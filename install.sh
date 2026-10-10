#!/usr/bin/env bash
# Make Omarchy the single source of theme truth for the Caelestia shell.
#
# Installs six things:
#
#   ~/.local/share/caelestia-shell-overlay/                the Colours page
#       The replacement QML page that lists Omarchy's themes.
#
#   ~/.local/bin/caelestia-theme-bridge                    the colour bridge
#       Translates the Omarchy palette into the files Caelestia reads.
#
#   ~/.local/bin/omarchy-caelestia-themes                  the page's data
#       Lists installed themes as JSON for the grid.
#
#   ~/.local/bin/sync-caelestia-shell                      the re-applier
#       Rebuilds the shell fork from the package plus the overlay.
#
#   ~/.config/omarchy/hooks/theme-set.d/caelestia-bridge   the theme-set hook
#       What actually makes a theme change take effect everywhere.
#
#   /etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook    the upgrade hook
#       Re-applies the page after each caelestia-shell upgrade.
#
# The last two are the point: the picker alone is inert. Picking a theme runs
# omarchy-theme-set, which knows nothing about Caelestia -- it is the theme-set
# hook that pushes the new palette into Caelestia's scheme, GTK, and wallpaper.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

OVERLAY="$HOME/.local/share/caelestia-shell-overlay"
BINDIR="$HOME/.local/bin"
OMARCHY_HOOKDIR="$HOME/.config/omarchy/hooks/theme-set.d"
PACKAGED=/etc/xdg/quickshell/caelestia
HOOK_DST="${CAELESTIA_OMARCHY_HOOK:-/etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook}"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (this script only sudo's for the pacman hook)"
command -v pacman >/dev/null 2>&1 || die "pacman not found; this is for Arch-based systems"
command -v omarchy-theme-set >/dev/null 2>&1 || die "Omarchy not found (no omarchy-theme-set in PATH)"
[[ -f $PACKAGED/shell.qml ]] || die "no packaged Caelestia shell at $PACKAGED"

# The user may have a copy from an earlier revision of this project. It is not
# ours to delete, but they should know two bridges now exist and only the one
# being installed is wired up.
if [[ -f $HOME/.config/caelestia-bridge/theme-bridge.py ]]; then
  echo "note: found an old bridge at ~/.config/caelestia-bridge/theme-bridge.py."
  echo "      It is no longer used; the installed one is at $BINDIR/caelestia-theme-bridge."
  echo
fi

say "Installing the Colours page"
mkdir -p "$OVERLAY"
cp -a "$REPO_DIR/overlay/." "$OVERLAY/"

say "Installing the bridge and helpers to $BINDIR"
mkdir -p "$BINDIR"
install -m755 "$REPO_DIR/bin/caelestia-theme-bridge" "$BINDIR/caelestia-theme-bridge"
install -m755 "$REPO_DIR/bin/sync-caelestia-shell" "$BINDIR/sync-caelestia-shell"
install -m755 "$REPO_DIR/bin/omarchy-caelestia-themes" "$BINDIR/omarchy-caelestia-themes"

say "Installing the Omarchy theme-set hook"
mkdir -p "$OMARCHY_HOOKDIR"
install -m755 "$REPO_DIR/hooks/omarchy-theme-set" "$OMARCHY_HOOKDIR/caelestia-bridge"

say "Installing the pacman hook (sudo)"
tmp=$(mktemp)
sed -e "s|@USER@|$(id -un)|g" -e "s|@HOME@|$HOME|g" \
    "$REPO_DIR/hooks/pacman/95-caelestia-shell-omarchy.hook.in" > "$tmp"
sudo install -Dm644 "$tmp" "$HOOK_DST"
rm -f "$tmp"

say "Syncing the shell fork and applying the current theme"
"$BINDIR/sync-caelestia-shell"
# Seed the palette now, so the shell is correct without waiting for a theme
# switch. Loud on purpose: the usual failure is that Omarchy has no current
# theme yet, and a silent no-op there looks exactly like this project not working.
if ! "$BINDIR/caelestia-theme-bridge" --emit-cli-scheme; then
  echo "note: no theme applied. This is normal if you have never set one --"
  echo "      pick one from Nexus, or seed it with:"
  echo "        caelestia-theme-bridge --emit-cli-scheme --theme NAME"
fi
"$BINDIR/sync-caelestia-shell" --restart

echo
say "Done. Open Nexus -> Wallpaper & style -> Colours."
