import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property color primaryColor: "#cba6f7"
    property color secondaryColor: "#b4befe"
    property color accentColor: "#89b4fa"
    property color backgroundColor: "#1e1e2e"
    property color surfaceColor: "#313244"
    property color textColor: "#cdd6f4"
    property color textMutedColor: "#a6adc8"
    property color successColor: "#a6e3a1"

    component CheckCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string iconText: ""
        property bool checked: false
        property bool isMaster: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 22
        radius: 12
        color: checked
               ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.18)
               : root.surfaceColor
        border.color: checked ? root.primaryColor : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.6)
        border.width: checked ? 2 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.toggled()
        }

        RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: 10
                color: card.checked
                       ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.3)
                       : Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.6)

                Text {
                    anchors.centerIn: parent
                    text: card.iconText
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    text: card.title
                    font.pixelSize: 15
                    font.bold: true
                    color: root.textColor
                    Layout.fillWidth: true
                }

                Text {
                    text: card.subtitle
                    font.pixelSize: 12
                    color: root.textMutedColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    visible: text.length > 0
                }
            }

            // Checkbox indicator
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 6
                color: card.checked ? root.primaryColor : "transparent"
                border.color: card.checked ? root.primaryColor : root.textMutedColor
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 14
                    font.bold: true
                    color: root.backgroundColor
                    visible: card.checked
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, 0.7)

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 20
            contentWidth: availableWidth
            clip: true

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    var flickable = scrollView.contentItem
                    var deltaY = event.angleDelta.y * 3.0
                    var newY = flickable.contentY - (deltaY / 120.0 * 40)
                    flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, newY))
                    event.accepted = true
                }
            }

            ColumnLayout {
                width: parent.width
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: qsTr("Émulation & Rétrogaming")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Sélectionnez le frontend et les émulateurs que vous souhaitez intégrer à votre système")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Global emulation switch
                CheckCard {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    title: qsTr("Activer la Suite d'Émulation (Recommandé)")
                    subtitle: qsTr("Création déclarative de ~/Jeux/ROMs et ~/Jeux/BIOS avec permissions complètes.")
                    iconText: "🕹️"
                    checked: engine.emulationEnable
                    onToggled: engine.setEmulationEnable(!engine.emulationEnable)
                }

                // Frontend & Retro Engine
                GridLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 14

                    CheckCard {
                        title: "ES-DE Frontend"
                        subtitle: qsTr("EmulationStation Desktop Edition avec jaquettes, thèmes et mise à jour automatique.")
                        iconText: "📺"
                        checked: engine.emulationFrontend === "es-de"
                        onToggled: engine.setEmulationFrontend(engine.emulationFrontend === "es-de" ? "none" : "es-de")
                    }

                    CheckCard {
                        title: "RetroArch & Cœurs Rétro"
                        subtitle: qsTr("Pack complet 2D/Arcade (SNES, Megadrive, NES, N64) et PlayStation 1 (SwanStation & Beetle PSX).")
                        iconText: "👾"
                        checked: engine.retroarchEnable
                        onToggled: engine.setRetroarchEnable(!engine.retroarchEnable)
                    }
                }

                // Standalone Emulators section title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Text {
                        text: qsTr("Émulateurs Dédiés Autonomes (Standalone Unstable)")
                        font.pixelSize: 16
                        font.bold: true
                        color: textColor
                    }
                    Text {
                        text: qsTr("Applications indépendantes sélectionnées pour leur compatibilité et leurs moteurs de rendu avancés.")
                        font.pixelSize: 12
                        color: textMutedColor
                    }
                }

                // Grid of Standalone Emulators
                GridLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 14

                    CheckCard {
                        title: "Nintendo Switch (Eden)"
                        subtitle: qsTr("Dernière version d'Eden (fork moderne de Yuzu & Sudachi) avec rendu Vulkan.")
                        iconText: "🔴"
                        checked: engine.eden
                        onToggled: engine.setEden(!engine.eden)
                    }

                    CheckCard {
                        title: "GameCube & Wii (Dolphin)"
                        subtitle: qsTr("Émulateur référence GameCube et Wii avec accélération Vulkan et compatibilité manettes.")
                        iconText: "🐬"
                        checked: engine.dolphin
                        onToggled: engine.setDolphin(!engine.dolphin)
                    }

                    CheckCard {
                        title: "PlayStation 1 (DuckStation)"
                        subtitle: qsTr("Émulateur PS1 de référence avec rendu Vulkan, upscaling 4K et correction PGXP.")
                        iconText: "🦆"
                        checked: engine.duckstation
                        onToggled: engine.setDuckstation(!engine.duckstation)
                    }

                    CheckCard {
                        title: "PlayStation 2 (PCSX2)"
                        subtitle: qsTr("Version moderne 2.6.x Qt/Vulkan avec upscaling haute résolution et correctifs 60 FPS.")
                        iconText: "🎮"
                        checked: engine.pcsx2
                        onToggled: engine.setPcsx2(!engine.pcsx2)
                    }

                    CheckCard {
                        title: "PlayStation Portable (PPSSPP)"
                        subtitle: qsTr("Émulateur PSP haute performance avec rendu Vulkan, shaders et textures HD.")
                        iconText: "📱"
                        checked: engine.ppsspp
                        onToggled: engine.setPpsspp(!engine.ppsspp)
                    }

                    CheckCard {
                        title: "Nintendo DS (melonDS)"
                        subtitle: qsTr("Émulateur DS autonome avec OpenGL/Vulkan, gestion double écran et tactile.")
                        iconText: "🍈"
                        checked: engine.melonds
                        onToggled: engine.setMelonds(!engine.melonds)
                    }

                    CheckCard {
                        title: "Nintendo 3DS (Azahar)"
                        subtitle: qsTr("Fork open-source moderne de Citra avec stéréoscopie, upscaling et rendu Vulkan.")
                        iconText: "🌸"
                        checked: engine.azahar
                        onToggled: engine.setAzahar(!engine.azahar)
                    }

                    CheckCard {
                        title: "Game Boy / GBC / GBA (mGBA)"
                        subtitle: qsTr("Interface autonome Qt complète, palettes Game Boy personnalisées et filtres.")
                        iconText: "🔋"
                        checked: engine.mgba
                        onToggled: engine.setMgba(!engine.mgba)
                    }

                    CheckCard {
                        title: "PlayStation 3 (RPCS3)"
                        subtitle: qsTr("Émulateur expérimental PS3 haute fidélité (nécessite un processeur puissant).")
                        iconText: "⚡"
                        checked: engine.rpcs3
                        onToggled: engine.setRpcs3(!engine.rpcs3)
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
