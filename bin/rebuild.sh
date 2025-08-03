#!/usr/bin/env bash

# A script to simplify nixos-rebuild commands for this flake.

set -euo pipefail

# --- Find Flake Root ---
# Get the directory of this script, then find the real path to its parent directory.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FLAKE_ROOT=$(realpath "$SCRIPT_DIR/..")

# --- Configuration ---
# Default user to build for.
# This is used to construct the flake reference (e.g., .#fujin).
USERNAME=$(whoami)

# --- Help Message ---
usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "A wrapper for 'nixos-rebuild' for the flake at: $FLAKE_ROOT"
  echo ""
  echo "Commands:"
  echo "  build       Build the new configuration."
  echo "  test        Test the new configuration."
  echo "  switch      Switch to the new configuration."
  echo "  boot        Switch to the new configuration and make it the default for next boot."
  echo ""
  echo "Options:"
  echo "  --local-build   Build on the local machine instead of the default remote builder."
  echo "  -h, --help      Show this help message."
  echo ""
  echo "Any other arguments are passed directly to 'nixos-rebuild'."
}

# --- Argument Parsing ---
COMMAND=""
BUILD_ARGS=("--build-host" "izanagi")
PASSTHROUGH_ARGS=()

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

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
      BUILD_ARGS=()
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

# --- Sudo Check ---
SUDO_CMD=""
if [[ "$COMMAND" == "test" || "$COMMAND" == "switch" || "$COMMAND" == "boot" ]]; then
  SUDO_CMD="sudo"
fi

# --- Flake Reference ---
FLAKE_REF="$FLAKE_ROOT#$USERNAME"

# --- Command Execution ---
# We build the command in an array to handle arguments with spaces correctly.
FULL_CMD=()
if [[ -n "$SUDO_CMD" ]]; then
  FULL_CMD+=("$SUDO_CMD")
fi
FULL_CMD+=("nixos-rebuild" "$COMMAND" "--flake" "$FLAKE_REF")
if [[ ${#BUILD_ARGS[@]} -gt 0 ]]; then
  FULL_CMD+=("${BUILD_ARGS[@]}")
fi
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
  FULL_CMD+=("${PASSTHROUGH_ARGS[@]}")
fi


echo "Building for user: $USERNAME on host: $(hostname)"
echo "Flake reference:   $FLAKE_REF"
echo "Executing command:"
echo "  ${FULL_CMD[@]}"
echo "-----------------------------------------------------"

"${FULL_CMD[@]}"

echo "-----------------------------------------------------"
echo "Done."
