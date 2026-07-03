# shellcheck shell=bash
# theme-switch — activate a pre-built Home Manager specialisation.
#
# Expects these variables to be injected by the Nix wrapper:
#   baseVariant        the variant that is the generation itself (not a
#                      specialisation), activated via `$gen/activate`.
#   availableVariants  space-separated list of all variant names (help text).
#   doomThemes         optional space-separated `variant:doomtheme` pairs for
#                      the best-effort Doom Emacs live-switch (may be empty).
#
# Standalone usage for testing:
#   baseVariant=gruvbox-dark \
#   availableVariants="gruvbox-dark gruvbox-light catppuccin-dark catppuccin-light" \
#   doomThemes="gruvbox-dark:doom-gruvbox" \
#   bash theme-switch.sh <variant>

: "${baseVariant:?theme-switch: baseVariant not set}"
: "${availableVariants:?theme-switch: availableVariants not set}"
: "${doomThemes:=}"
set -euo pipefail

variant="${1:-}"

if [ -z "$variant" ]; then
  echo "Usage: theme-switch <variant>"
  echo "Available: ${availableVariants}"
  exit 1
fi

# Resolve the Home Manager *base* generation — the one built by NixOS that
# actually contains the `specialisation/` directory holding every variant's
# activation script.
#
# IMPORTANT: do NOT use `current-home` / the HM profile as the primary
# source. Activating a specialisation repoints those to the specialisation's
# *leaf* generation, which has no `specialisation/` of its own — so after
# switching once, every other variant (and the base) would become unfindable.
# The NixOS-managed `home-manager-«user».service` unit references the base
# generation and only changes on a rebuild.
user="${USER:-$(id -un)}"
gen=""
if unit="$(systemctl cat "home-manager-${user}.service" 2>/dev/null)"; then
  gen="$(printf '%s\n' "$unit" | grep -oE '/nix/store/[0-9a-z]+-home-manager-generation' | head -n1)"
fi

# Fallbacks for standalone Home Manager, where the profile symlink / gcroot
# points at the base generation (not a specialisation leaf).
for candidate in \
  "${HOME}/.local/state/home-manager/gcroots/current-home" \
  "/nix/var/nix/profiles/per-user/${user}/home-manager" \
  "${HOME}/.local/state/home-manager/home-manager-generation"
do
  [ -n "$gen" ] && break
  if [ -e "$candidate" ]; then
    gen="$(readlink -e "$candidate")" || gen=""
  fi
done

if [ -z "$gen" ]; then
  log_error "could not resolve Home Manager base generation"
  exit 1
fi

case "$variant" in
  "${baseVariant}")
    # Base variant is the generation itself, not a specialisation.
    activate="$gen/activate"
    ;;
  *)
    activate="$gen/specialisation/$variant/activate"
    ;;
esac

if [ ! -x "$activate" ]; then
  log_error "variant '$variant' not found at $activate"
  log_info "available: ${availableVariants}"
  exit 1
fi

log_info "switching theme to ${variant}"

# Best-effort: live-switch the running Doom Emacs daemon too. No config
# files are touched; if the daemon isn't running or emacsclient isn't
# installed (e.g. on a server), this is silently skipped.
doom_theme=""
if [ -n "$doomThemes" ]; then
  for pair in $doomThemes; do
    case "$pair" in
      "${variant}":*) doom_theme="${pair#*:}"; break ;;
    esac
  done
fi
if [ -n "$doom_theme" ]; then
  if command -v emacsclient >/dev/null 2>&1 \
     && emacsclient --eval "(progn (mapc (function disable-theme) custom-enabled-themes) (load-theme (quote ${doom_theme}) t))" >/dev/null 2>&1; then
    log_info "doom: ${doom_theme}"
  else
    log_warn "doom theme not applied (daemon not running or '${doom_theme}' not installed)"
  fi
fi

# Pick a palette-matching wallpaper and apply it. This BLOCKS — on the very
# first run wallpaper-pick clones the wallpaper repo and builds the palette
# index, which can take a few minutes; progress is logged on stderr by the
# pick/set scripts. Failures fall back to leaving the wallpaper unchanged.
if [ "${wallpapersEnabled:-0}" = "1" ] && [ -n "${wallpaperPickBin:-}" ] && [ -n "${wallpaperSetBin:-}" ]; then
  if wp="$("$wallpaperPickBin" "$variant")" && [ -n "$wp" ]; then
    "$wallpaperSetBin" "$wp" || log_warn "wallpaper apply failed"
  else
    log_warn "wallpaper selection failed; leaving wallpaper unchanged"
  fi
fi

log_info "activating Home Manager specialisation"
exec "$activate"
