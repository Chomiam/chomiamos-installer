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

    component ChoiceCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string iconText: ""
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: cardRow.implicitHeight + 24
        radius: 12
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
            anchors.margins: 14
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                radius: 10
                color: card.selected
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
                radius: 11
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
                        text: qsTr("Bureau & Navigateur Web")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Personnalisez votre interface graphique et sélectionnez le navigateur par défaut")
                        font.pixelSize: 14
                        color: textMutedColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        Text {
                            text: qsTr("Environnement de Bureau")
                            font.pixelSize: 18
                            font.bold: true
                            color: textColor
                        }

                        ChoiceCard {
                            title: "GNOME (Défaut)"
                            subtitle: qsTr("Interface soignée, stable et productive avec Dash to Dock, Vitals et Blur My Shell.")
                            iconText: "🖥️"
                            selected: engine.desktopEnvironment === "gnome"
                            onClicked: engine.setDesktopEnvironment("gnome")
                        }

                        ChoiceCard {
                            title: "COSMIC (Expérimental)"
                            subtitle: qsTr("Le nouvel environnement ultra-rapide écrit en Rust par System76, conçu pour le multitâche et le jeu.")
                            iconText: "🚀"
                            selected: engine.desktopEnvironment === "cosmic"
                            onClicked: engine.setDesktopEnvironment("cosmic")
                        }

                        ChoiceCard {
                            title: "Cinnamon"
                            subtitle: qsTr("Interface traditionnelle, fluide et personnalisable avec barre des tâches classique.")
                            iconText: "🌿"
                            selected: engine.desktopEnvironment === "cinnamon"
                            onClicked: engine.setDesktopEnvironment("cinnamon")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        Text {
                            text: qsTr("Navigateur Web par Défaut")
                            font.pixelSize: 18
                            font.bold: true
                            color: textColor
                        }

                        ChoiceCard {
                            title: "Google Chrome"
                            subtitle: qsTr("Navigateur rapide et compatible avec toutes les applications Google et extensions.")
                            iconText: "🌐"
                            selected: engine.browser === "chrome"
                            onClicked: engine.setBrowser("chrome")
                        }

                        ChoiceCard {
                            title: "Mozilla Firefox"
                            subtitle: qsTr("Navigateur libre, respectueux de la vie privée et personnalisable.")
                            iconText: "🦊"
                            selected: engine.browser === "firefox"
                            onClicked: engine.setBrowser("firefox")
                        }

                        ChoiceCard {
                            title: "Brave Browser"
                            subtitle: qsTr("Navigateur rapide axé sur la confidentialité avec bloqueur de publicités et de traqueurs intégré.")
                            iconText: "🦁"
                            selected: engine.browser === "brave"
                            onClicked: engine.setBrowser("brave")
                        }

                        ChoiceCard {
                            title: "Zen Browser (Flatpak)"
                            subtitle: qsTr("Navigateur basé sur Firefox avec onglets verticaux modernes et design soigné.")
                            iconText: "🧘"
                            selected: engine.browser === "zen"
                            onClicked: engine.setBrowser("zen")
                        }

                        ChoiceCard {
                            title: "LibreWolf"
                            subtitle: qsTr("Fork de Firefox durci pour une sécurité maximale et blocage natif de télémétrie.")
                            iconText: "🐺"
                            selected: engine.browser === "librewolf"
                            onClicked: engine.setBrowser("librewolf")
                        }

                        ChoiceCard {
                            title: "Opera (Flatpak)"
                            subtitle: qsTr("Navigateur avec fonctionnalités multimédia intégrées et VPN gratuit.")
                            iconText: "⭕"
                            selected: engine.browser === "opera"
                            onClicked: engine.setBrowser("opera")
                        }

                        ChoiceCard {
                            title: "Opera GX (Flatpak)"
                            subtitle: qsTr("Navigateur orienté gaming avec limiteurs de RAM, CPU et intégration Twitch/Discord.")
                            iconText: "🎮"
                            selected: engine.browser === "opera-gx"
                            onClicked: engine.setBrowser("opera-gx")
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
