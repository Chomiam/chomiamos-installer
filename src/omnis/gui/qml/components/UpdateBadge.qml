/*
 * UpdateBadge - Pastille réactive indiquant le statut de mise à jour de l'installateur
 *
 * États visuels :
 * - 🟢 Vert : Installateur à jour (vX.X.X • À jour)
 * - 🔵 Bleu : Vérification en cours sur GitHub (animation pulsante)
 * - 🟠 Orange : Mise à jour disponible (cliquable pour ouvrir la modal)
 * - ⚪ Gris : Mode hors-ligne / pas d'accès internet
 * - 🔴 Rouge : Erreur lors de la vérification
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // Propriétés héritées / branding
    property color successColor: "#10B981"   // Catppuccin Green / Emerald
    property color accentColor: "#89B4FA"    // Catppuccin Blue
    property color warningColor: "#FAB387"   // Catppuccin Peach
    property color errorColor: "#F38BA8"     // Catppuccin Red
    property color textMutedColor: "#A6ADC8" // Catppuccin Subtext0
    property color textColor: "#CDD6F4"      // Catppuccin Text

    // Statut réactif provenant du bridge Python
    readonly property string status: engine.updateStatus || "idle"
    readonly property bool isChecking: engine.isCheckingUpdate
    readonly property string currentVer: engine.appVersion || "0.6.2"
    readonly property string targetVer: engine.latestVersion || currentVer

    // Dimensions
    implicitHeight: 28
    implicitWidth: badgeLayout.implicitWidth + 20
    radius: height / 2

    // Couleur de fond selon le statut
    color: {
        if (mouseArea.containsMouse) {
            if (status === "available") return Qt.rgba(warningColor.r, warningColor.g, warningColor.b, 0.28)
            if (status === "checking")  return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
            if (status === "offline")   return Qt.rgba(textMutedColor.r, textMutedColor.g, textMutedColor.b, 0.18)
            if (status === "error")     return Qt.rgba(errorColor.r, errorColor.g, errorColor.b, 0.22)
            return Qt.rgba(successColor.r, successColor.g, successColor.b, 0.25)
        }
        if (status === "available") return Qt.rgba(warningColor.r, warningColor.g, warningColor.b, 0.18)
        if (status === "checking")  return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.14)
        if (status === "offline")   return Qt.rgba(textMutedColor.r, textMutedColor.g, textMutedColor.b, 0.10)
        if (status === "error")     return Qt.rgba(errorColor.r, errorColor.g, errorColor.b, 0.14)
        return Qt.rgba(successColor.r, successColor.g, successColor.b, 0.15)
    }

    // Bordure
    border.width: 1
    border.color: {
        if (status === "available") return Qt.rgba(warningColor.r, warningColor.g, warningColor.b, mouseArea.containsMouse ? 0.75 : 0.50)
        if (status === "checking")  return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, mouseArea.containsMouse ? 0.65 : 0.40)
        if (status === "offline")   return Qt.rgba(textMutedColor.r, textMutedColor.g, textMutedColor.b, mouseArea.containsMouse ? 0.45 : 0.25)
        if (status === "error")     return Qt.rgba(errorColor.r, errorColor.g, errorColor.b, mouseArea.containsMouse ? 0.65 : 0.40)
        return Qt.rgba(successColor.r, successColor.g, successColor.b, mouseArea.containsMouse ? 0.70 : 0.40)
    }

    // Animation fluide sur les changements de couleur
    Behavior on color {
        ColorAnimation { duration: 200 }
    }
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    // Animation d'appui
    scale: mouseArea.pressed ? 0.96 : (mouseArea.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    RowLayout {
        id: badgeLayout
        anchors.centerIn: parent
        spacing: 7

        // Pastille lumineuse (Point coloré)
        Item {
            width: 10
            height: 10
            Layout.alignment: Qt.AlignVCenter

            // Halo lumineux pulsant pour l'état checking ou available
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: root.status === "available" ? root.warningColor :
                       (root.status === "checking" ? root.accentColor : root.successColor)
                opacity: 0.3
                visible: root.status === "checking" || root.status === "available"

                SequentialAnimation on scale {
                    running: root.status === "checking" || root.status === "available"
                    loops: Animation.Infinite
                    PropertyAnimation { from: 0.8; to: 1.4; duration: 900; easing.type: Easing.InOutSine }
                    PropertyAnimation { from: 1.4; to: 0.8; duration: 900; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on opacity {
                    running: root.status === "checking" || root.status === "available"
                    loops: Animation.Infinite
                    PropertyAnimation { from: 0.4; to: 0.1; duration: 900; easing.type: Easing.InOutSine }
                    PropertyAnimation { from: 0.1; to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Cercle central
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: {
                    if (root.status === "available") return root.warningColor
                    if (root.status === "checking")  return root.accentColor
                    if (root.status === "offline")   return root.textMutedColor
                    if (root.status === "error")     return root.errorColor
                    return root.successColor
                }

                Behavior on color {
                    ColorAnimation { duration: 250 }
                }
            }
        }

        // Texte d'état
        Text {
            id: labelText
            Layout.alignment: Qt.AlignVCenter
            text: {
                if (root.status === "checking")  return qsTr("Vérification…")
                if (root.status === "available") return qsTr("Mise à jour v%1").arg(root.targetVer)
                if (root.status === "offline")   return qsTr("v%1 • Hors-ligne").arg(root.currentVer)
                if (root.status === "error")     return qsTr("Vérification échouée")
                return qsTr("v%1 • À jour").arg(root.currentVer)
            }
            font.pixelSize: 11
            font.bold: true
            color: {
                if (root.status === "available") return root.warningColor
                if (root.status === "checking")  return root.accentColor
                if (root.status === "offline")   return root.textMutedColor
                if (root.status === "error")     return root.errorColor
                return root.successColor
            }

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }

        // Petite icône d'action (Refresh ou Flèche de mise à jour)
        Text {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: 11
            font.bold: true
            color: labelText.color
            opacity: mouseArea.containsMouse || root.status === "available" || root.status === "checking" ? 0.9 : 0.0

            text: {
                if (root.status === "available") return "↑"
                if (root.status === "checking")  return "⟳"
                return "⟳"
            }

            // Rotation douce pendant la vérification
            RotationAnimation on rotation {
                running: root.status === "checking"
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }

    // Interaction souris
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.status === "available") {
                // Ouvre le dialogue de mise à jour si disponible
                if (typeof appUpdateDialog !== "undefined" && appUpdateDialog) {
                    appUpdateDialog.open()
                }
            } else {
                // Relance la vérification en direct
                engine.checkForUpdates()
            }
        }
    }

    // Infobulle d'aide détaillée
    ToolTip {
        id: badgeToolTip
        visible: mouseArea.containsMouse
        delay: 400
        timeout: 6000

        contentItem: Text {
            text: {
                if (root.status === "checking") {
                    return qsTr("Vérification des mises à jour sur GitHub en cours…")
                }
                if (root.status === "available") {
                    return qsTr("Une nouvelle version (v%1) est disponible !\nCliquez pour ouvrir le gestionnaire de mise à jour.").arg(root.targetVer)
                }
                if (root.status === "offline") {
                    return qsTr("Connexion internet inaccessible.\nCliquez pour revérifier la connexion.")
                }
                if (root.status === "error") {
                    return qsTr("Impossible de vérifier les mises à jour.\nCliquez pour réessayer.")
                }
                return qsTr("L'installateur est sur la dernière version officielle (v%1).\nCliquez pour vérifier à nouveau.").arg(root.currentVer)
            }
            color: root.textColor
            font.pixelSize: 12
        }

        background: Rectangle {
            color: "#181825"  // Catppuccin Mantle
            radius: 8
            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15)
            border.width: 1
        }
    }
}
