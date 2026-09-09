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
        property string badge: ""
        property string subtitle: ""
        property string iconText: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 24
        radius: 14
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
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: card.checked
                       ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.3)
                       : Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.6)

                Text {
                    anchors.centerIn: parent
                    text: card.iconText
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                RowLayout {
                    spacing: 8
                    Text {
                        text: card.title
                        font.pixelSize: 15
                        font.bold: true
                        color: root.textColor
                    }

                    Rectangle {
                        visible: card.badge.length > 0
                        radius: 6
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                        border.color: root.accentColor
                        border.width: 1
                        implicitWidth: badgeText.implicitWidth + 10
                        implicitHeight: badgeText.implicitHeight + 4

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: card.badge
                            font.pixelSize: 10
                            font.bold: true
                            color: root.accentColor
                        }
                    }
                }

                Text {
                    text: card.subtitle
                    font.pixelSize: 12
                    color: root.textMutedColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

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

                // Header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: qsTr("Multimédia & Réseau")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Sélectionnez vos applications multimédia et vos outils de partage réseau")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Two columns: Multimedia (left) and Network (right)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 24

                    // Left Column: Multimedia
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        Text {
                            text: qsTr("Multimédia & Streaming")
                            font.pixelSize: 18
                            font.bold: true
                            color: textColor
                        }

                        CheckCard {
                            title: "Stremio"
                            badge: "Streaming & VOD"
                            iconText: "📺"
                            subtitle: qsTr("Plateforme moderne de streaming vidéo pour films, séries et vidéos avec support d'extensions communautaires.")
                            checked: engine.stremio
                            onToggled: engine.setStremio(!engine.stremio)
                        }

                        CheckCard {
                            title: "VLC Media Player"
                            badge: "Lecteur Universel"
                            iconText: "🎬"
                            subtitle: qsTr("Le lecteur multimédia polyvalent de référence, capable de lire tous les codecs audio et vidéo sans configuration.")
                            checked: engine.vlc
                            onToggled: engine.setVlc(!engine.vlc)
                        }

                        CheckCard {
                            title: "MPV"
                            badge: "Ultra-rapide"
                            iconText: "⚡"
                            subtitle: qsTr("Lecteur vidéo épuré et ultra-performant avec décodage matériel GPU et rendu vidéo optimal.")
                            checked: engine.mpv
                            onToggled: engine.setMpv(!engine.mpv)
                        }
                    }

                    // Right Column: Network
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        Text {
                            text: qsTr("Réseau, Partage & Téléchargement")
                            font.pixelSize: 18
                            font.bold: true
                            color: textColor
                        }

                        CheckCard {
                            title: "LocalSend"
                            badge: "AirDrop Libre"
                            iconText: "📡"
                            subtitle: qsTr("Partagez instantanément des fichiers avec vos appareils (PC, Mac, Android, iOS) sur le même réseau Wi-Fi sans passer par Internet.")
                            checked: engine.localsend
                            onToggled: engine.setLocalsend(!engine.localsend)
                        }

                        CheckCard {
                            title: "Tailscale"
                            badge: "VPN WireGuard Maillé"
                            iconText: "🔒"
                            subtitle: qsTr("Connectez tous vos appareils dans un réseau privé sécurisé chiffré. Accédez à vos partages à distance sans ouvrir de port.")
                            checked: engine.tailscale
                            onToggled: engine.setTailscale(!engine.tailscale)
                        }

                        CheckCard {
                            title: "Motrix"
                            badge: "Accélérateur & Torrent"
                            iconText: "📥"
                            subtitle: qsTr("Gestionnaire de téléchargements moderne tout-en-un compatible HTTP, FTP, BitTorrent et Magnet avec accélération multi-sources.")
                            checked: engine.motrix
                            onToggled: engine.setMotrix(!engine.motrix)
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
