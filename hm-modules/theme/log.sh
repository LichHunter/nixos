# shellcheck shell=bash
# Colorful, TTY-aware logging helpers: log_info / log_warn / log_error.
#
# Everything is written to *stderr*, so a script's stdout stays a clean data
# channel (e.g. wallpaper-pick prints the chosen image path on stdout while
# its progress goes to stderr). Set SCRIPT_TAG to prefix every line with the
# originating script, e.g. "[theme-switch] selecting wallpaper...".
#
# Colors are auto-disabled when stderr isn't a terminal or NO_COLOR is set.
__theme_log_init() {
  if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
    __C_RESET=$'\033[0m'
    __C_INFO=$'\033[1;34m'   # blue
    __C_WARN=$'\033[1;33m'   # yellow
    __C_ERR=$'\033[1;31m'    # red
  else
    __C_RESET=""; __C_INFO=""; __C_WARN=""; __C_ERR=""
  fi
}
__theme_log_init

log_info()  { printf '%s%s%s%s\n' "${__C_INFO}" "${SCRIPT_TAG:+[$SCRIPT_TAG] }" "$*" "${__C_RESET}" >&2; }
log_warn()  { printf '%s%s%s%s\n' "${__C_WARN}" "${SCRIPT_TAG:+[$SCRIPT_TAG] }" "warning: $*" "${__C_RESET}" >&2; }
log_error() { printf '%s%s%s%s\n' "${__C_ERR}"  "${SCRIPT_TAG:+[$SCRIPT_TAG] }" "error: $*"   "${__C_RESET}" >&2; }
