pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// From caelestia-omarchy-themes:
// https://github.com/thenobody0817/caelestia-omarchy-themes
//
// Forked from caelestia-shell v2.5.0, where this page was a "Page under
// construction" stub. Omarchy owns theming here, so the page lists Omarchy's
// themes instead of Caelestia's own schemes. Picking one runs
// `omarchy-theme-set`, whose theme-set hook (~/.config/omarchy/hooks/theme-set.d/
// caelestia-bridge) rewrites ~/.local/state/caelestia/scheme.json, which
// services/Colours.qml watches -- so the bar recolours to match.
//
// Re-applied over the packaged shell by bin/sync-caelestia-shell, which the
// pacman hook runs after each caelestia-shell upgrade.
PageBase {
    id: root

    title: Tr.tr("Colours")
    isSubPage: true

    property var themes: []

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        implicitHeight: layout.implicitHeight

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Tokens.spacing.large

            StyledText {
                text: Tr.tr("Omarchy themes")
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Picking a theme recolours Caelestia and Hyprland to match.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Config.nexus.wallpapersPerRow)
                rowSpacing: Tokens.spacing.medium
                columnSpacing: Tokens.spacing.large

                Repeater {
                    model: root.themes

                    ThemeCard {
                        required property var modelData

                        Layout.fillWidth: true
                        theme: modelData
                        onClicked: Quickshell.execDetached(["omarchy-theme-set", modelData.slug])
                    }
                }
            }
        }

        Process {
            id: listProc

            running: true
            command: [`${Paths.home}/.local/bin/omarchy-caelestia-themes`]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.themes = JSON.parse(text);
                    } catch (e) {
                        console.warn("caelestia.nexus", "failed to parse Omarchy themes:", e);
                        root.themes = [];
                    }
                }
            }
        }
    }

    component ThemeCard: Item {
        id: card

        required property var theme
        signal clicked

        implicitHeight: cardLayout.implicitHeight

        ColumnLayout {
            id: cardLayout

            anchors.fill: parent
            spacing: Tokens.spacing.small

            StyledClippingRect {
                Layout.fillWidth: true
                implicitHeight: width * 0.6
                radius: Tokens.rounding.largeIncreased
                // Themes without a preview (rare) fall back to their accent.
                color: card.theme.preview ? Colours.tPalette.m3surfaceContainer : `#${card.theme.accent}`

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: card.theme.preview ?? ""
                    visible: status === Image.Ready
                }

                StyledRect {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.small
                    visible: card.theme.current
                    implicitWidth: check.implicitHeight + Tokens.padding.small * 2
                    implicitHeight: check.implicitHeight + Tokens.padding.small * 2
                    color: Colours.palette.m3primary
                    radius: Tokens.rounding.full

                    MaterialIcon {
                        id: check

                        anchors.centerIn: parent
                        text: "check"
                        color: Colours.palette.m3onPrimary
                        fontStyle: Tokens.font.icon.small
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: card.theme.name
                color: card.theme.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.small.weight(card.theme.current ? Font.Medium : Font.Normal).build()
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        StateLayer {
            onClicked: card.clicked()
        }
    }
}
