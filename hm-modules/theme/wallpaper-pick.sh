# shellcheck shell=bash
# wallpaper-pick — print a random wallpaper from $wallpapersDir whose palette
# best matches the given theme variant. Per-image palettes are extracted once
# (ImageMagick) and cached, keyed by the (immutable) source path so a rebuild
# that changes the wallpaper set reindexes automatically.
#
# Matching uses several key colors on both sides: the variant's base16
# base00–base05 (the background→foreground neutral range) are each matched to
# their nearest wallpaper dominant color; the sum of those nearest distances
# is the score. A random image is picked from the lowest-score tier.
#
# Env (injected by the Nix wrapper):
#   wallpapersDir    directory of wallpaper images (~/Wallpapers, a git clone)
#   wallpaperRepo    git URL cloned into wallpapersDir on first use
#   variantSchemes   space-separated `variant:schemeFile` pairs (base16 YAML)
#   MAGICK           path to the ImageMagick `magick` binary
#   GIT              path to the `git` binary
# Arg: variant name (e.g. gruvbox-dark)

: "${wallpapersDir:?wallpaper-pick: wallpapersDir not set}"
: "${wallpaperRepo:?wallpaper-pick: wallpaperRepo not set}"
: "${variantSchemes:?wallpaper-pick: variantSchemes not set}"
: "${MAGICK:?wallpaper-pick: MAGICK not set}"
: "${GIT:?wallpaper-pick: GIT not set}"
set -euo pipefail

variant="${1:?usage: wallpaper-pick <variant>}"

# Ensure the wallpaper repo is cloned locally. The clone is a one-time cost
# paid on first use (not at build time), keeping `nix build` fast.
if [ ! -d "$wallpapersDir/.git" ]; then
  log_info "cloning wallpaper repo (one-time, may take a few minutes)..."
  mkdir -p "$(dirname "$wallpapersDir")"
  "$GIT" clone --depth=1 --single-branch "$wallpaperRepo" "$wallpapersDir" >&2
  log_info "clone ready"
fi

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-pick"
palettes="$cache_dir/palettes.tsv"
stamp_file="$cache_dir/source"

# Cache key: the clone's current commit, so a `git pull` reindexes. Falls back
# to the resolved path if git fails for some reason.
src_stamp="$("$GIT" -C "$wallpapersDir" rev-parse HEAD 2>/dev/null || readlink -f "$wallpapersDir")"

rebuild_cache() {
  img_count="$(find "$wallpapersDir" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -printf . 2>/dev/null | wc -c)"
  log_info "indexing ${img_count} wallpapers (one-time, building palette cache)..."
  mkdir -p "$cache_dir"
  tmp="$palettes.tmp"
  : > "$tmp"
  jobs="$(nproc 2>/dev/null || echo 4)"

  # For each image: top dominant colors (by pixel count) as space-separated #hex.
  find "$wallpapersDir" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 \
    | xargs -0 -P "$jobs" -n1 sh -c '
        MAGICK="$0" img="$1"
        "$MAGICK" "$img" -resize 128x128^ -gravity center -extent 128x128 +dither -colors 8 -format "%c" histogram:info: 2>/dev/null \
          | grep -E "^[[:space:]]*[0-9]+:" | sort -rn | grep -oE "#[0-9A-Fa-f]{6}" | head -6 | paste -sd" " - \
          | { read -r hex; [ -n "$hex" ] && printf "%s\t%s\n" "$img" "$hex"; }
      ' "$MAGICK" >> "$tmp" || true

  mv "$tmp" "$palettes"
  printf '%s\n' "$src_stamp" > "$stamp_file"
}

if [ ! -f "$palettes" ] || [ ! -f "$stamp_file" ] || [ "$(cat "$stamp_file")" != "$src_stamp" ]; then
  rebuild_cache
fi

# Resolve the base16 scheme file for the requested variant.
scheme=""
for pair in $variantSchemes; do
  case "$pair" in
    "${variant}":*) scheme="${pair#*:}"; break ;;
  esac
done
[ -n "$scheme" ] || { log_error "no scheme mapped for variant '$variant'"; exit 2; }

# Theme key colors: base00–base05 hex (one per line, with leading #).
theme_colors="$(grep -E '^[[:space:]]*base0[0-5]:' "$scheme" | grep -oE '#[0-9A-Fa-f]{6}')"
[ -n "$theme_colors" ] || { log_error "could not parse base00–05 from $scheme"; exit 2; }

# hex (no #) -> decimal rgb on stdout
hex2dec() { printf '%d %d %d\n' "$((16#${1:0:2}))" "$((16#${1:2:2}))" "$((16#${1:4:2}))"; }

# Theme colors as parallel arrays.
t_r=(); t_g=(); t_b=()
while read -r h; do
  read -r r g b < <(hex2dec "${h#\#}")
  t_r+=("$r"); t_g+=("$g"); t_b+=("$b")
done <<< "$theme_colors"

# Score every indexed wallpaper: sum over theme colors of nearest wallpaper color.
scores="$cache_dir/scores.tmp"
: > "$scores"
while IFS=$'\t' read -r path whexes; do
  w_r=(); w_g=(); w_b=()
  for wh in $whexes; do
    read -r wr wg wb < <(hex2dec "${wh#\#}")
    w_r+=("$wr"); w_g+=("$wg"); w_b+=("$wb")
  done
  if [ "${#w_r[@]}" -eq 0 ]; then continue; fi
  total=0
  for i in "${!t_r[@]}"; do
    mind=1000000000
    for j in "${!w_r[@]}"; do
      dr=$(( t_r[i] - w_r[j] )); dg=$(( t_g[i] - w_g[j] )); db=$(( t_b[i] - w_b[j] ))
      cd=$(( dr*dr + dg*dg + db*db ))
      if [ "$cd" -lt "$mind" ]; then mind=$cd; fi
    done
    total=$(( total + mind ))
  done
  printf '%s\t%s\n' "$total" "$path"
done < "$palettes" | sort -n -k1 > "$scores"

[ -s "$scores" ] || { log_error "no wallpapers indexed"; exit 3; }

# Matched tier: within 1.4x of the best score (fall back to closest 20).
best="$(head -n1 "$scores" | cut -f1)"
threshold=$(( best * 14 / 10 ))
matched="$(awk -F'\t' -v t="$threshold" '$1 <= t {print $2}' "$scores")"
if [ "$(printf '%s\n' "$matched" | grep -c .)" -lt 5 ]; then
  matched="$(head -n20 "$scores" | cut -f2)"
fi

# Print the chosen PATH on stdout (data channel for callers) and log the
# human-readable choice on stderr.
chosen="$(printf '%s\n' "$matched" | shuf -n1)"
log_info "picked $(basename "$chosen") for ${variant}"
printf '%s\n' "$chosen"
