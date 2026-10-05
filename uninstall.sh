#!/usr/bin/env bash
# Remove the Omarchy theme picker and restore the stock Caelestia Colours page.

set -euo pipefail

OVERLAY="$HOME/.local/share/caelestia-shell-overlay"
BINDIR="$HOME/.local/bin"
HOOK_DST="${CAELESTIA_OMARCHY_HOOK:-/etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook}"
PAGE="$OVERLAY/modules/nexus/pages/wallandstyle/ColourSelect.qml"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (this script sudo's only for the pacman hook)"

say "Removing the Omarchy Colours page"
rm -f "$PAGE"
# Prune the overlay dirs this page created, but leave any other overlay content alone.
find "$OVERLAY" -type d -empty -delete 2>/dev/null || true

say "Restoring the stock page in the live shell"
if [[ -x $BINDIR/sync-caelestia-shell ]]; then
    "$BINDIR/sync-caelestia-shell" --restart
else
    echo "  (sync script already gone; re-syncing from the packaged tree)"
    rsync -a --delete /etc/xdg/quickshell/caelestia/ "$HOME/.config/quickshell/caelestia/"
fi

say "Removing helper and sync scripts"
rm -f "$BINDIR/omarchy-caelestia-themes" "$BINDIR/sync-caelestia-shell"

say "Removing the pacman hook (sudo)"
sudo rm -f "$HOOK_DST"

echo
say "Done. The stock Colours page is back."
