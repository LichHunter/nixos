#!/usr/bin/env bash
# pve-build.sh — build a NixOS configuration on a disposable LXC container
# running on a Proxmox VE node, then apply the result to the requester
# (= the machine invoking this script, by default).
#
# The flow has five stages; each can be invoked on its own, or chained via
# the composite commands (build / test / switch / boot).
#
#   Stage    Step command               Effect
#   ------   -------------------------  --------------------------------------
#   1        check-image                Read-only: is a NixOS LXC ostemplate on PVE?
#            deploy-image               Idempotent: build+upload if missing, no-op if present.
#            update-image               Force: rebuild locally + replace on PVE.
#   2        start-builder              deploy-image + clone a fresh CT under a free
#                                       VMID + start it + wait for DHCP.
#   3        build-on [VMID]            Run `nixos-rebuild build --build-host builder@<hostname>`
#                                       against an existing disposable. VMID is
#                                       discovered from PVE if not given.
#   4        activate <test|switch|boot>
#                                     Run `sudo nixos-rebuild <cmd> --flake .#<requester>`
#                                       LOCALLY (no SSH). Closure must already be
#                                       in the local store from stage 3.
#   5        destroy-builder [VMID]   pct destroy --purge --force. VMID is
#                                       discovered from PVE if not given.
#
# Composite commands (chain stages 1-5 for the common cases):
#   build    = 1(deploy) + 2 + 3                    (CT left running)
#   test     = 1(deploy) + 2 + 3 + 4(test)          (CT left running)
#   switch   = 1(deploy) + 2 + 3 + 4(switch) + 5    (CT destroyed on success)
#   boot     = 1(deploy) + 2 + 3 + 4(boot)   + 5    (CT destroyed on success)
#
# Auxiliary:
#   info [VMID]   Print VMID/IP/SSH/destroy hints for a disposable.
#
# STATELESS DESIGN
#   The script writes no state files. Each step discovers prior steps'
#   artifacts dynamically:
#     - Disposables are identified by hostname pattern "<prefix>-<VMID>"
#       on PVE. `discover_vmid` queries pvesh for LXC containers matching
#       the prefix; if exactly one exists, it is used. Zero or multiple
#       -> the user must pass a VMID explicitly.
#     - The built closure lives in the local Nix store; nixos-rebuild finds
#       it naturally on activate.
#   This makes the script safe to re-run, interrupt, or split across shell
#   sessions without leftover state.
#
# HOSTNAME-BASED SSH
#   All SSH to disposables targets their hostname (`<prefix>-<VMID>`, e.g.
#   `nixos-builder-9999`), never their IP. The caller's resolver must be
#   able to look up PVE container hostnames — typically via dnsmasq or a
#   split-DNS that reads from PVE. The script never resolves IPs for SSH;
#   `get_ct_ip` is used only for `info` display and diagnostic logging.
#
# The split between build (user-owned SSH, no sudo) and activate (sudo, no
# SSH) avoids the need for the requester's root user to have SSH keys that
# reach the disposable — only the calling user does.

set -euo pipefail

# Global toggles referenced by the logging helpers above; defaulted here so
# the helpers can be called before the argument parser runs.
DEBUG=false

## ---------------------------------------------------------------------------
# Paths
## ---------------------------------------------------------------------------
# Walk up from $PWD looking for flake.nix. Override with FLAKE_ROOT=/path.
find_flake_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/flake.nix" ]] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  return 1
}

if [[ -z "${FLAKE_ROOT:-}" ]]; then
  if ! FLAKE_ROOT=$(find_flake_root); then
    die "No flake.nix found in \$PWD or any parent. Run from your flake root or set FLAKE_ROOT."
  fi
fi

## ---------------------------------------------------------------------------
# Defaults — override via env vars or CLI flags
# ---------------------------------------------------------------------------
PVE_HOST="${PVE_HOST:-pve}"                              # SSH alias for the PVE node (defined in ~/.ssh/config)
PVE_STORAGE="${PVE_STORAGE:-local}"                      # ostemplate storage (holds vztmpl/)
PVE_ROOTFS_STORAGE="${PVE_ROOTFS_STORAGE:-local-lvm}"    # rootfs storage for new CTs
PVE_BRIDGE="${PVE_BRIDGE:-vmbr0}"                        # network bridge
VMID_START="${VMID_START:-9999}"                          # scan downward from here for a free VMID
VMID_FLOOR="${VMID_FLOOR:-100}"                          # lowest VMID to consider (PVE minimum)
TEMPLATE_OUTPUT="${TEMPLATE_OUTPUT:-nixos-lxc}"          # flake output to build
CT_HOSTNAME_PREFIX="${CT_HOSTNAME_PREFIX:-nixos-builder}" # disposables' hostname prefix
BUILD_SSH_USER="${BUILD_SSH_USER:-builder}"                # user nixos-rebuild SSHes as on the CT
CT_BOOT_TIMEOUT="${CT_BOOT_TIMEOUT:-120}"                # seconds to wait for DHCP lease
CT_ROOTFS_GIB="${CT_ROOTFS_GIB:-150}"                    # rootfs size in GiB (nix store fills fast)
CT_MEMORY="${CT_MEMORY:-16384}"                          # container memory limit in MB (nix builds are hungry)
CT_SWAP="${CT_SWAP:-16384}"                              # container swap in MB

## ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
# Levels / channels:
#   log / warn / err   plain status, warnings, errors (always on)
#   phase              major stage banner — what we are about to do overall
#   step               sub-step within a phase
#   ok                 success marker
#   phase_done         phase completion with elapsed seconds
#   run                 echo a local command, then execute it
#   debug               verbose internals — only with --debug
#
# All output goes to stderr so stdout stays clean for callers that pipe us.
LOG_INDENT=""
log()    { printf '\033[1;34m[pve-build]\033[0m %s%s\n' "$LOG_INDENT" "$*" >&2; }
warn()   { printf '\033[1;33m[pve-build WARN]\033[0m %s%s\n' "$LOG_INDENT" "$*" >&2; }
err()    { printf '\033[1;31m[pve-build ERROR]\033[0m %s%s\n' "$LOG_INDENT" "$*" >&2; }
die()    { err "$*"; exit 1; }
debug()  { $DEBUG && printf '\033[2;37m[pve-build debug]\033[0m %s%s\n' "$LOG_INDENT" "$*" >&2 || true; }

# Major stage banner. Also starts the phase timer used by phase_done.
phase() {
  printf '\n\033[1;36m━━━ %s ━━━\033[0m\n' "$*" >&2
  _PHASE_START=$SECONDS
}
step()  { printf '\033[1;36m▸\033[0m %s\n' "$*" >&2; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*" >&2; }
fail()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# Phase completion with elapsed time.
phase_done() {
  local label="$1"
  local elapsed=$(( SECONDS - ${_PHASE_START:-$SECONDS} ))
  printf '\033[1;32m✓\033[0m %s \033[2m(%ds)\033[0m\n' "$label" "$elapsed" >&2
}

# Echo a local command (dim green "$  cmd..."), then execute it.
run() {
  printf '\033[2;32m$\033[0m %s\n' "$*" >&2
  "$@"
}

# SSH options for reaching the PVE node. Connection multiplexing keeps a
# single master connection alive for the whole script invocation so the
# user authenticates once (passphrase, password, MFA) instead of per call.
# The mux socket lives in a private mktemp directory so concurrent runs
# don't collide. ControlPersist=yes keeps the master alive indefinitely
# (until the EXIT trap closes it via `ssh -O exit`) — this is deliberate,
# because long-running local work between PVE calls (e.g. `nix build` of
# a 350M+ image) would otherwise let a timed ControlPersist expire and
# force re-auth on the next pve/pve_scp call.
SSH_MUX_DIR=$(mktemp -d -t pve-build-mux.XXXXXX)
SSH_MUX_SOCKET="$SSH_MUX_DIR/sock"
PVE_SSH_OPTS=(
  -o ConnectTimeout=10
  -o ControlMaster=auto
  -o ControlPath="$SSH_MUX_SOCKET"
  -o ControlPersist=yes
)

# Tear down the SSH master and the temp dir on exit. `ssh -O exit` talks
# to the master via the ControlPath socket (no network call, no prompt);
# the `[[ -S ... ]]` guard skips it if no master was ever established.
cleanup_ssh_master() {
  if [[ -S "$SSH_MUX_SOCKET" ]]; then
    ssh "${PVE_SSH_OPTS[@]}" -O exit "$PVE_HOST" 2>/dev/null || true
  fi
  if [[ -S "${DISPOSABLE_MUX_SOCKET:-}" ]]; then
    ssh "${DISPOSABLE_SSH_OPTS[@]}" -O exit builder@placeholder 2>/dev/null || true
  fi
  rm -rf "$SSH_MUX_DIR" "${DISPOSABLE_MUX_DIR:-}"
}
trap cleanup_ssh_master EXIT

# Default pve() wrapper — runs a command on the PVE node over SSH, echoing
# the full invocation first. Every pve/pvesh/pct call in this script goes
# through here, so all PVE traffic is visible in the log and reuses the
# same authenticated master connection.
pve() {
  printf '\033[2;32m$\033[0m ssh %s %s\n' "$PVE_HOST" "$*" >&2
  ssh "${PVE_SSH_OPTS[@]}" "$PVE_HOST" "$@"
}

# scp wrapper that reuses the same master connection as pve(). Times the
# transfer and logs the average speed on completion. Without the master
# reuse, scp would establish its own fresh SSH session and re-prompt for
# auth.
pve_scp() {
  printf '\033[2;32m$\033[0m scp %s\n' "$*" >&2
  local start=$SECONDS rc elapsed
  set +e
  scp "${PVE_SSH_OPTS[@]}" "$@"
  rc=$?
  set -e
  elapsed=$((SECONDS - start))

  if [[ $rc -eq 0 ]]; then
    local src="$1" size_bytes size_human speed
    if [[ -f "$src" ]]; then
      size_bytes=$(wc -c < "$src" 2>/dev/null || echo 0)
      size_human=$(du -h "$src" | cut -f1)
      speed=$(awk -v s="$size_bytes" -v t="$elapsed" \
        'BEGIN{ if(t>0) printf "%.1f", s/1024/1024/t; else print "?" }')
      ok "Transferred $size_human in ${elapsed}s (${speed} MB/s)"
    else
      ok "Transferred in ${elapsed}s"
    fi
  else
    fail "scp failed (exit $rc) after ${elapsed}s"
  fi
  return $rc
}

# SSH options for reaching the disposable — its host key is fresh every run.
# Same multiplexing pattern as PVE: one master per script invocation so the
# user authenticates once even though wait_for_ready polls every 2s and
# probe_ssh / nixos-rebuild each make their own connections.
DISPOSABLE_MUX_DIR=$(mktemp -d -t pve-build-disposable-mux.XXXXXX)
DISPOSABLE_MUX_SOCKET="$DISPOSABLE_MUX_DIR/sock"
DISPOSABLE_SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
  -o ControlMaster=auto
  -o ControlPath="$DISPOSABLE_MUX_SOCKET"
  -o ControlPersist=yes
)

## ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 <command> [options]

Build a NixOS configuration on a disposable LXC container on a Proxmox VE
node, then apply it to the requester (current machine by default).

Composite commands (chain all stages):
  build                      deploy-image + start-builder + build-on.
  test                       deploy-image + start-builder + build-on + activate test.
  switch                     deploy-image + start-builder + build-on + activate switch
                             + destroy-builder. Disposable destroyed on success.
  boot                       deploy-image + start-builder + build-on + activate boot
                             + destroy-builder. Disposable destroyed on success.

Step commands (run one stage — VMID auto-discovered from PVE if omitted):
  check-image                Read-only: exit 0 if a NixOS LXC ostemplate is on PVE, 1 if not.
  deploy-image               Idempotent: build+upload if missing, no-op if present.
  update-image               Force: rebuild .$TEMPLATE_OUTPUT locally + replace on PVE.
  start-builder              deploy-image + clone a fresh CT + start.
  build-on [VMID]            Build closure on an existing disposable.
  activate <test|switch|boot>
                             Activate LOCALLY (closure must already be built).
  destroy-builder [VMID]     pct destroy --purge --force.

Auxiliary:
  info [VMID]                Show VMID / IP / SSH / destroy hints (or list all).

Disposables are identified by hostname pattern "$CT_HOSTNAME_PREFIX-<VMID>"
on PVE. If exactly one exists, it is used implicitly; if zero or multiple
exist, you must pass a VMID explicitly. The script writes no state files.

Options:
  --machine NAME             Requester machine name (default: current hostname).
  --pve-host HOST            PVE SSH target (default: $PVE_HOST; env: PVE_HOST).
  --pve-storage NAME         Ostemplate storage (default: $PVE_STORAGE).
  --rootfs-storage NAME      Rootfs storage (default: $PVE_ROOTFS_STORAGE).
  --bridge NAME              Bridge (default: $PVE_BRIDGE).
  --vmid-start N             Highest VMID to consider (default: $VMID_START). Scanned downward.
  --vmid-floor N             Lowest VMID to consider (default: $VMID_FLOOR).
  --rootfs-gib N             Rootfs size in GiB (default: $CT_ROOTFS_GIB).
  --keep                     Keep the disposable even on successful switch/boot.
  --local-build              Skip PVE entirely; run nixos-rebuild locally.
  --show-trace               Pass --show-trace to nixos-rebuild.
  --verbose                  Pass --verbose to nixos-rebuild.
  --debug                    Verbose script internals (commands, decisions).
  -h, --help                 Show this help.

Environment:
  PVE_HOST, PVE_STORAGE, PVE_ROOTFS_STORAGE, PVE_BRIDGE,
  VMID_START, VMID_FLOOR, BUILD_SSH_USER,
  CT_BOOT_TIMEOUT, CT_ROOTFS_GIB, TEMPLATE_OUTPUT, CT_HOSTNAME_PREFIX

Examples:
  # Full happy path — build + activate susano permanently, auto-destroy CT.
  $0 switch --machine susano

  # Step-by-step (each step discovers the prior step's artifacts from PVE):
  $0 deploy-image                 # build + upload the LXC ostemplate (no-op if present)
  $0 start-builder                # clones a fresh disposable CT
  $0 build-on                     # discovers the CT on PVE, builds on it
  $0 activate switch              # activates locally (no SSH)
  $0 destroy-builder              # discovers the CT on PVE, destroys it

  # Rebuild the LXC image after editing machines/builder/default.nix.
  $0 update-image

  # Operate on a specific CT (skips discovery, useful when multiple exist).
  $0 build-on 305
  $0 destroy-builder 305

  # See what disposables exist on PVE.
  $0 info

Any unrecognized options are passed through to nixos-rebuild.
EOF
}

## ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
COMMAND=""
MACHINE_NAME=""
POSITIONAL_VMID=""      # used by build-on / destroy-builder / info
ACTIVATE_CMD=""         # activate <test|switch|boot>
KEEP=false
LOCAL_BUILD=false
SHOW_TRACE=false
VERBOSE=false
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    # Composite commands
    build|test|switch|boot)
      [[ -n "$COMMAND" ]] && die "Only one command may be specified."
      COMMAND="$1"; shift ;;
    # Step commands
    check-image|deploy-image|update-image|start-builder|ensure-template|create)
      [[ -n "$COMMAND" ]] && die "Only one command may be specified."
      # Backwards-compat aliases:
      case "$1" in
        ensure-template) COMMAND="deploy-image" ;;
        create)          COMMAND="start-builder" ;;
        *)               COMMAND="$1" ;;
      esac
      shift ;;
    build-on|destroy-builder|info)
      [[ -n "$COMMAND" ]] && die "Only one command may be specified."
      COMMAND="$1"; shift
      if [[ $# -gt 0 && "$1" != --* ]]; then POSITIONAL_VMID="$1"; shift; fi ;;
    activate)
      [[ -n "$COMMAND" ]] && die "Only one command may be specified."
      COMMAND="$1"; shift
      if [[ $# -gt 0 && "$1" != --* ]]; then ACTIVATE_CMD="$1"; shift; fi ;;
    # Flags
    --machine)         MACHINE_NAME="${2:?--machine requires a value}"; shift 2 ;;
    --pve-host)        PVE_HOST="${2:?--pve-host requires a value}"; shift 2 ;;
    --pve-storage)     PVE_STORAGE="${2:?--pve-storage requires a value}"; shift 2 ;;
    --rootfs-storage)  PVE_ROOTFS_STORAGE="${2:?--rootfs-storage requires a value}"; shift 2 ;;
    --bridge)          PVE_BRIDGE="${2:?--bridge requires a value}"; shift 2 ;;
    --vmid-start)      VMID_START="${2:?--vmid-start requires a value}"; shift 2 ;;
    --vmid-floor)      VMID_FLOOR="${2:?--vmid-floor requires a value}"; shift 2 ;;
    --rootfs-gib)      CT_ROOTFS_GIB="${2:?--rootfs-gib requires a value}"; shift 2 ;;
    --keep)            KEEP=true; shift ;;
    --local-build)     LOCAL_BUILD=true; shift ;;
    --show-trace)      SHOW_TRACE=true; shift ;;
    --verbose)         VERBOSE=true; shift ;;
    --debug)           DEBUG=true; shift ;;
    -h|--help)         usage; exit 0 ;;
    --*)               die "Unknown option: $1" ;;
    *)
      # A non-flag token before any command is set is an unknown command.
      [[ -z "$COMMAND" ]] && die "Unknown command: $1 (try --help)"
      PASSTHROUGH+=("$1"); shift ;;
  esac
done

[[ -n "$COMMAND" ]] || { usage; exit 1; }

# Requester auto-detection: hostname, override with --machine.
# Relevant for composite, build-on, activate (anything that calls nixos-rebuild).
if [[ -z "$MACHINE_NAME" ]]; then
  MACHINE_NAME=$(hostname 2>/dev/null || echo "$USER")
fi

phase "Configuration"
log "Requester machine: $MACHINE_NAME"
log "Flake:             $FLAKE_ROOT#$MACHINE_NAME"
log "PVE host:          $PVE_HOST"
log "PVE storage:       $PVE_STORAGE (ostemplate) / $PVE_ROOTFS_STORAGE (rootfs)"
log "Bridge:            $PVE_BRIDGE"
log "VMID start:       $VMID_START (scanning down to $VMID_FLOOR)"
log "Disposable prefix: $CT_HOSTNAME_PREFIX-<VMID>"
log "Command:           $COMMAND"
debug "DEBUG: enabled"
debug "KEEP=$KEEP  LOCAL_BUILD=$LOCAL_BUILD  SHOW_TRACE=$SHOW_TRACE  VERBOSE=$VERBOSE"
debug "PASSTHROUGH (${#PASSTHROUGH[@]}): ${PASSTHROUGH[*]:-}"

## ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
require() {
  command -v "$1" >/dev/null || die "$1 is required on the caller ($2)."
}

# Verify SSH connectivity to the PVE node before any PVE-touching step.
# Without this, silent SSH failures inside pvesh / pveam / pct calls (which
# use `2>/dev/null || true` to tolerate empty results) would be reported to
# the user as "no matches" or "no disposables" — a misleading success.
require_pve() {
  step "Probing SSH to PVE node ($PVE_HOST) ..."
  if ! pve true; then
    fail "Cannot SSH to PVE node via alias '$PVE_HOST'."
    warn "  - is the PVE node up?"
    warn "  - does '$PVE_HOST' resolve via ~/.ssh/config (Host, User, IdentityFile)?"
    warn "  - is your SSH key authorized on the PVE node?"
    die "PVE unreachable."
  fi
  ok "PVE reachable: $PVE_HOST"
}

## ---------------------------------------------------------------------------
# VMID discovery — query PVE for LXC containers whose name matches the
# disposable hostname prefix. Used by every step that needs a target VMID
# but wasn't given one explicitly.
# ---------------------------------------------------------------------------
#
# Output of `pvesh get /cluster/resources --type vm --output-format json`:
#   [{"vmid":100,"name":"nixos-builder-300","type":"lxc","status":"running",...}, ...]
discover_disposables() {
  # Prints "<vmid> <status> <name>" lines for every LXC container whose name
  # starts with "$CT_HOSTNAME_PREFIX-". Empty output means pvesh failed OR
  # no matches; the caller decides based on context.
  step "Querying PVE for LXC containers matching '${CT_HOSTNAME_PREFIX}-*' ..."
  local raw
  raw=$(pve pvesh get /cluster/resources --type vm --output-format json 2>/dev/null \
    | jq -r --arg prefix "$CT_HOSTNAME_PREFIX" '
        map(select(
          .type == "lxc" and (.name | startswith($prefix + "-"))
        ))
        | sort_by(.vmid)
        | .[]
        | "\(.vmid) \(.status) \(.name)"
      ' 2>/dev/null || true)
  local count=0
  [[ -n "$raw" ]] && count=$(grep -c '^' <<<"$raw" || true)
  debug "discover_disposables: pvesh returned $count match(es)"
  printf '%s' "$raw"
}

# Echo the VMID of the single disposable matching the prefix on PVE. Dies if
# there are zero or multiple matches (caller should pass an explicit VMID).
discover_vmid() {
  local matches
  matches=$(discover_disposables)

  if [[ -z "$matches" ]]; then
    fail "No disposable container on $PVE_HOST matches '${CT_HOSTNAME_PREFIX}-*'."
    die "Run '$0 start-builder' first, or pass a VMID explicitly."
  fi

  local count
  count=$(grep -c '^' <<<"$matches" || true)

  if [[ "$count" -eq 1 ]]; then
    local vmid status name
    read -r vmid status name <<<"$matches"
    ok "Found disposable: VMID=$vmid status=$status name=$name"
    echo "$vmid"
    return
  fi

  fail "Multiple disposable containers found on $PVE_HOST:"
  while IFS= read -r line; do
    warn "  $line"
  done <<<"$matches"
  die "Ambiguous: pass a VMID explicitly (e.g. '$0 $COMMAND <VMID>')."
}

# Resolve a VMID: explicit argument wins, else discover from PVE.
resolve_vmid() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"
  else
    discover_vmid
  fi
}

## ---------------------------------------------------------------------------
# Stage 1: image management (check / deploy / update).
# All three operate on the NixOS LXC ostemplate stored in PVE's
# /var/lib/vz/template/cache/. The "latest" template is whichever
# nixos-lxc-*.tar.xz sorts last alphabetically (matches the helpers below).
# ---------------------------------------------------------------------------

# Echo the storage-relative path of the newest nixos-lxc template on PVE, or
# empty if none. Read-only.
find_template_on_pve() {
  debug "find_template_on_pve: pveam list $PVE_STORAGE"
  pve pveam list "$PVE_STORAGE" 2>/dev/null \
    | awk '/nixos.*lxc.*\.tar\.xz/ {print $1}' \
    | sort | tail -n1 || true
}

# Build .$TEMPLATE_OUTPUT locally and scp the tarball to PVE's template cache.
# Sets OSTEMPLATE on success. Used by both deploy-image (when missing) and
# update-image (always).
build_and_upload_image() {
  step "Building .$TEMPLATE_OUTPUT locally via nix ..."
  local result_dir
  result_dir=$(cd "$FLAKE_ROOT" && run nix build ".#$TEMPLATE_OUTPUT" --no-link --print-out-paths)
  [[ -n "$result_dir" && -d "$result_dir" ]] \
    || die "nix build .$TEMPLATE_OUTPUT produced no output path."
  log "  nix output: $result_dir"

  # nixos-generators proxmox-lxc format lays the file under result/tarball/*.tar.xz
  local tarball
  tarball=$(find "$result_dir/tarball" -maxdepth 1 -type f -name '*.tar.xz' -print -quit | head -n1)
  [[ -n "$tarball" ]] \
    || die "No .tar.xz found under $result_dir/tarball/. Did nixos-generators output layout change?"
  local tname; tname=$(basename "$tarball")
  debug "tarball path: $tarball"
  debug "tarball name: $tname"
  ok "Built image: $tname"

  step "Uploading to $PVE_HOST:/var/lib/vz/template/cache/ ..."
  local size_human
  size_human=$(du -h "$tarball" | cut -f1)
  log "  scp $tarball ($size_human) -> $PVE_HOST:/var/lib/vz/template/cache/$tname"
  pve_scp "$tarball" "$PVE_HOST:/var/lib/vz/template/cache/$tname"

  OSTEMPLATE="$PVE_STORAGE:vztmpl/$tname"
}

# Remove old nixos-lxc templates from PVE, keeping $1. Must be called after
# the new image is uploaded so a build/upload failure leaves the previous
# template intact.
purge_old_templates_on_pve() {
  local keep="${1:-}"
  step "Purging old nixos-lxc templates from $PVE_HOST (keeping ${keep:-none}) ..."
  local all
  all=$(pve pveam list "$PVE_STORAGE" 2>/dev/null \
        | awk '/nixos.*lxc.*\.tar\.xz/ {print $1}' || true)
  local removed=0
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    if [[ -n "$keep" && "$t" == "$keep" ]]; then
      debug "keeping: $t"
      continue
    fi
    local filename="${t##*/}"
    log "  removing: $t"
    pve rm -f "/var/lib/vz/template/cache/$filename" 2>/dev/null || true
    removed=$((removed + 1))
  done <<<"$all"
  ok "Purged $removed old template(s)"
}

# Read-only check. Sets OSTEMPLATE and returns 0 if a template exists;
# clears OSTEMPLATE and returns 1 if missing.
check_image() {
  step "Checking for nixos-lxc ostemplate on $PVE_HOST (storage: $PVE_STORAGE) ..."
  local existing
  existing=$(find_template_on_pve)
  if [[ -n "$existing" ]]; then
    OSTEMPLATE="$existing"
    ok "Image present: $OSTEMPLATE"
    return 0
  fi
  OSTEMPLATE=""
  warn "No nixos-lxc ostemplate found."
  return 1
}

# Idempotent deploy: build + upload only if no template exists.
deploy_image() {
  if check_image; then
    log "Nothing to do — image already on PVE."
    return
  fi
  build_and_upload_image
  ok "Image deployed: $OSTEMPLATE"
}

# Force update: build + upload first, then purge old. If the build or upload
# fails, the previous template remains on PVE.
update_image() {
  build_and_upload_image
  purge_old_templates_on_pve "$OSTEMPLATE"
  ok "Image updated: $OSTEMPLATE"
}

## ---------------------------------------------------------------------------
# Stage 2 helpers: VMID + container lifecycle
# ---------------------------------------------------------------------------
find_free_vmid() {
  step "Finding a free VMID (scanning downward from $VMID_START to $VMID_FLOOR) ..."

  # pvesh returns JSON cluster-wide; jq extracts vmids on the caller side.
  local used
  used=$(pve pvesh get /cluster/resources --type vm --output-format json 2>/dev/null \
          | jq -r '.[].vmid' 2>/dev/null || true)
  local used_count
  used_count=$(grep -c '^' <<<"$used" || true)
  debug "pvesh reports $used_count VMID(s) in use cluster-wide"

  local id
  for (( id=VMID_START; id>=VMID_FLOOR; id-- )); do
    if ! grep -qx "$id" <<<"$used"; then
      ok "Free VMID selected: $id"
      echo "$id"
      return
    fi
  done
  fail "No free VMID in [$VMID_FLOOR, $VMID_START]."
  die "Raise --vmid-start, lower --vmid-floor, or clean up old disposables."
}

# Create + start a container. The container is identifiable afterwards purely
# by its hostname pattern on PVE — no state file is written.
create_and_start_ct() {
  local vmid="$1"
  local hostname="$CT_HOSTNAME_PREFIX-$vmid"

  step "Creating container $vmid (hostname=$hostname) ..."
  debug "ostemplate: $OSTEMPLATE"
  debug "rootfs:     $PVE_ROOTFS_STORAGE:$CT_ROOTFS_GIB"
  debug "net0:       name=eth0,bridge=$PVE_BRIDGE,ip=dhcp"
  pve pct create "$vmid" "$OSTEMPLATE" \
    --hostname "$hostname" \
    --arch amd64 \
    --ostype unmanaged \
    --unprivileged 1 \
    --features keyctl=1,nesting=1 \
    --rootfs "$PVE_ROOTFS_STORAGE:$CT_ROOTFS_GIB" \
    --memory "$CT_MEMORY" \
    --swap "$CT_SWAP" \
    --net0 "name=eth0,bridge=$PVE_BRIDGE,ip=dhcp" \
    --onboot 0 \
    --start 0
  ok "Container $vmid created"

  step "Starting container $vmid ..."
  pve pct start "$vmid"
  ok "Container $vmid started"
}

# Echo the current IPv4 of a running container's eth0, or empty if unavailable.
get_ct_ip() {
  local vmid="$1"
  pve pct exec "$vmid" -- ip -j -4 addr show eth0 2>/dev/null \
    | jq -r '.[0].addr_info[]? | select(.scope=="global") | .local' 2>/dev/null \
    | head -n1 || true
}

# Wait for a disposable to become SSH-reachable via its hostname. Echos the
# hostname on success (so the caller can pass it to do_build / probe_ssh).
# We deliberately do NOT use the IP here — the script's contract is that
# disposable hostnames resolve on the caller (see HOSTNAME-BASED SSH above).
wait_for_ready() {
  local vmid="$1"
  local hostname="$CT_HOSTNAME_PREFIX-$vmid"
  local deadline=$(( $(date +%s) + CT_BOOT_TIMEOUT ))
  step "Waiting for SSH to $BUILD_SSH_USER@$hostname (timeout ${CT_BOOT_TIMEOUT}s) ..."

  local elapsed=0
  while [[ $(date +%s) -lt $deadline ]]; do
    if ssh "${DISPOSABLE_SSH_OPTS[@]}" "$BUILD_SSH_USER@$hostname" true 2>/dev/null; then
      # Best-effort IP lookup for diagnostic logging only.
      local maybe_ip; maybe_ip=$(get_ct_ip "$vmid" 2>/dev/null || true)
      ok "SSH up: $BUILD_SSH_USER@$hostname${maybe_ip:+ (IP: $maybe_ip)} (after ${elapsed}s)"
      echo "$hostname"
      return
    fi
    debug "ssh to $hostname not ready yet (t=${elapsed}s); retrying in 2s"
    sleep 2
    elapsed=$(( elapsed + 2 ))
  done
  fail "Timeout waiting for SSH to $BUILD_SSH_USER@$hostname."
  warn "Is '$hostname' resolvable on this host? The script SSHes by hostname, never IP."
  die "Check PVE container start state and your DNS/hosts setup."
}

# Probe SSH to the disposable. Returns nonzero on failure.
probe_ssh() {
  local target="$1"
  step "Probing SSH to $BUILD_SSH_USER@$target ..."
  if ! ssh "${DISPOSABLE_SSH_OPTS[@]}" "$BUILD_SSH_USER@$target" true 2>/dev/null; then
    fail "Cannot SSH to $BUILD_SSH_USER@$target."
    warn "The disposable's '$BUILD_SSH_USER' user must trust your SSH key. The baked-in admin"
    warn "key is alexander0derevianko@gmail.com — edit machines/builder/default.nix (adminKeys) to add yours."
    return 1
  fi
  ok "SSH OK: $BUILD_SSH_USER@$target"
}

## ---------------------------------------------------------------------------
# Stages 3 + 4: build on disposable / activate locally
# ---------------------------------------------------------------------------

# Build phase: build the requester's closure on the disposable, copy it back
# into the caller's local Nix store. Returns the nixos-rebuild exit code.
# Targets the disposable by hostname (nixos-rebuild will SSH to it).
do_build() {
  local vmid="$1" hostname="$2"
  local build_args=(
    nixos-rebuild build
    --flake "$FLAKE_ROOT#$MACHINE_NAME"
    --build-host "$BUILD_SSH_USER@$hostname"
  )
  $SHOW_TRACE && build_args+=(--show-trace)
  $VERBOSE  && build_args+=(--verbose)
  [[ ${#PASSTHROUGH[@]} -gt 0 ]] && build_args+=("${PASSTHROUGH[@]}")

  # nix / nixos-rebuild honour NIX_SSHOPTS when SSHing to --build-host.
  export NIX_SSHOPTS="${NIX_SSHOPTS:-} ${DISPOSABLE_SSH_OPTS[*]}"

  step "Build phase (CT $vmid via $hostname): building requester closure on disposable ..."
  debug "NIX_SSHOPTS=$NIX_SSHOPTS"
  printf '\033[2;32m$\033[0m %s\n' "${build_args[*]}" >&2
  set +e
  "${build_args[@]}"
  local rc=$?
  set -e
  return $rc
}

# Activate phase: runs LOCALLY with sudo, no --build-host. The closure must
# already be in the local store (from a prior do_build). Returns exit code.
do_activate() {
  local cmd="$1"
  local activate_args=(sudo nixos-rebuild "$cmd" --flake "$FLAKE_ROOT#$MACHINE_NAME")
  $SHOW_TRACE && activate_args+=(--show-trace)
  $VERBOSE  && activate_args+=(--verbose)
  [[ ${#PASSTHROUGH[@]} -gt 0 ]] && activate_args+=("${PASSTHROUGH[@]}")

  step "Activate phase (local): $cmd — applying closure already in local store ..."
  printf '\033[2;32m$\033[0m %s\n' "${activate_args[*]}" >&2
  set +e
  "${activate_args[@]}"
  local rc=$?
  set -e
  return $rc
}

## ---------------------------------------------------------------------------
# Stage 5: destroy
# ---------------------------------------------------------------------------
destroy_ct() {
  local vmid="$1"
  step "Destroying container $vmid on $PVE_HOST (pct destroy --purge --force) ..."
  pve pct destroy "$vmid" --purge --force \
    || die "Failed to destroy container $vmid (it may already be gone)."
  ok "Container $vmid destroyed"
}

# Print debug hints for a container that's been left in place.
print_debug_info() {
  local vmid="$1" hostname="${2:-}" ip="${3:-}"
  warn "Container $vmid is left on PVE."
  warn "  pct enter:   ssh $PVE_HOST -t pct enter $vmid"
  [[ -n "$hostname" ]] && warn "  SSH:         ssh ${DISPOSABLE_SSH_OPTS[*]} $BUILD_SSH_USER@$hostname"
  [[ -n "$ip" ]]       && warn "  raw IP:      $ip (not used by this script — SSH is hostname-based)"
  warn "  destroy:     $0 destroy-builder $vmid"
  warn "  info:        $0 info $vmid"
}

## ---------------------------------------------------------------------------
# Local build: skip PVE entirely, run nixos-rebuild on this machine.
# ---------------------------------------------------------------------------

cmd_local_build() {
  require nix "run nixos-rebuild"

  phase "Local build: $COMMAND (no PVE disposable)"

  local args=(nixos-rebuild "$COMMAND" --flake "$FLAKE_ROOT#$MACHINE_NAME")
  $SHOW_TRACE && args+=(--show-trace)
  $VERBOSE  && args+=(--verbose)
  [[ ${#PASSTHROUGH[@]} -gt 0 ]] && args+=("${PASSTHROUGH[@]}")

  if [[ "$COMMAND" == "test" || "$COMMAND" == "switch" || "$COMMAND" == "boot" ]]; then
    args=(sudo "${args[@]}")
  fi

  printf '\033[2;32m$\033[0m %s\n' "${args[*]}" >&2
  set +e
  "${args[@]}"
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    fail "Local build FAILED (exit $rc)."
    exit "$rc"
  fi
  ok "Local build SUCCEEDED."
  phase_done "Local build: $COMMAND"
}

## ---------------------------------------------------------------------------
# Composite command: full pipeline for build / test / switch / boot.
# ---------------------------------------------------------------------------
cmd_composite() {
  if $LOCAL_BUILD; then
    cmd_local_build
    return
  fi

  require ssh  "drive PVE"
  require_pve
  require scp  "upload the template"
  require nix  "build the template + run nixos-rebuild"
  require jq   "find free VMID + read container IP"

  phase "Composite: $COMMAND  (deploy-image + start-builder + build-on$([[ "$COMMAND" != build ]] && echo " + activate $COMMAND")$({ [[ "$COMMAND" == switch || "$COMMAND" == boot ]] && ! $KEEP; } && echo " + destroy-builder"))"

  deploy_image

  local vmid hostname rc matches count
  matches=$(discover_disposables)

  if [[ -z "$matches" ]]; then
    vmid=$(find_free_vmid)
    hostname="$CT_HOSTNAME_PREFIX-$vmid"
    log "No existing disposable — creating $hostname"
    create_and_start_ct "$vmid"
  else
    count=$(grep -c '^' <<<"$matches" || true)
    if [[ "$count" -ne 1 ]]; then
      warn "Multiple disposable containers found:"
      while IFS= read -r line; do warn "  $line"; done <<<"$matches"
      die "Ambiguous: clean up with '$0 destroy-builder <VMID>' first."
    fi
    read -r vmid _ _ <<<"$matches"
    hostname="$CT_HOSTNAME_PREFIX-$vmid"
    log "Reusing existing disposable: $hostname"
    local status
    status=$(pve pct status "$vmid" 2>/dev/null | awk '{print $2}' || true)
    if [[ "$status" != "running" ]]; then
      step "Container $vmid is stopped — starting ..."
      pve pct start "$vmid"
    fi
  fi

  hostname=$(wait_for_ready "$vmid")

  probe_ssh "$hostname" || { print_debug_info "$vmid" "$hostname"; die "Aborting composite pipeline."; }

  do_build "$vmid" "$hostname" && rc=0 || rc=$?
  if [[ $rc -eq 0 ]]; then ok "Build phase succeeded (exit 0)."; else fail "Build phase failed (exit $rc)."; fi

  if [[ $rc -eq 0 ]] && [[ "$COMMAND" == "test" || "$COMMAND" == "switch" || "$COMMAND" == "boot" ]]; then
    do_activate "$COMMAND" && rc=0 || rc=$?
    if [[ $rc -eq 0 ]]; then ok "Activate phase succeeded (exit 0)."; else fail "Activate phase failed (exit $rc)."; fi
  fi

  if [[ $rc -ne 0 ]]; then
    fail "Pipeline FAILED (exit $rc)."
    print_debug_info "$vmid" "$hostname"
    exit "$rc"
  fi

  if { [[ "$COMMAND" == "switch" || "$COMMAND" == "boot" ]]; } && ! $KEEP; then
    destroy_ct "$vmid"
  else
    log "Command was '$COMMAND'${KEEP:+ (--keep)} — container $vmid is left on PVE."
    log "  destroy with:  $0 destroy-builder $vmid"
  fi

  phase_done "Composite: $COMMAND"
}

## ---------------------------------------------------------------------------
# Step commands
# ---------------------------------------------------------------------------
cmd_check_image() {
  require ssh "drive PVE"
  require_pve
  phase "check-image — read-only probe of ostemplate on PVE"
  if check_image; then
    log "Image present on PVE: $OSTEMPLATE"
    phase_done "check-image"
    exit 0
  fi
  fail "No NixOS LXC image found on $PVE_HOST."
  log "Run '$0 deploy-image' to build+upload."
  phase_done "check-image"
  exit 1
}

cmd_deploy_image() {
  require ssh "drive PVE"
  require_pve
  require scp "upload the template"
  require nix "build the template"
  phase "deploy-image — ensure ostemplate is on PVE (idempotent)"
  deploy_image
  log "Ostemplate ready: $OSTEMPLATE"
  phase_done "deploy-image"
}

cmd_update_image() {
  require ssh "drive PVE"
  require_pve
  require scp "upload the template"
  require nix "build the template"
  phase "update-image — purge + rebuild + upload ostemplate"
  update_image
  log "Ostemplate ready: $OSTEMPLATE"
  phase_done "update-image"
}

cmd_start_builder() {
  require ssh "drive PVE"
  require_pve
  require scp "upload the template"
  require nix "build the template"
  require jq  "find free VMID"

  phase "start-builder — clone a fresh disposable CT"

  deploy_image

  local vmid hostname
  vmid=$(find_free_vmid)
  hostname="$CT_HOSTNAME_PREFIX-$vmid"
  log "Hostname will be: $hostname"

  create_and_start_ct "$vmid"
  hostname=$(wait_for_ready "$vmid")

  if ! probe_ssh "$hostname"; then
    print_debug_info "$vmid" "$hostname"
    die "SSH probe failed."
  fi

  local ip; ip=$(get_ct_ip "$vmid")

  cat >&2 <<EOF

$(ok "Disposable ready.")
  VMID:        $vmid
  Hostname:    $hostname
  IP (eth0):   ${ip:-(unknown)}
  PVE host:    $PVE_HOST
  Rootfs:      $PVE_ROOTFS_STORAGE ($CT_ROOTFS_GIB GiB)
  Bridge:      $PVE_BRIDGE
  SSH:         ssh $BUILD_SSH_USER@$hostname
  pct enter:   ssh $PVE_HOST -t pct enter $vmid

  Next steps:
    build:      $0 build-on $vmid
    destroy:    $0 destroy-builder $vmid
    inspect:    $0 info $vmid
EOF
  phase_done "start-builder"
}

cmd_build_on() {
  require ssh "drive PVE"
  require_pve
  require nix "run nixos-rebuild"
  require jq  "discover + read container IP"

  phase "build-on — build requester closure on disposable"

  local vmid hostname rc
  vmid=$(resolve_vmid "${POSITIONAL_VMID:-}")
  hostname="$CT_HOSTNAME_PREFIX-$vmid"
  step "Target disposable: VMID=$vmid hostname=$hostname"

  # Sanity: confirm the container is running on PVE before trusting DNS.
  local status
  status=$(pve pct status "$vmid" 2>/dev/null | awk '{print $2}' || true)
  debug "pct status $vmid -> ${status:-(unknown)}"
  if [[ "$status" != "running" ]]; then
    fail "Container $vmid is not running (status: ${status:-(unknown)})."
    die "Start it on PVE first ('pct start $vmid') or pick another VMID."
  fi

  probe_ssh "$hostname" || { print_debug_info "$vmid" "$hostname"; die "Aborting build-on."; }

  do_build "$vmid" "$hostname" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]]; then
    fail "Build FAILED (exit $rc)."
    print_debug_info "$vmid" "$hostname"
    exit "$rc"
  fi
  ok "Build SUCCEEDED."
  log "  activate with: $0 activate <test|switch|boot>"
  phase_done "build-on"
}

cmd_activate() {
  require nix "run nixos-rebuild"

  case "${ACTIVATE_CMD:-}" in
    test|switch|boot) ;;
    *) die "activate requires <test|switch|boot> as its argument." ;;
  esac

  phase "activate $ACTIVATE_CMD — apply closure LOCALLY (no SSH to disposable)"

  local rc
  do_activate "$ACTIVATE_CMD" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]]; then
    fail "Activate FAILED (exit $rc)."
    exit "$rc"
  fi
  ok "Activate SUCCEEDED."

  # Auto-destroy the disposable only for switch/boot without --keep. The
  # disposable (if any) is discovered from PVE; if multiple exist, skip the
  # auto-destroy and tell the user to clean up explicitly.
  if { [[ "$ACTIVATE_CMD" == "switch" || "$ACTIVATE_CMD" == "boot" ]]; } && ! $KEEP; then
    step "Auto-destroying disposable (command was $ACTIVATE_CMD, no --keep) ..."
    local matches count
    matches=$(discover_disposables)
    count=$(grep -c '^' <<<"$matches" || true)
    case "$count" in
      0)
        log "No disposable left on PVE — nothing to auto-destroy." ;;
      1)
        local vmid; read -r vmid _ _ <<<"$matches"
        destroy_ct "$vmid" ;;
      *)
        warn "Multiple disposables on PVE — skipping auto-destroy. Clean up explicitly:"
        while IFS= read -r line; do warn "  $line"; done <<<"$matches"
        warn "  e.g.  $0 destroy-builder <VMID>"
        ;;
    esac
  fi

  phase_done "activate $ACTIVATE_CMD"
}

cmd_destroy_builder() {
  require ssh "drive PVE"
  require_pve
  phase "destroy-builder — pct destroy --purge --force"
  local vmid
  vmid=$(resolve_vmid "${POSITIONAL_VMID:-}")
  destroy_ct "$vmid"
  phase_done "destroy-builder"
}

cmd_info() {
  require ssh "drive PVE"
  require_pve
  require jq  "discover + read container IP"

  phase "info — disposables on $PVE_HOST"

  # No explicit VMID: list every disposable.
  if [[ -z "$POSITIONAL_VMID" ]]; then
    local matches count
    matches=$(discover_disposables)
    if [[ -z "$matches" ]]; then
      log "No disposable containers on $PVE_HOST match '${CT_HOSTNAME_PREFIX}-*'."
      log "Start one with:  $0 start-builder"
      phase_done "info"
      return
    fi
    count=$(grep -c '^' <<<"$matches" || true)
    log "Found $count disposable(s) on $PVE_HOST:"
    while IFS= read -r line; do
      local v s n maybe_ip
      read -r v s n <<<"$line"
      maybe_ip=$(get_ct_ip "$v" 2>/dev/null || true)
      printf '  VMID=%-6s status=%-10s name=%-30s ip=%s\n' \
        "$v" "$s" "$n" "${maybe_ip:-(no ip)}" >&2
    done <<<"$matches"
    log "Inspect one in detail with: $0 info <VMID>"
    phase_done "info"
    return
  fi

  # Explicit VMID: detail view.
  local vmid hostname ip
  vmid="$POSITIONAL_VMID"
  hostname="$CT_HOSTNAME_PREFIX-$vmid"
  ip=$(get_ct_ip "$vmid")
  cat >&2 <<EOF
[pve-build] Disposable info
  VMID:             $vmid
  Hostname:         $hostname
  IP (eth0):        ${ip:-(unavailable — not running?)}
  PVE host:         $PVE_HOST
  SSH (hostname):   ssh ${DISPOSABLE_SSH_OPTS[*]} $BUILD_SSH_USER@$hostname
  pct enter:        ssh $PVE_HOST -t pct enter $vmid
  destroy:          $0 destroy-builder $vmid
EOF
  phase_done "info"
}

## ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
phase_done "Configuration"
case "$COMMAND" in
  build|test|switch|boot) cmd_composite ;;
  check-image)           cmd_check_image ;;
  deploy-image)          cmd_deploy_image ;;
  update-image)          cmd_update_image ;;
  start-builder)         cmd_start_builder ;;
  build-on)              cmd_build_on ;;
  activate)              cmd_activate ;;
  destroy-builder)       cmd_destroy_builder ;;
  info)                  cmd_info ;;
  *)                     die "Unknown command: $COMMAND" ;;
esac
