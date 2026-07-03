# shellcheck shell=bash
# set-wallpaper — bind the runtime wallpaper symlink to $1 and restart hyprpaper
# so it picks up the new image. hyprpaper's config (managed by Home Manager)
# points at the symlink, so we never write hyprpaper config ourselves.
#
# Env (injected by the Nix wrapper):
#   wallpaperSymlink  path to the symlink hyprpaper's `wallpaper.path` reads
# Arg: image path

: "${wallpaperSymlink:?set-wallpaper: wallpaperSymlink not set}"
set -euo pipefail

target="${1:?usage: set-wallpaper <image-path>}"
[ -f "$target" ] || { log_error "not a file: $target"; exit 1; }

mkdir -p "$(dirname "$wallpaperSymlink")"
ln -sfn "$target" "$wallpaperSymlink"

# Apply live by (re)starting the user hyprpaper service. `systemctl restart`
# starts the unit even if it is inactive — important because a freshly-added
# hyprpaper service won't be running until the first switch. Tolerate the
# service being absent (e.g. on a host without hyprpaper).
if command -v systemctl >/dev/null 2>&1 && systemctl --user restart hyprpaper 2>/dev/null; then
  log_info "applied $(basename "$target") (hyprpaper started)"
else
  log_warn "could not start hyprpaper; wallpaper symlink set but not displayed"
fi
