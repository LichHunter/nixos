#!/usr/bin/env bash

# Enhanced script to simplify nixos-rebuild commands for this flake.

set -euo pipefail

# --- Find Flake Root ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FLAKE_ROOT=$(realpath "$SCRIPT_DIR/..")

# --- Configuration ---
DEFAULT_USERNAME=$(whoami)
DEFAULT_BUILD_HOST="izanagi@izanagi"

# --- Help Message ---
usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Enhanced wrapper for 'nixos-rebuild' for the flake at: $FLAKE_ROOT"
  echo ""
  echo "Commands:"
  echo "  build       Build the new configuration."
  echo "  test        Test the new configuration."
  echo "  switch      Switch to the new configuration."
  echo "  boot        Switch to the new configuration and make it the default for next boot."
  echo ""
  echo "Build/Target Options:"
  echo "  --local-build           Build on the local machine (default for local operations)"
  echo "  --build-host HOST       Specify remote build host (default: $DEFAULT_BUILD_HOST)"
  echo "  --target-host HOST      Deploy to remote target host"
  echo "  --use-remote-sudo       Use sudo on remote target host (auto-enabled for switch/boot on remote)"
  echo ""
  echo "Configuration Options:"
  echo "  --machine NAME          Machine configuration name (default: current hostname or username)"
  echo "  --flake PATH            Path to flake directory (default: $FLAKE_ROOT)"
  echo ""
  echo "Other Options:"
  echo "  --fast                  Skip building nix (useful for remote builds)"
  echo "  --show-trace            Show detailed error traces"
  echo "  --verbose               Enable verbose output"
  echo "  --dry-run               Show what would be built without building"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  # Local build and switch"
  echo "  $0 switch --local-build"
  echo ""
  echo "  # Build on izanagi, deploy locally"
  echo "  $0 build --build-host $DEFAULT_BUILD_HOST"
  echo ""
  echo "  # Build and deploy on remote machine"
  echo "  $0 switch --target-host user@remote-host"
  echo ""
  echo "  # Build on one host, deploy to another"
  echo "  $0 switch --build-host build-host --target-host deploy-host"
  echo ""
  echo "  # Build specific machine configuration"
  echo "  $0 build --machine susano --local-build"
  echo ""
  echo "Any other arguments are passed directly to 'nixos-rebuild'."
}

# --- Argument Parsing ---
COMMAND=""
MACHINE_NAME=""
FLAKE_PATH="$FLAKE_ROOT"
BUILD_HOST=""
TARGET_HOST=""
USE_LOCAL_BUILD=false
USE_REMOTE_SUDO=""
SHOW_TRACE=false
VERBOSE=false
DRY_RUN=false
FAST=false
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    build|test|switch|boot)
      if [[ -n "$COMMAND" ]]; then
        echo "Error: Only one command (build, test, switch, boot) can be specified." >&2
        exit 1
      fi
      COMMAND="$1"
      shift
      ;;
    --local-build)
      USE_LOCAL_BUILD=true
      BUILD_HOST=""
      shift
      ;;
    --build-host)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --build-host requires a hostname argument." >&2
        exit 1
      fi
      BUILD_HOST="$2"
      USE_LOCAL_BUILD=false
      shift 2
      ;;
    --target-host)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --target-host requires a hostname argument." >&2
        exit 1
      fi
      TARGET_HOST="$2"
      shift 2
      ;;
    --use-remote-sudo)
      USE_REMOTE_SUDO="--use-remote-sudo"
      shift
      ;;
    --machine)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --machine requires a machine name argument." >&2
        exit 1
      fi
      MACHINE_NAME="$2"
      shift 2
      ;;
    --flake)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --flake requires a path argument." >&2
        exit 1
      fi
      FLAKE_PATH="$2"
      shift 2
      ;;
    --fast)
      FAST=true
      shift
      ;;
    --show-trace)
      SHOW_TRACE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      PASSTHROUGH_ARGS+=("$1")
      shift
      ;;
  esac
done

# --- Validation ---
if [[ -z "$COMMAND" ]]; then
  echo "Error: No command (build, test, switch, boot) specified." >&2
  usage
  exit 1
fi

# --- Determine Machine Name ---
if [[ -z "$MACHINE_NAME" ]]; then
  if [[ -n "$TARGET_HOST" ]]; then
    # For remote targets, use the hostname from target-host if available
    MACHINE_NAME=$(echo "$TARGET_HOST" | sed 's/.*@//' | sed 's/\..*//')
  else
    # For local builds, try hostname first, then fall back to username
    MACHINE_NAME=$(hostname 2>/dev/null || echo "$DEFAULT_USERNAME")
  fi
fi

# --- Determine Build Strategy ---
if [[ -n "$TARGET_HOST" ]]; then
  # Remote deployment
  if [[ -z "$BUILD_HOST" && ! "$USE_LOCAL_BUILD" == true ]]; then
    # If no build host specified and not explicitly local, use target host for building
    BUILD_HOST="$TARGET_HOST"
  fi

  # Auto-enable remote sudo for switch/boot commands if not explicitly set
  if [[ -z "$USE_REMOTE_SUDO" && ("$COMMAND" == "switch" || "$COMMAND" == "boot") ]]; then
    USE_REMOTE_SUDO="--use-remote-sudo"
  fi
else
  # Local deployment
  if [[ -z "$BUILD_HOST" && ! "$USE_LOCAL_BUILD" == true ]]; then
    # Default to remote build host for local deployment
    BUILD_HOST="$DEFAULT_BUILD_HOST"
  fi
fi

# --- Sudo Check ---
SUDO_CMD=""
if [[ -z "$TARGET_HOST" && ("$COMMAND" == "test" || "$COMMAND" == "switch" || "$COMMAND" == "boot") ]]; then
  SUDO_CMD="sudo"
fi

# --- Construct Flake Reference ---
FLAKE_REF="$FLAKE_PATH#$MACHINE_NAME"

# --- Build Command ---
FULL_CMD=()
if [[ -n "$SUDO_CMD" ]]; then
  FULL_CMD+=("$SUDO_CMD")
fi

FULL_CMD+=("nixos-rebuild" "$COMMAND" "--flake" "$FLAKE_REF")

# Add build host if specified and not local build
if [[ -n "$BUILD_HOST" && ! "$USE_LOCAL_BUILD" == true ]]; then
  FULL_CMD+=("--build-host" "$BUILD_HOST")
fi

# Add target host if specified
if [[ -n "$TARGET_HOST" ]]; then
  FULL_CMD+=("--target-host" "$TARGET_HOST")
fi

# Add remote sudo if specified
if [[ -n "$USE_REMOTE_SUDO" ]]; then
  FULL_CMD+=("$USE_REMOTE_SUDO")
fi

# Add optional flags
if [[ "$FAST" == true ]]; then
  FULL_CMD+=("--fast")
fi

if [[ "$SHOW_TRACE" == true ]]; then
  FULL_CMD+=("--show-trace")
fi

if [[ "$VERBOSE" == true ]]; then
  FULL_CMD+=("--verbose")
fi

# Handle dry-run by modifying command
if [[ "$DRY_RUN" == true ]]; then
  case "$COMMAND" in
    build)
      FULL_CMD[$(( ${#FULL_CMD[@]} - 4 ))]="dry-build"  # Replace 'build' with 'dry-build'
      ;;
    switch|boot|test)
      FULL_CMD[$(( ${#FULL_CMD[@]} - 4 ))]="dry-activate"  # Replace command with 'dry-activate'
      ;;
  esac
fi

# Add any passthrough arguments
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
  FULL_CMD+=("${PASSTHROUGH_ARGS[@]}")
fi

# --- Display Configuration ---
echo "=============================================="
echo "NixOS Rebuild Configuration"
echo "=============================================="
echo "Command:        $COMMAND"
echo "Machine:        $MACHINE_NAME"
echo "Flake:          $FLAKE_REF"

if [[ -n "$TARGET_HOST" ]]; then
  echo "Target Host:    $TARGET_HOST"
else
  echo "Target Host:    localhost"
fi

if [[ "$USE_LOCAL_BUILD" == true ]]; then
  echo "Build Host:     localhost (local build)"
elif [[ -n "$BUILD_HOST" ]]; then
  echo "Build Host:     $BUILD_HOST"
else
  echo "Build Host:     localhost (local build)"
fi

if [[ -n "$USE_REMOTE_SUDO" ]]; then
  echo "Remote Sudo:    enabled"
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Mode:           DRY RUN (no actual changes)"
fi

echo "=============================================="
echo "Executing command:"
echo "  ${FULL_CMD[*]}"
echo "=============================================="

# --- Execute Command ---
"${FULL_CMD[@]}"

echo "=============================================="
echo "Done."
