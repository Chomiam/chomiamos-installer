/*
 * SummaryView - Installation Summary and Confirmation for ChomiamOS
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // Signals
    signal editLocale()
    signal editUsers()
    signal editDesktop()
    signal editCommunication()
    signal editGaming()
    signal editEmulation()
    signal editMediaNetwork()
    signal editCreation()
    signal editPartition()

    signal confirmedToggled(bool confirmed)
    property bool confirmed: false

    // Localisation & Utilisateur
    property string localeValue: "fr_FR.UTF-8"
    property string timezoneValue: "Europe/Paris"
    property string keymapValue: "fr"
    property string usernameValue: ""
    property string fullNameValue: ""
    property string hostnameValue: ""
    property bool autoLoginValue: false
    property bool isAdminValue: true

    // Bureau & Navigateur
    property string desktopEnvironmentValue: "gnome"
    property string browserValue: "chrome"

    // Communication
    property string discordClientValue: "discord"

    // Gaming
    property bool gamingEnableValue: true
    property bool steamValue: true
    property bool lutrisValue: true
    property bool heroicValue: true
    property bool faugusValue: true
    property bool deckyLoaderValue: true
    property bool geforceNowValue: true
    property bool steeringWheelsValue: true

    // Émulation & Rétrogaming
    property bool emulationEnableValue: true
    property string emulationFrontendValue: "es-de"
    property bool retroarchEnableValue: true
    property bool edenValue: true
    property bool dolphinValue: true
    property bool pcsx2Value: true
    property bool ppssppValue: true
    property bool melondsValue: true
    property bool azaharValue: true
    property bool mgbaValue: true
    property bool rpcs3Value: false

    // Multimédia & Réseau
    property bool stremioValue: true
    property bool vlcValue: true
    property bool mpvValue: true
    property bool localsendValue: true
    property bool tailscaleValue: true
    property bool motrixValue: true

    // Utilisateur
    property string userShellValue: "fish"

    // Création & Outils
    property string davinciResolveValue: "none"
    property bool blenderValue: true
    property bool godotValue: true
    property bool virtualisationValue: true
    property bool aiSuiteValue: false
    property bool antigravityValue: true
    property bool pearDesktopValue: true
    property bool kdenliveValue: true

    // Stockage
    property string diskValue: ""
    property string diskSizeValue: ""
    property string partitionModeValue: "auto"

    // Distro info
    property string distroName: "ChomiamOS"
    property string distroVersion: "26.05"
    property string distroLogo: ""

    // Theme colors
    property color primaryColor: "#cba6f7"
    property color secondaryColor: "#b4befe"
    property color accentColor: "#89b4fa"
    property color backgroundColor: "#1e1e2e"
    property color surfaceColor: "#313244"
    property color textColor: "#cdd6f4"
    property color textMutedColor: "#a6adc8"
    property color successColor: "#a6e3a1"
    property color warningColor: "#f9e2af"
    property color errorColor: "#f38ba8"

    function formatDiscordLabel(client) {
        if (client === "discord") return "Discord Officiel (Natif NixOS)"
        if (client === "equibop") return "Equibop (Flatpak)"
        if (client === "vesktop") return "Vesktop (Flatpak)"
        return "Aucun"
    }

    function formatBrowserLabel(b) {
        if (b === "chrome") return "Google Chrome"
        if (b === "firefox") return "Mozilla Firefox"
        if (b === "zen") return "Zen Browser (Flatpak)"
        if (b === "librewolf") return "LibreWolf"
        if (b === "opera") return "Opera (Flatpak)"
        if (b === "opera-gx") return "Opera GX (Flatpak)"
        return b
    }

    function formatDavinciLabel(d) {
        if (d === "free") return "DaVinci Resolve (Gratuit)"
        if (d === "studio") return "DaVinci Resolve Studio (Payant)"
        return "Désactivé"
    }

    function formatGamingLaunchers() {
        var list = []
        if (steamValue) list.push("Steam")
        if (lutrisValue) list.push("Lutris")
        if (heroicValue) list.push("Heroic")
        if (faugusValue) list.push("Faugus")
        if (geforceNowValue) list.push("GeForce NOW")
        if (deckyLoaderValue) list.push("Decky Loader")
        if (steeringWheelsValue) list.push("Simracing")
        if (list.length === 0) return "Aucun lanceur sélectionné"
        return list.join(", ")
    }

    function formatEmulators() {
        var list = []
        if (emulationFrontendValue === "es-de") list.push("ES-DE Frontend")
        if (retroarchEnableValue) list.push("RetroArch (2D/PS1)")
        if (edenValue) list.push("Eden (Switch)")
        if (dolphinValue) list.push("Dolphin (GC/Wii)")
        if (pcsx2Value) list.push("PCSX2 (PS2)")
        if (ppssppValue) list.push("PPSSPP (PSP)")
        if (melondsValue) list.push("melonDS (DS)")
        if (azaharValue) list.push("Azahar (3DS)")
        if (mgbaValue) list.push("mGBA (GB/GBA)")
        if (rpcs3Value) list.push("RPCS3 (PS3)")
        return list.length > 0 ? list.join(", ") : "Aucun"
    }

    function formatMediaList() {
        var list = []
        if (stremioValue) list.push("Stremio")
        if (vlcValue) list.push("VLC")
        if (mpvValue) list.push("MPV")
        if (list.length === 0) return "Aucun lecteur"
        return list.join(", ")
    }

    function formatNetworkList() {
        var list = []
        if (localsendValue) list.push("LocalSend")
        if (tailscaleValue) list.push("Tailscale VPN")
        if (motrixValue) list.push("Motrix")
        if (list.length === 0) return "Aucun outil réseau"
        return list.join(", ")
    }

    function formatCreationTools() {
        var list = []
        if (davinciResolveValue !== "none") list.push(formatDavinciLabel(davinciResolveValue))
        if (blenderValue) list.push("Blender 3D")
        if (godotValue) list.push("Godot Engine")
        if (virtualisationValue) list.push("Virtualisation KVM")
        if (aiSuiteValue) list.push("Suite IA Locale")
        if (antigravityValue) list.push("Antigravity IDE")
        if (pearDesktopValue) list.push("Pear Desktop")
        if (kdenliveValue) list.push("Kdenlive")
        if (list.length === 0) return "Aucun outil sélectionné"
        return list.join(", ")
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        ScrollView {
            id: scrollView
            anchors.fill: parent
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
                spacing: 16

                // Header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: qsTr("Résumé de l'''Installation")
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: qsTr("Veuillez vérifier l'''ensemble des paramètres sélectionnés avant de lancer l'''installation")
                        font.pixelSize: 14
                        color: textMutedColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Cards Container
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 800
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Card 1: Bureau & Web
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: deskCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "🖥️"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: deskCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Bureau & Navigateur Web")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Environnement : %1 | Navigateur : %2")
                                          .arg(desktopEnvironmentValue === "cosmic" ? "COSMIC (Expérimental)" : "GNOME (Défaut)")
                                          .arg(formatBrowserLabel(browserValue))
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editDesktop()
                            }
                        }
                    }

                    // Card 2: Communication
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: commCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "💬"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: commCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Communication & Messagerie")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Client Discord : %1").arg(formatDiscordLabel(discordClientValue))
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editCommunication()
                            }
                        }
                    }

                    // Card 3: Jeux Vidéo
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: gameCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "🎮"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: gameCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Jeux Vidéo & Lanceurs")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Suite Gaming : %1").arg(gamingEnableValue ? "Activée (GameMode, GameScope, Sunshine)" : "Désactivée")
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }

                                Text {
                                    text: qsTr("Composants : %1").arg(formatGamingLaunchers())
                                    font.pixelSize: 12
                                    color: accentColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editGaming()
                            }
                        }
                    }

                    // Card: Émulation & Rétrogaming
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: emulationSummaryContent.implicitHeight + 32
                        color: surfaceColor
                        radius: 12
                        border.color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08)

                        RowLayout {
                            id: emulationSummaryContent
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            Text {
                                text: "🕹️"
                                font.pixelSize: 28
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Émulation & Rétrogaming")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Suite d'Émulation : %1").arg(emulationEnableValue ? "Activée (~/Jeux/ROMs, ~/Jeux/BIOS)" : "Désactivée")
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }

                                Text {
                                    text: qsTr("Composants : %1").arg(formatEmulators())
                                    font.pixelSize: 12
                                    color: accentColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editEmulation()
                            }
                        }
                    }

                    // Card 4: Multimédia & Réseau
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: medNetCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "📺"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: medNetCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Multimédia & Réseau")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Multimédia : %1").arg(formatMediaList())
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }

                                Text {
                                    text: qsTr("Réseau & Partage : %1").arg(formatNetworkList())
                                    font.pixelSize: 12
                                    color: accentColor
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editMediaNetwork()
                            }
                        }
                    }

                    // Card 5: Création & Outils
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: creatCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "🎨"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: creatCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Création & Outils Avancés")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Outils sélectionnés : %1").arg(formatCreationTools())
                                    font.pixelSize: 12
                                    color: textMutedColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editCreation()
                            }
                        }
                    }

                    // Card 6: Utilisateur & Machine
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: userCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "👤"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: userCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Utilisateur & Système")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Compte : %1 (%2) | Machine : %3 | Shell : %4")
                                          .arg(usernameValue || "chomiam")
                                          .arg(fullNameValue || "ChomiamOS User")
                                          .arg(hostnameValue || "chomiamos")
                                          .arg((userShellValue || "fish").toUpperCase())
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }

                                Text {
                                    text: qsTr("Langue : %1 | Clavier : %2 | Fuseau : %3")
                                          .arg(localeValue)
                                          .arg(keymapValue)
                                          .arg(timezoneValue)
                                    font.pixelSize: 12
                                    color: textMutedColor
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editUsers()
                            }
                        }
                    }

                    // Card 7: Disque & Partitionnement
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: diskCol.implicitHeight + 28
                        radius: 12
                        color: surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Text {
                                text: "💾"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                id: diskCol
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Stockage & Partitionnement")
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textColor
                                }

                                Text {
                                    text: qsTr("Disque cible : %1 %2 | Système de fichiers : Ext4")
                                          .arg(diskValue || "Non sélectionné")
                                          .arg(diskSizeValue ? "(" + diskSizeValue + ")" : "")
                                    font.pixelSize: 13
                                    color: textMutedColor
                                }
                            }

                            Button {
                                text: qsTr("Modifier")
                                onClicked: root.editPartition()
                            }
                        }
                    }
                }

                // Final confirmation warning
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 800
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: finalWarningColumn.implicitHeight + 28
                    radius: 12
                    color: Qt.rgba(warningColor.r, warningColor.g, warningColor.b, 0.15)
                    border.color: warningColor
                    border.width: 2

                    ColumnLayout {
                        id: finalWarningColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            spacing: 10
                            Text {
                                text: "⚠️"
                                font.pixelSize: 20
                            }
                            Text {
                                text: qsTr("Prêt à Installer ChomiamOS")
                                font.pixelSize: 16
                                font.bold: true
                                color: textColor
                            }
                        }

                        Text {
                            text: qsTr("Le partitionnement et le déploiement vont débuter. Les données sur le disque sélectionné seront définitivement remplacées.")
                            font.pixelSize: 13
                            color: textColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            id: confirmCheckBox
                            checked: root.confirmed
                            onToggled: root.confirmedToggled(checked)

                            contentItem: Text {
                                text: qsTr("Je confirme vouloir installer ChomiamOS sur le disque (%1) et effacer son contenu.")
                                      .arg(diskValue || qsTr("disque sélectionné"))
                                font.pixelSize: 13
                                font.bold: true
                                color: textColor
                                wrapMode: Text.WordWrap
                                leftPadding: confirmCheckBox.indicator.width + 8
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
