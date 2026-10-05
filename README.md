# caelestia-omarchy-themes

Gives a stock [Caelestia](https://github.com/caelestia-dots/shell) shell an
Omarchy theme picker.

Caelestia ships a **Colours** page under *Nexus → Wallpaper & style*, but on a
plain install it is a "Page under construction" stub. This drops a working page
in its place: a grid of the Omarchy themes installed on the machine, each with
its preview and accent. Picking one runs `omarchy-theme-set`, whose theme-set
hook (the Caelestia bridge) rewrites `~/.local/state/caelestia/scheme.json`,
which the shell watches — so the bar and Hyprland recolour to match.

## Requirements

- Arch-based system with `pacman`
- [Omarchy](https://omarchy.org) (for `omarchy-theme-set` and its themes)
- `caelestia-shell` installed (`/etc/xdg/quickshell/caelestia` present)

## Install

```sh
git clone https://github.com/thenobody0817/caelestia-omarchy-themes
cd caelestia-omarchy-themes
./install.sh
```

Then open **Nexus → Wallpaper & style → Colours**.

The installer needs `sudo` once, to drop a pacman hook in
`/etc/pacman.d/hooks/`. Run it as your normal user, not root.

## Uninstall

```sh
./uninstall.sh
```

Restores the stock stub and removes the hook and scripts.

## How it works

Caelestia loads its shell from the first of `~/.config/quickshell/caelestia` or
`/etc/xdg/quickshell/caelestia` that exists, and does not merge them. So this
keeps a small **overlay** tree and copies it over the packaged shell:

| Path | What |
|---|---|
| `~/.local/share/caelestia-shell-overlay/` | the overlay: the one QML page it replaces |
| `~/.local/bin/omarchy-caelestia-themes` | lists Omarchy themes as JSON for the page |
| `~/.local/bin/sync-caelestia-shell` | re-applies packaged + overlay to `~/.config/quickshell/caelestia` |
| `/etc/pacman.d/hooks/95-caelestia-shell-omarchy.hook` | runs the sync after every `caelestia-shell` upgrade |

A `caelestia-shell` upgrade replaces the packaged tree, so the hook re-applies
the overlay and restarts the shell. That is the whole trick.

## Credits

The page is a fork of `caelestia-shell`'s own `ColourSelect.qml`, which is
GPL-3.0-only; this repo is too (see [LICENSE](LICENSE)).
