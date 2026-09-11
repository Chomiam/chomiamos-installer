/*
 * Omnis Installer - UpdateDialog
 *
 * Dialogue moderne Catppuccin pour la mise à jour automatique en ligne.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: updateDialog

    property string newVersion: ""
    property string releaseNotes: ""
    property string downloadUrl: ""
    property bool isUpdating: false
    property int progressPercent: 0
    property string statusMessage: qsTr("Téléchargement de la mise à jour...")
    property string errorMessage: ""

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width * 0.8 : 650, 650)
    modal: true
    focus: true
    closePolicy: isUpdating ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    background: Rectangle {
        color: surfaceColor
        radius: 14
        border.color: errorMessage ? errorColor : accentColor
        border.width: 1.5

        // Ombre douce
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            radius: 18
            color: Qt.rgba(0, 0, 0, 0.4)
        }
    }

    header: Rectangle {
        color: "transparent"
        implicitHeight: headerRow.implicitHeight + 28

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: errorMessage ? "⚠️" : (isUpdating ? "⚡" : "🚀")
                font.pixelSize: 24
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: errorMessage
                          ? qsTr("Échec de la mise à jour")
                          : (isUpdating ? qsTr("Mise à jour de ChomiamOS Installer") : qsTr("Mise à jour disponible !"))
                    font.pixelSize: 18
                    font.bold: true
                    color: textColor
                }

                Text {
                    text: errorMessage
                          ? qsTr("Une erreur est survenue lors de l'opération.")
                          : (isUpdating
                             ? qsTr("Veuillez patienter pendant l'installation des nouveaux composants.")
                             : qsTr("Une nouvelle version de l'assistant d'installation est disponible en ligne."))
                    font.pixelSize: 12
                    color: textMutedColor
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 16

        // 1. Écran de proposition de mise à jour
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: !isUpdating && !errorMessage

            // Badges de versions
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    radius: 8
                    color: backgroundColor
                    border.color: textMutedColor
                    border.width: 1
                    implicitHeight: 34
                    implicitWidth: curVerText.implicitWidth + 24

                    Text {
                        id: curVerText
                        anchors.centerIn: parent
                        text: qsTr("Version actuelle : ") + engine.appVersion
                        color: textMutedColor
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "➜"
                    color: accentColor
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    radius: 8
                    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                    border.color: accentColor
                    border.width: 1
                    implicitHeight: 34
                    implicitWidth: newVerText.implicitWidth + 24

                    Text {
                        id: newVerText
                        anchors.centerIn: parent
                        text: qsTr("Nouvelle version : ") + newVersion
                        color: accentColor
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Notes de version
            Text {
                text: qsTr("Notes de mise à jour :")
                font.pixelSize: 13
                font.bold: true
                color: textColor
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                clip: true

                TextArea {
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextArea.Wrap
                    font.family: branding.fontMonospace || "monospace"
                    font.pixelSize: 12
                    color: textColor
                    text: releaseNotes ? releaseNotes : qsTr("Aucune note détaillée disponible pour cette version.")

                    background: Rectangle {
                        color: backgroundColor
                        radius: 8
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                    }
                }
            }
        }

        // 2. Écran de progression
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16
            visible: isUpdating && !errorMessage

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: statusMessage
                    color: textColor
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Text {
                    text: progressPercent + " %"
                    color: accentColor
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            // Barre de progression Catppuccin
            ProgressBar {
                id: pBar
                Layout.fillWidth: true
                from: 0
                to: 100
                value: progressPercent

                background: Rectangle {
                    implicitHeight: 12
                    color: backgroundColor
                    radius: 6
                }

                contentItem: Item {
                    implicitHeight: 12

                    Rectangle {
                        width: pBar.visualPosition * parent.width
                        height: parent.height
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.lighter(accentColor, 1.1) }
                            GradientStop { position: 1.0; color: accentColor }
                        }

                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("⚡ L'installateur redémarrera automatiquement dès que les composants seront prêts.")
                color: textMutedColor
                font.pixelSize: 12
                font.italic: true
            }
        }

        // 3. Écran d'erreur
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !!errorMessage

            Text {
                Layout.fillWidth: true
                text: errorMessage
                color: errorColor
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }

    footer: Item {
        implicitHeight: footerRow.implicitHeight + 24

        RowLayout {
            id: footerRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item { Layout.fillWidth: true }

            // Mode 1 : Boutons Ignorer / Mettre à jour
            Button {
                text: qsTr("Plus tard")
                visible: !isUpdating && !errorMessage
                height: 38
                implicitWidth: 100

                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? Qt.darker(backgroundColor, 1.2) : backgroundColor
                    border.color: textMutedColor
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: updateDialog.close()
            }

            Button {
                text: qsTr("Mettre à jour maintenant")
                visible: !isUpdating && !errorMessage
                height: 38
                implicitWidth: 200

                background: Rectangle {
                    radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(accentColor, 1.1) }
                        GradientStop { position: 1.0; color: accentColor }
                    }
                    border.color: Qt.lighter(accentColor, 1.2)
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    font.bold: true
                    color: "#11111b"  // Catppuccin Crust pour contraste optimal sur Mauve
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    isUpdating = true
                    progressPercent = 0
                    statusMessage = qsTr("Préparation du téléchargement...")
                    engine.startUpdate(downloadUrl)
                }
            }

            // Mode 3 : Bouton Fermer après erreur
            Button {
                text: qsTr("Fermer")
                visible: !!errorMessage
                height: 38
                implicitWidth: 100

                background: Rectangle {
                    radius: 8
                    color: backgroundColor
                    border.color: textMutedColor
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    errorMessage = ""
                    isUpdating = false
                    updateDialog.close()
                }
            }
        }
    }
}
