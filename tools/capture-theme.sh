#!/usr/bin/env bash
# Capture the Caelestia bar and desktop under different Omarchy themes.
#
# Switches a theme, waits for the shell to pick it up, captures, and puts the
# theme you started with back when it is done. That last part matters: these
# captures reload Hyprland and swap the wallpaper several times, so the tool
# should not leave your desktop on some arbitrary theme.
#
# The bar recolours live -- the theme-set hook rewrites the scheme file the shell
# watches -- so a short settle is usually enough. If a shot looks like the old
# theme, raise --wait.
#
# usage:
#   capture-theme.sh [options] THEME [THEME...]
#   capture-theme.sh --list
#
# options:
#   -o, --out DIR        where the PNGs go (default: docs)
#   -p, --prefix NAME    prefix each filename with NAME- (e.g. bar-hackerman.png)
#   -g, --geometry G     grim geometry to crop, as "x,y WxH"
#   -b, --bar            shorthand for a 60x800 crop of the left-hand bar
#   -f, --full           capture the whole output (the default)
#   -w, --wait SECS      how long to let a theme settle before shooting (default 2)
#   -n, --no-restore     leave the last theme applied instead of restoring yours
#   -l, --list           list the theme slugs available on this machine and exit
#   -h, --help           show this help
#
# Every PNG is captured at the output's native scale, so on a 2x panel they come
# out crisp -- which is what a README wants anyway.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die() { echo "error: $*" >&2; exit 1; }

# grim needs a live Wayland session, and this script is equally likely to be run
# from a terminal that has one as from one that does not. Take the environment
# from the running Caelestia shell when the current shell has none.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  pid=$(pgrep -f -- 'qs -c caelestia' | head -1 || true)
  [[ -n $pid ]] || die "no Wayland session found, and no Caelestia shell to copy one from"
  export WAYLAND_DISPLAY=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^WAYLAND_DISPLAY=//p')
  export XDG_RUNTIME_DIR=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^XDG_RUNTIME_DIR=//p')
fi
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || {
  export HYPRLAND_INSTANCE_SIGNATURE=$(tr '\0' '\n' < "/proc/${pid:-$(pgrep -f -- 'qs -c caelestia' | head -1)}/environ" \
                                         | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')
}

command -v grim     >/dev/null 2>&1 || die "grim not found; this needs a wlroots screenshot tool"
command -v omarchy-theme-set >/dev/null 2>&1 || die "omarchy-theme-set not found; are you on Omarchy?"
[[ ${1:-} != "--list" ]] || {
  echo "Themes available on this machine:"
  for d in "$HOME"/.config/omarchy/themes /usr/share/omarchy/themes; do
    [[ -d $d ]] || continue
    for t in "$d"/*/; do [[ -f $t/colors.toml ]] && basename "$t"; done
  done | sort -u | sed 's/^/  /'
  exit 0
}

OUT=docs
PREFIX=""
GEOMETRY=""
WAIT=2
RESTORE=true
FULL=true

themes=()
while (($#)); do
  case $1 in
    -o|--out)        OUT=$2; shift 2 ;;
    -p|--prefix)     PREFIX=$2; shift 2 ;;
    -g|--geometry)   GEOMETRY=$2; FULL=false; shift 2 ;;
    -b|--bar)        GEOMETRY="0,0 60x800"; FULL=false; shift ;;
    -f|--full)       FULL=true; GEOMETRY=""; shift ;;
    -w|--wait)       WAIT=$2; shift 2 ;;
    -n|--no-restore) RESTORE=false; shift ;;
    -l|--list)       exec "$0" --list ;;
    -h|--help)       sed -n '2,31p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)              die "unknown option: $1" ;;
    *)               themes+=("$1"); shift ;;
  esac
done

((${#themes[@]})) || die "no theme given; run '$0 --list' or '--help'"

# Remember where we started from, so a failed run or a Ctrl-C still restores it.
# A shell trap covers INT/TERM/EXIT, but not SIGKILL -- which is exactly how an
# agent's tool call gets cancelled. So the theme is also stamped to a state file
# before the first switch, and any later run restores from that stamp and removes
# it. That way an interrupted capture heals itself on the next one rather than
# leaving the desktop on whatever theme it happened to be killed on.
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-capture-theme"

if [[ -f $STATE_FILE ]]; then
  leftover=$(<"$STATE_FILE")
  if [[ -n $leftover ]] && [[ $leftover != "$(cat "$HOME"/.local/state/omarchy/current/theme.name 2>/dev/null)" ]]; then
    echo "note: a previous capture was interrupted while on '$leftover' -- restoring that now"
    omarchy-theme-set "$leftover" >/dev/null 2>&1 || true
    sleep 2
  fi
  rm -f "$STATE_FILE"
fi

current=$(cat "$HOME"/.local/state/omarchy/current/theme.name 2>/dev/null || true)
restore() {
  if $RESTORE && [[ -n $current ]]; then
    omarchy-theme-set "$current" >/dev/null 2>&1 || true
  fi
  rm -f "$STATE_FILE"
}
mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$current" > "$STATE_FILE"
trap restore EXIT

mkdir -p "$OUT"
echo "capturing ${#themes[@]} theme(s) into $OUT"

for theme in "${themes[@]}"; do
  name=$theme
  [[ -n $PREFIX ]] && name="$PREFIX-$theme"
  target="$OUT/$name.png"

  echo "  -> $theme"
  omarchy-theme-set "$theme" >/dev/null 2>&1 || die "omarchy-theme-set failed for '$theme'"

  # Give the shell's file watcher and the Hyprland reload time to land. The bar
  # and wallpaper change independently of each other, so this is a compromise.
  sleep "$WAIT"

  if $FULL; then
    grim "$target"
  else
    grim -g "$GEOMETRY" "$target"
  fi
  echo "     $target"
done

$RESTORE && [[ -n $current ]] && echo "restored your theme: $current"
echo "done"
