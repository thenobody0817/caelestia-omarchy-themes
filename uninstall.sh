#!/usr/bin/env bash
# Remove the Omarchy/Caelestia bridge and restore the stock Colours page.
#
# Reverses install.sh exactly: the overlay page, the three helpers, the Omarchy
# theme-set hook and the pacman hook.
#
# The files the bridge *wrote* -- ~/.local/state/caelestia/scheme.json, GTK's
# gtk.css and thunar.css, Hyprland's scheme/current.lua -- are deliberately left
# alone. They are state, not configuration this project owns, and deleting them
# would leave the session on an undefined palette. They simply stop being
# updated, and Caelestia's own CLI takes over from there again.

set -euo pipefail

OVERLAY="$HOME/.local/share/caelestia-shell-overlay"
BINDIR="$HOME/.local/bin"
OMARCHY_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/caelestia-bridge"
PACKAGED=/etc/xdg/quickshell/caelestia
HOOK_DST="${CAELESTIA_OMARCHY_HOOK:-/etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook}"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (this script only sudo's for the pacman hook)"

say "Removing the Colours page from the overlay"
rm -f "$OVERLAY/modules/nexus/pages/wallandstyle/ColourSelect.qml"

say "Restoring the stock page in the live shell"
# Order matters: the overlay must still exist here, because sync-caelestia-shell
# refuses to run without it. The directories it leaves behind are pruned only
# afterwards.
if [[ -x $BINDIR/sync-caelestia-shell ]]; then
    "$BINDIR/sync-caelestia-shell" --restart ||
        echo "warning: re-sync failed -- the shell fork may still hold the picker page"
else
    echo "  (sync script already gone; re-syncing from the packaged tree)"
    rsync -a --delete "$PACKAGED/" "$HOME/.config/quickshell/caelestia/" || true
fi

say "Removing the empty overlay directories"
find "$OVERLAY" -type d -empty -delete 2>/dev/null || true

say "Removing the bridge and helpers"
rm -f "$BINDIR/caelestia-theme-bridge"
rm -f "$BINDIR/sync-caelestia-shell"
rm -f "$BINDIR/omarchy-caelestia-themes"

say "Removing the Omarchy theme-set hook"
rm -f "$OMARCHY_HOOK"

say "Removing the pacman hook (sudo)"
sudo rm -f "$HOOK_DST"

echo
say "Done. The stock Colours page is back and Omarchy theme switches no longer"
echo "     recolour Caelestia."
