#!/usr/bin/env bash
# Install the Omarchy theme picker into a stock Caelestia shell.
#
# Drops a "Colours" page (which lists Omarchy themes) into Caelestia's fork
# tree, the helper it calls, and a pacman hook that re-applies it after every
# caelestia-shell upgrade. See README.md.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

OVERLAY="$HOME/.local/share/caelestia-shell-overlay"
BINDIR="$HOME/.local/bin"
PACKAGED=/etc/xdg/quickshell/caelestia
HOOK_DST="${CAELESTIA_OMARCHY_HOOK:-/etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook}"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (this script sudo's only for the pacman hook)"
command -v pacman >/dev/null 2>&1 || die "pacman not found; this is for Arch-based systems"
[[ -x /usr/share/omarchy/bin/omarchy-theme-set ]] || die "Omarchy not found (no omarchy-theme-set)"
[[ -f $PACKAGED/shell.qml ]] || die "no packaged Caelestia shell at $PACKAGED"

say "Installing the Omarchy Colours page"
mkdir -p "$OVERLAY"
cp -a "$REPO_DIR/overlay/." "$OVERLAY/"

say "Installing helper and sync scripts to $BINDIR"
mkdir -p "$BINDIR"
install -m755 "$REPO_DIR/bin/omarchy-caelestia-themes" "$BINDIR/omarchy-caelestia-themes"
install -m755 "$REPO_DIR/bin/sync-caelestia-shell" "$BINDIR/sync-caelestia-shell"

say "Installing the pacman hook (sudo)"
tmp=$(mktemp)
sed -e "s|@USER@|$(id -un)|g" -e "s|@HOME@|$HOME|g" \
    "$REPO_DIR/hook/95-caelestia-shell-omarchy.hook.in" > "$tmp"
sudo install -Dm644 "$tmp" "$HOOK_DST"
rm -f "$tmp"

say "Syncing the shell and restarting it"
"$BINDIR/sync-caelestia-shell" --restart

echo
say "Done. Open Nexus -> Wallpaper & style -> Colours."
