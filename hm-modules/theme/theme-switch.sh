# shellcheck shell=bash
# theme-switch — activate a pre-built Home Manager specialisation.
#
# Expects two variables to be injected by the Nix wrapper:
#   baseVariant        the variant that is the generation itself (not a
#                      specialisation), activated via `$gen/activate`.
#   availableVariants  space-separated list of all variant names (help text).
#
# Standalone usage for testing:
#   baseVariant=gruvbox-dark \
#   availableVariants="gruvbox-dark gruvbox-light catppuccin-dark catppuccin-light" \
#   bash theme-switch.sh <variant>

: "${baseVariant:?theme-switch: baseVariant not set}"
: "${availableVariants:?theme-switch: availableVariants not set}"
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
  echo "error: could not resolve Home Manager base generation" >&2
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
  echo "error: variant '$variant' not found at $activate" >&2
  echo "Available: ${availableVariants}"
  exit 1
fi

echo "Switching theme to $variant..."
exec "$activate"
