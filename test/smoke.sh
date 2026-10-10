#!/usr/bin/env bash
# Smoke tests for the parts that can be checked without a live Wayland session.
#
# Everything here is read-only apart from a scratch directory under TMPDIR: it
# never touches the real overlay, ~/.local/bin, or any directory in ~/.config.
# The tests that need a real install check for prerequisites first and skip
# loudly rather than inventing a fake environment.

set -uo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BIN="$REPO_DIR/bin"

if [[ -t 1 ]]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
  GREEN=''; RED=''; DIM=''; BOLD=''; OFF=''
fi

pass=0 fail=0 skipped=0
ok()   { printf '  %sok%s    %s\n' "$GREEN" "$OFF" "$1"; pass=$((pass+1)); }
bad()  { printf '  %sFAIL%s  %s\n' "$RED" "$OFF" "$1"; fail=$((fail+1)); }
maybe(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
skip() { printf '  skip   %s%s%s\n' "$DIM" "$1" "$OFF"; skipped=$((skipped+1)); }
hdr()  { printf '\n%s%s%s\n' "${BOLD}" "$1" "$OFF"; }

THEMES_DIRS=("$HOME/.config/omarchy/themes" /usr/share/omarchy/themes)
mapfile -t THEMES < <(find "${THEMES_DIRS[@]}" -mindepth 1 -maxdepth 1 -type d \
                      -name '*.colors' -prune -o -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
                      xargs -r -n1 basename 2>/dev/null | sort -u)

# Scratch roots, both cleaned up on exit. Kept out of the real HOME so nothing
# here can touch a live shell.
sandbox=""
fresh=""
trap 'rm -rf "$sandbox" "$fresh"' EXIT

printf '%s\n' "${BOLD}caelestia-omarchy-themes smoke tests${OFF}"

# --------------------------------------------------------------------------
hdr "theme listing"

if [[ -x $BIN/omarchy-caelestia-themes ]]; then
  list=$("$BIN/omarchy-caelestia-themes")
  maybe "omarchy-caelestia-themes emits valid JSON" \
        "python3 -c 'import json,sys; json.load(sys.stdin)' <<<\"\$list\""

  # Every entry needs the six keys the QML page reads, and accents must be six
  # hex digits -- the page hands them straight to a Qt colour.
  jsonfile=$(mktemp); printf '%s\n' "$list" > "$jsonfile"
  python3 - "$jsonfile" <<'PY' && ok "every entry has the keys the QML page reads" \
                             || bad "every entry has the keys the QML page reads"
import json, re, sys
required = {"slug", "name", "mode", "accent", "preview", "current"}
for t in json.load(open(sys.argv[1])):
    if not required <= t.keys():
        sys.exit(1)
    if t["mode"] not in ("dark", "light"):
        sys.exit(1)
    if not re.fullmatch(r"[0-9A-F]{6}", t["accent"]):
        sys.exit(1)
PY
  rm -f "$jsonfile"
else
  skip "omarchy-caelestia-themes (binary missing)"
fi

# --------------------------------------------------------------------------
hdr "colour bridge --dry-run"

if [[ -x $BIN/caelestia-theme-bridge ]]; then
  if ((${#THEMES[@]})); then
    # Cover both base palettes: the first theme, plus the first light one, if
    # any theme declares itself light.
    colors_of() { for d in "${THEMES_DIRS[@]}"; do
                    [[ -f $d/$1/colors.toml ]] && { printf '%s\n' "$d/$1/colors.toml"; return; }
                  done; }

    sample=("${THEMES[0]}")
    for t in "${THEMES[@]}"; do
      colors=$(colors_of "$t")
      [[ -n $colors ]] || continue
      grep -qi '^[[:space:]]*mode.*light' "$colors" && { sample=("${THEMES[0]}" "$t"); break; }
    done

    for theme in "${sample[@]}"; do
      out=$("$BIN/caelestia-theme-bridge" --dry-run --theme "$theme" 2>&1); rc=$?
      maybe "theme '$theme': exits 0"            "[[ $rc -eq 0 ]]"
      maybe "theme '$theme': reports a scheme"    "grep -q '^keys *:' <<<\"\$out\""
      maybe "theme '$theme': promises no writes"  "grep -qi 'nothing written' <<<\"\$out\""
    done
  else
    skip "bridge (no Omarchy themes installed)"
  fi

  # The point of --dry-run is that nothing lands. Compare the mtime of the one
  # file whose absence we can safely observe, rather than trusting the banner.
  before=$(stat -c %Y "$HOME/.local/state/caelestia/scheme.json" 2>/dev/null || echo 0)
  "$BIN/caelestia-theme-bridge" --dry-run --emit-cli-scheme --theme "${THEMES[0]:-catppuccin}" >/dev/null 2>&1
  after=$(stat -c %Y "$HOME/.local/state/caelestia/scheme.json" 2>/dev/null || echo 0)
  maybe "--dry-run --emit-cli-scheme writes no scheme.json" "[[ $before == $after ]]"

  # Regression: on a fresh install ~/.config/hypr/scheme/ does not exist yet, and
  # creating it is the bridge's own job. It must not mistake that absence for
  # "Caelestia is not installed" and skip every Caelestia-specific write.
  #
  # Use a *system* theme here: the sandbox has its own empty HOME, so a theme
  # installed under ~/.config/omarchy/themes would be invisible to it.
  system_theme=$(find /usr/share/omarchy/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | head -1)
  if [[ -z $system_theme ]]; then
    skip "bridge bootstrap (no system themes to test against)"
  else
    fresh=$(mktemp -d)
    out=$(env -u XDG_STATE_HOME HOME="$fresh" "$BIN/caelestia-theme-bridge" \
            --emit-cli-scheme --theme "$system_theme" 2>&1); rc=$?
    maybe "fresh install, no hypr/scheme ($system_theme): exits 0" "[[ $rc -eq 0 ]]"
    maybe "fresh install: creates hypr/scheme/current.lua" \
          "[[ -f $fresh/.config/hypr/scheme/current.lua ]]"
    maybe "fresh install: seeds the shell's scheme.json" \
          "[[ -f $fresh/.local/state/caelestia/scheme.json ]]"
  fi
else
  skip "bridge (binary missing)"
fi

# --------------------------------------------------------------------------
hdr "shell sync: drift backup"

if [[ -d /etc/xdg/quickshell/caelestia ]]; then
  sandbox=$(mktemp -d)
  home="$sandbox/home"
  mkdir -p "$home/.config/quickshell/caelestia/modules/nexus/pages/wallandstyle" \
           "$home/.local/share/caelestia-shell-overlay"
  cp -a "$REPO_DIR/overlay/." "$home/.local/share/caelestia-shell-overlay/"

  # A fork with three kinds of content: a file the package will overwrite, a
  # file the package will delete, and the overlay page, which is ours and must
  # never be reported as someone else's drift.
  cp /etc/xdg/quickshell/caelestia/shell.qml \
     "$home/.config/quickshell/caelestia/shell.qml"
  printf '/* local edit */\n' >> "$home/.config/quickshell/caelestia/shell.qml"
  printf 'stray\n' > "$home/.config/quickshell/caelestia/stray.qml"
  cp "$REPO_DIR/overlay/modules/nexus/pages/wallandstyle/ColourSelect.qml" \
     "$home/.config/quickshell/caelestia/modules/nexus/pages/wallandstyle/ColourSelect.qml"

  note=$(env -u XDG_STATE_HOME HOME="$home" "$BIN/sync-caelestia-shell" 2>&1)

  maybe "reports the file the package will overwrite" \
        "grep -q '[[:space:]]shell.qml$' <<<\"\$note\""
  maybe "reports the stray file that will be deleted" \
        "grep -q '[[:space:]]stray.qml$' <<<\"\$note\""
  maybe "does NOT report the overlay page as drift" \
        "! grep -q 'ColourSelect.qml' <<<\"\$note\""

  backup=$(find "$home/.local/state/caelestia-shell-backup" -mindepth 1 -maxdepth 1 -type d | head -1)
  maybe "backs the overwritten file up" \
        "[[ -n \$backup && -f \$backup/shell.qml ]]"
  maybe "backs the stray file up before deleting it" \
        "[[ -n \$backup && -f \$backup/stray.qml ]]"
  maybe "leaves the overlay page out of the backup" \
        "[[ -z \$backup || ! -e \$backup/modules/nexus/pages/wallandstyle/ColourSelect.qml ]]"

  # A second sync should be quiet: the fork now matches package plus overlay.
  again=$(env -u XDG_STATE_HOME HOME="$home" "$BIN/sync-caelestia-shell" 2>&1)
  maybe "a second sync reports no drift" "! grep -q '^note:' <<<\"\$again\""
else
  skip "shell sync (no packaged Caelestia found)"
fi

# --------------------------------------------------------------------------
printf '\n%s\n' "$pass passed, $fail failed, $skipped skipped"
(( fail )) && exit 1
exit 0
