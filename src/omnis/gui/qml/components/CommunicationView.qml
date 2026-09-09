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

    component DiscordCard: Rectangle {
        id: card
        property string title: ""
        property string badge: ""
        property string subtitle: ""
        property string iconText: ""
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 28
        radius: 14
        color: selected
               ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.2)
               : root.surfaceColor
        border.color: selected ? root.primaryColor : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.6)
        border.width: selected ? 2 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }

        RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: card.selected
                       ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.3)
                       : Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.6)

                Text {
                    anchors.centerIn: parent
                    text: card.iconText
                    font.pixelSize: 24
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                RowLayout {
                    spacing: 8
                    Text {
                        text: card.title
                        font.pixelSize: 16
                        font.bold: true
                        color: root.textColor
                    }

                    Rectangle {
                        visible: card.badge.length > 0
                        radius: 6
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                        border.color: root.accentColor
                        border.width: 1
                        implicitWidth: badgeText.implicitWidth + 12
                        implicitHeight: badgeText.implicitHeight + 4

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: card.badge
                            font.pixelSize: 11
                            font.bold: true
                            color: root.accentColor
                        }
                    }
                }

                Text {
                    text: card.subtitle
                    font.pixelSize: 13
                    color: root.textMutedColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: card.selected ? root.primaryColor : "transparent"
                border.color: card.selected ? root.primaryColor : root.textMutedColor
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: root.backgroundColor
                    visible: card.selected
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
                        text: qsTr("Communication & Messagerie")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Choisissez le client Discord que vous souhaitez intégrer à votre système")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 700
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    DiscordCard {
                        title: "Discord Officiel"
                        badge: "Natif NixOS"
                        subtitle: qsTr("Le client officiel Discord packagé au niveau système Nix. Stabilité éprouvée et intégration directe.")
                        iconText: "💬"
                        selected: engine.discordClient === "discord"
                        onClicked: engine.setDiscordClient("discord")
                    }

                    DiscordCard {
                        title: "Equibop"
                        badge: "Flatpak Flathub"
                        subtitle: qsTr("Client Discord alternatif léger, modulaire et hautement personnalisable avec support de thèmes et plugins.")
                        iconText: "⚡"
                        selected: engine.discordClient === "equibop"
                        onClicked: engine.setDiscordClient("equibop")
                    }

                    DiscordCard {
                        title: "Vesktop"
                        badge: "Flatpak Flathub"
                        subtitle: qsTr("Client Discord complet propulsé par Vencord. Idéal pour Wayland avec partage d'écran audio et plugins intégrés.")
                        iconText: "🎧"
                        selected: engine.discordClient === "vesktop"
                        onClicked: engine.setDiscordClient("vesktop")
                    }

                    DiscordCard {
                        title: qsTr("Aucun client Discord")
                        badge: qsTr("Optionnel")
                        subtitle: qsTr("Ne pas installer Discord. Vous pourrez toujours l'installer ultérieurement selon vos besoins.")
                        iconText: "🚫"
                        selected: engine.discordClient === "none"
                        onClicked: engine.setDiscordClient("none")
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
