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
        property string warningText: ""
        property string iconText: ""
        property bool checked: false
        property bool isMaster: false
        property bool isOptionEnabled: true
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 22
        radius: 12
        opacity: isOptionEnabled ? 1.0 : 0.45
        color: checked
               ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.18)
               : root.surfaceColor
        border.color: checked ? root.primaryColor : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.6)
        border.width: checked ? 2 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            cursorShape: card.isOptionEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: if (card.isOptionEnabled) card.toggled()
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

                Text {
                    text: card.warningText
                    font.pixelSize: 11
                    font.bold: true
                    color: "#f9e2af"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    visible: card.warningText.length > 0
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
                        text: qsTr("Jeux Vidéo & Divertissement")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Cochez les lanceurs et outils de jeu que vous souhaitez installer")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Global gaming suite switch
                CheckCard {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    title: "Suite Système Gaming (Recommandé)"
                    subtitle: qsTr("Optimisations de performances (GameMode, GameScope), streaming Sunshine et compatibilité Wine/Proton.")
                    iconText: "🎮"
                    checked: engine.gamingEnable
                    onToggled: engine.setGamingEnable(!engine.gamingEnable)
                }

                // Grid of launchers
                GridLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 14

                    CheckCard {
                        title: "Steam"
                        subtitle: qsTr("Plateforme Valve avec Proton intégré pour exécuter vos jeux Windows.")
                        iconText: "🕹️"
                        checked: engine.steam
                        onToggled: engine.setSteam(!engine.steam)
                    }

                    CheckCard {
                        title: qsTr("Session Steam GameScope")
                        subtitle: qsTr("Session graphique plein écran dédiée GameScope (mode console / Steam Deck).")
                        warningText: engine.isNvidiaGpu ? qsTr("⚠️ Non disponible sur GPU NVIDIA (incompatibilité session Wayland)") : ""
                        isOptionEnabled: !engine.isNvidiaGpu
                        iconText: "📺"
                        checked: !engine.isNvidiaGpu && engine.gamescopeSession
                        onToggled: engine.setGamescopeSession(!engine.gamescopeSession)
                    }

                    CheckCard {
                        title: "Lutris"
                        subtitle: qsTr("Gestionnaire de jeux pour Battle.net, EA App, Ubisoft Connect et émulateurs.")
                        iconText: "🍷"
                        checked: engine.lutris
                        onToggled: engine.setLutris(!engine.lutris)
                    }

                    CheckCard {
                        title: "Heroic Games Launcher"
                        subtitle: qsTr("Lanceur open source performant pour Epic Games Store et GOG.")
                        iconText: "🦸"
                        checked: engine.heroic
                        onToggled: engine.setHeroic(!engine.heroic)
                    }

                    CheckCard {
                        title: "Faugus Launcher"
                        subtitle: qsTr("Lanceur moderne et léger dédié aux jeux Windows sous Wine/Proton.")
                        iconText: "🎯"
                        checked: engine.faugus
                        onToggled: engine.setFaugus(!engine.faugus)
                    }

                    CheckCard {
                        title: "NVIDIA GeForce NOW"
                        subtitle: qsTr("Client de cloud-gaming officiel pour jouer en streaming haute fidélité.")
                        iconText: "☁️"
                        checked: engine.geforceNow
                        onToggled: engine.setGeforceNow(!engine.geforceNow)
                    }

                    CheckCard {
                        title: "Decky Loader"
                        subtitle: qsTr("Gestionnaire de plugins pour Steam (thèmes, contrôle du TDP, réglages audio).")
                        iconText: "🔌"
                        checked: engine.deckyLoader
                        onToggled: engine.setDeckyLoader(!engine.deckyLoader)
                    }

                    CheckCard {
                        Layout.columnSpan: 2
                        title: "Support Volants & Simracing"
                        subtitle: qsTr("Pilotes noyau pour volants Logitech, Thrustmaster, Fanatec et logiciel de calibration Oversteer.")
                        iconText: "🏎️"
                        checked: engine.steeringWheels
                        onToggled: engine.setSteeringWheels(!engine.steeringWheels)
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
