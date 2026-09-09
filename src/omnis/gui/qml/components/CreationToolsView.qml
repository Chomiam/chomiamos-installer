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

    component RadioCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string iconText: ""
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 20
        radius: 12
        color: selected
               ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.18)
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
            anchors.margins: 12
            spacing: 12

            Text {
                text: card.iconText
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: card.title
                    font.pixelSize: 14
                    font.bold: true
                    color: root.textColor
                }

                Text {
                    text: card.subtitle
                    font.pixelSize: 11
                    color: root.textMutedColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                radius: 10
                color: card.selected ? root.primaryColor : "transparent"
                border.color: card.selected ? root.primaryColor : root.textMutedColor
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
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
                        text: qsTr("Création & Outils Avancés")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Sélectionnez les logiciels de montage, modélisation 3D, virtualisation et IA")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // DaVinci Resolve Section
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Text {
                        text: qsTr("Montage Vidéo : DaVinci Resolve")
                        font.pixelSize: 16
                        font.bold: true
                        color: textColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RadioCard {
                            title: qsTr("Aucun")
                            subtitle: qsTr("Ne pas installer")
                            iconText: "🚫"
                            selected: engine.davinciResolve === "none"
                            onClicked: engine.setDavinciResolve("none")
                        }

                        RadioCard {
                            title: "DaVinci Resolve"
                            subtitle: qsTr("Version Gratuite")
                            iconText: "🎬"
                            selected: engine.davinciResolve === "free"
                            onClicked: engine.setDavinciResolve("free")
                        }

                        RadioCard {
                            title: "DaVinci Studio"
                            subtitle: qsTr("Version Payante")
                            iconText: "⭐"
                            selected: engine.davinciResolve === "studio"
                            onClicked: engine.setDavinciResolve("studio")
                        }
                    }
                }

                // General Creation and Advanced Tools
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 850
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Text {
                        text: qsTr("Logiciels de Création & Services Système")
                        font.pixelSize: 16
                        font.bold: true
                        color: textColor
                    }

                    CheckCard {
                        title: "Blender 3D"
                        subtitle: qsTr("Suite complète de modélisation 3D, sculpture, animation et rendu cycles accéléré par GPU.")
                        iconText: "🎨"
                        checked: engine.blender
                        onToggled: engine.setBlender(!engine.blender)
                    }

                    CheckCard {
                        title: "Godot Engine"
                        subtitle: qsTr("Moteur de jeu vidéo 2D et 3D open-source léger, idéal pour la création indépendante.")
                        iconText: "🤖"
                        checked: engine.godot
                        onToggled: engine.setGodot(!engine.godot)
                    }

                    CheckCard {
                        title: "Virtualisation (KVM / QEMU / Virt-Manager)"
                        subtitle: qsTr("Hyperviseur matériel pour exécuter des machines virtuelles Linux et Windows à pleine vitesse.")
                        iconText: "📦"
                        checked: engine.virtualisation
                        onToggled: engine.setVirtualisation(!engine.virtualisation)
                    }

                    CheckCard {
                        title: "Suite IA Locale (Ollama + Open-WebUI + SearXNG)"
                        subtitle: qsTr("Exécutez des modèles de langage locaux en VRAM sur votre GPU sans envoyer vos données dans le cloud.")
                        iconText: "🧠"
                        checked: engine.aiSuite
                        onToggled: engine.setAiSuite(!engine.aiSuite)
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
