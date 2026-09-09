#!/usr/bin/env bash
# =============================================================================
# ❄️ CHOMIAMOS INSTALLER — Assistant Graphique d'Installation (Yad / Catppuccin)
# =============================================================================

set -e

# Forcer le thème sombre GTK3 / GNOME pour toutes les fenêtres Yad
export GTK_THEME="Adwaita:dark"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_FILE="$SCRIPT_DIR/theme/catppuccin-mocha.css"
LOGO_ICON="$SCRIPT_DIR/theme/logo-icon.png"

DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ] || [ "$arg" = "--simulation" ]; then
    DRY_RUN=true
  fi
done

# Vérification des droits root (sauf en mode simulation)
if [ "$DRY_RUN" = false ] && [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# =============================================================================
# 1. 🔍 AUTO-DÉTECTION DU MATÉRIEL (GPU & DISQUES)
# =============================================================================

DETECTED_GPU="amd"
if lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "nvidia"; then
  DETECTED_GPU="nvidia"
elif lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "intel"; then
  DETECTED_GPU="intel"
elif lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "amd\|ati"; then
  DETECTED_GPU="amd"
fi

if [ "$DETECTED_GPU" = "nvidia" ]; then
  GPU_CHOICES="^nvidia (NVIDIA Récentes : RTX 20xx, 30xx, 40xx, 50xx, GTX 16xx) [Détectée]!amd (AMD Radeon : RX 5000, 6000, 7000, 9000, Steam Deck)!intel (Intel Arc et processeurs avec puce graphique Intel)!nvidia-legacy (Anciennes cartes NVIDIA : séries GTX 10xx, 9xx, 7xx)"
elif [ "$DETECTED_GPU" = "intel" ]; then
  GPU_CHOICES="^intel (Intel Arc et processeurs avec puce graphique Intel) [Détectée]!amd (AMD Radeon : RX 5000, 6000, 7000, 9000, Steam Deck)!nvidia (NVIDIA Récentes : RTX 20xx, 30xx, 40xx, 50xx, GTX 16xx)!nvidia-legacy (Anciennes cartes NVIDIA : séries GTX 10xx, 9xx, 7xx)"
else
  GPU_CHOICES="^amd (AMD Radeon : RX 5000, 6000, 7000, 9000, Steam Deck) [Détectée]!nvidia (NVIDIA Récentes : RTX 20xx, 30xx, 40xx, 50xx, GTX 16xx)!intel (Intel Arc et processeurs avec puce graphique Intel)!nvidia-legacy (Anciennes cartes NVIDIA : séries GTX 10xx, 9xx, 7xx)"
fi

# Détection des disques
DISKS=()
if [ "$DRY_RUN" = true ]; then
  DISKS+=("/dev/nvme0n1 (1.0 TB - Samsung SSD 990 PRO NVMe [SIMULATION])")
  DISKS+=("/dev/sda (2.0 TB - Crucial CT2000MX500 SSD [SIMULATION])")
else
  INSTALLER_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed -E 's/[0-9]+$//' | sed -E 's/p[0-9]+$//' || true)
  while read -r name size model; do
    dev="$name"
    if [[ ! "$dev" =~ ^/dev/ ]]; then
      dev="/dev/$name"
    fi
    if [ -n "$INSTALLER_DEV" ] && [ "$dev" = "$INSTALLER_DEV" ]; then
      continue
    fi
    DISKS+=("$dev ($size - $model)")
  done < <(lsblk -dpno NAME,SIZE,MODEL | grep -v "loop\|zram\|sr[0-9]")
fi

if [ ${#DISKS[@]} -eq 0 ]; then
  yad --css="$CSS_FILE" --error \
      --title="Erreur de détection" \
      --width=450 \
      --center \
      --text="❌ Aucun disque de stockage détecté pour l'installation." \
      --button="Quitter:1"
  exit 1
fi

if [ ${#DISKS[@]} -gt 0 ]; then
  DISKS[0]="^${DISKS[0]}"
fi
DISKS_CHOICES=$(IFS="!"; echo "${DISKS[*]}")

# Helper pour conserver la liste complète des choix avec l'option choisie active
mark_selected() {
  local choices="$1"
  local selected="$2"
  local sel_key="${selected%% *}"
  sel_key="${sel_key#\^}"
  local clean="${choices//\^/}"
  local result=()
  local oldIFS="$IFS"
  IFS="!" read -ra items <<< "$clean"
  for item in "${items[@]}"; do
    local key="${item%% *}"
    if [ "$key" = "$sel_key" ]; then
      result+=("^$item")
    else
      result+=("$item")
    fi
  done
  IFS="!"
  echo "${result[*]}"
}

# =============================================================================
# 2. 🎛️ VALEURS INITIALES DU FORMULAIRE
# =============================================================================

SHELL_CHOICES="^fish (Moderne, avec autocomplétion intelligente)!zsh (Très personnalisable)!bash (Le shell Linux classique)"
DESKTOP_CHOICES="^Gnome!Cosmic!Les deux"
BROWSER_CHOICES="^chrome (Google Chrome)!firefox (Mozilla Firefox)!zen (Zen Browser - Moderne et orienté confidentialité)!librewolf (LibreWolf - Firefox durci axé sur la vie privée)!opera-gx (Opera GX - Navigateur orienté gaming)!opera (Opera Standard)"
DAVINCI_CHOICES="^none (Non installé)!free (DaVinci Resolve - Version Gratuite)!studio (DaVinci Resolve Studio - Version Payante)"

VAL_USERNAME="chomiam"
VAL_FULLNAME="Axel Valens"
VAL_PASSWORD=""
VAL_PASSWORD_CONFIRM=""
VAL_HOSTNAME="chomiamos"
VAL_SHELL="$SHELL_CHOICES"

VAL_GPU="$GPU_CHOICES"
VAL_STEERING="TRUE"

VAL_DESKTOP="$DESKTOP_CHOICES"

VAL_LAUNCHER_STEAM="TRUE"
VAL_LAUNCHER_LUTRIS="TRUE"
VAL_LAUNCHER_HEROIC="TRUE"
VAL_LAUNCHER_FAUGUS="TRUE"
VAL_BROWSER="$BROWSER_CHOICES"

VAL_GAMING_ENABLE="TRUE"
VAL_DECKY_ENABLE="TRUE"
VAL_GEFORCE_NOW="TRUE"

VAL_VIRT_ENABLE="TRUE"
VAL_SAMBA_ENABLE="TRUE"
VAL_BLENDER_ENABLE="TRUE"
VAL_GODOT_ENABLE="TRUE"
VAL_DAVINCI="$DAVINCI_CHOICES"
VAL_AI_SUITE="FALSE"

VAL_TARGET_DISK="$DISKS_CHOICES"

# =============================================================================
# 3. 🧙 ASSISTANT MULTI-PAGES EN 6 ÉTAPES (CATPPUCCIN MOCHA WIZARD)
# =============================================================================

STEP=1
TOTAL_STEPS=6

while true; do
  case $STEP in

    # -------------------------------------------------------------------------
    # ÉTAPE 1 : IDENTITÉ & COMPTE UTILISATEUR
    # -------------------------------------------------------------------------
    1)
      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 1/6" \
        --window-icon="$LOGO_ICON" \
        --width=750 --height=560 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>❄️ ChomiamOS</span> <span size='large' foreground='#a6adc8'>— Étape 1/$TOTAL_STEPS : Compte &amp; Système</span>\n<span foreground='#b4befe'>Créez votre compte utilisateur personnel et définissez l'identité de votre ordinateur.</span>\n" \
        --separator="|" \
        --field="👤 Nom de compte (en minuscules sans espace) :" "$VAL_USERNAME" \
        --field="📝 Votre Nom d'usage ou Prénom :" "$VAL_FULLNAME" \
        --field="🔑 Mot de passe de votre session :H" "$VAL_PASSWORD" \
        --field="🔒 Confirmer le mot de passe :H" "$VAL_PASSWORD_CONFIRM" \
        --field="🏷️ Nom de votre ordinateur sur le réseau (Hostname) :" "$VAL_HOSTNAME" \
        --field="🐚 Terminal de commande par défaut :CB" "$VAL_SHELL" \
        --button="Quitter!application-exit:1" \
        --button="Suivant ➔:0") || RET=$?

      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_USERNAME VAL_FULLNAME VAL_PASSWORD VAL_PASSWORD_CONFIRM VAL_HOSTNAME RAW_SHELL _ <<< "$OUTPUT"
      VAL_SHELL=$(mark_selected "$SHELL_CHOICES" "$RAW_SHELL")

      if [ -z "$VAL_USERNAME" ]; then
        yad --css="$CSS_FILE" --error --center --text="❌ Le nom d'utilisateur ne peut pas être vide."
        continue
      fi

      if [ "$DRY_RUN" = false ] && [ -z "$VAL_PASSWORD" ]; then
        yad --css="$CSS_FILE" --error --center --text="❌ Le mot de passe ne peut pas être vide."
        continue
      fi

      if [ "$VAL_PASSWORD" != "$VAL_PASSWORD_CONFIRM" ]; then
        yad --css="$CSS_FILE" --error --center --text="❌ Les deux mots de passe ne correspondent pas."
        continue
      fi

      STEP=2
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 2 : MATÉRIEL & PILOTES GRAPHIQUES
    # -------------------------------------------------------------------------
    2)
      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 2/6" \
        --window-icon="$LOGO_ICON" \
        --width=760 --height=520 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🖥️ Matériel &amp; Graphisme</span> <span size='large' foreground='#a6adc8'>— Étape 2/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Le pilote GPU et le noyau Linux optimisé (Zen pour AMD, XanMod pour NVIDIA/Intel) seront appliqués.</span>\n" \
        --separator="|" \
        --field="🎮 Modèle de votre Carte Graphique (GPU) :CB" "$VAL_GPU" \
        --field="🏎️ Volants de course et Simulation (SimRacing / Oversteer) :CHK" "$VAL_STEERING" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0") || RET=$?

      if [ $RET -eq 2 ]; then STEP=1; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r RAW_GPU VAL_STEERING _ <<< "$OUTPUT"
      VAL_GPU=$(mark_selected "$GPU_CHOICES" "$RAW_GPU")
      STEP=3
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 3 : BUREAU & INTERFACE UTILISATEUR
    # -------------------------------------------------------------------------
    3)
      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 3/6" \
        --window-icon="$LOGO_ICON" \
        --width=760 --height=520 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🎨 Bureau &amp; Navigation</span> <span size='large' foreground='#a6adc8'>— Étape 3/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Choisissez votre environnement visuel et votre navigateur Internet favori.</span>\n" \
        --separator="|" \
        --field="🖥️ Environnement de bureau principal (GNOME ou COSMIC) :CB" "$VAL_DESKTOP" \
        --field="🌐 Navigateur Internet par défaut :CB" "$VAL_BROWSER" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0") || RET=$?

      if [ $RET -eq 2 ]; then STEP=2; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r RAW_DESKTOP RAW_BROWSER _ <<< "$OUTPUT"
      VAL_DESKTOP=$(mark_selected "$DESKTOP_CHOICES" "$RAW_DESKTOP")
      VAL_BROWSER=$(mark_selected "$BROWSER_CHOICES" "$RAW_BROWSER")
      STEP=4
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 4 : GAMING & STEAM OPTIMISATIONS
    # -------------------------------------------------------------------------
    4)
      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 4/6" \
        --window-icon="$LOGO_ICON" \
        --width=760 --height=580 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🕹️ Suite Gaming &amp; Jeux Vidéo</span> <span size='large' foreground='#a6adc8'>— Étape 4/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Sélectionnez vos lanceurs de jeux et optimisations de performances sous Linux.</span>\n" \
        --separator="|" \
        --field="🚀 Optimisations Système Gaming (GameMode, GameScope, Noyau Zen/XanMod) :CHK" "$VAL_GAMING_ENABLE" \
        --field="🎮 Lanceur Steam (Valve &amp; Proton) :CHK" "$VAL_LAUNCHER_STEAM" \
        --field="⚔️ Lutris (Jeux Windows, Battle.net, EA, GOG) :CHK" "$VAL_LAUNCHER_LUTRIS" \
        --field="🦸 Heroic Games Launcher (Epic Games &amp; GOG) :CHK" "$VAL_LAUNCHER_HEROIC" \
        --field="⚡ Faugus Launcher (Nouveau lanceur rapide jeux Windows) :CHK" "$VAL_LAUNCHER_FAUGUS" \
        --field="🔌 Decky Loader pour Steam (Jovian-NixOS / extensions Steam) :CHK" "$VAL_DECKY_ENABLE" \
        --field="☁️ Raccourci NVIDIA GeForce NOW (Cloud Gaming) :CHK" "$VAL_GEFORCE_NOW" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0") || RET=$?

      if [ $RET -eq 2 ]; then STEP=3; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_GAMING_ENABLE VAL_LAUNCHER_STEAM VAL_LAUNCHER_LUTRIS VAL_LAUNCHER_HEROIC VAL_LAUNCHER_FAUGUS VAL_DECKY_ENABLE VAL_GEFORCE_NOW _ <<< "$OUTPUT"
      STEP=5
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 5 : SERVICES, VIRTUALISATION & CRÉATION
    # -------------------------------------------------------------------------
    5)
      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 5/6" \
        --window-icon="$LOGO_ICON" \
        --width=760 --height=560 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🛠️ Virtualisation &amp; Applications</span> <span size='large' foreground='#a6adc8'>— Étape 5/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Activez les outils professionnels, la virtualisation Windows et les logiciels de création.</span>\n" \
        --separator="|" \
        --field="🪟 Virtualisation Windows (Virt-Manager, KVM &amp; pilotes VirtIO) :CHK" "$VAL_VIRT_ENABLE" \
        --field="📁 Partage de fichiers réseau local (Samba &amp; WSDD pour Windows/Mac) :CHK" "$VAL_SAMBA_ENABLE" \
        --field="🎨 Logiciel de modélisation &amp; rendu 3D (Blender) :CHK" "$VAL_BLENDER_ENABLE" \
        --field="🎮 Moteur de création de jeux vidéo (Godot Engine 4) :CHK" "$VAL_GODOT_ENABLE" \
        --field="🎬 Montage Vidéo Professionnel (DaVinci Resolve) :CB" "$VAL_DAVINCI" \
        --field="🤖 Suite IA Locale Privée (Ollama &amp; WebUI) :CHK" "$VAL_AI_SUITE" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0") || RET=$?

      if [ $RET -eq 2 ]; then STEP=4; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_VIRT_ENABLE VAL_SAMBA_ENABLE VAL_BLENDER_ENABLE VAL_GODOT_ENABLE RAW_DAVINCI VAL_AI_SUITE _ <<< "$OUTPUT"
      VAL_DAVINCI=$(mark_selected "$DAVINCI_CHOICES" "$RAW_DAVINCI")
      STEP=6
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 6 : DISQUE CIBLE, SYSTÈME DE FICHIERS & RÉCAPITULATIF
    # -------------------------------------------------------------------------
    6)
      RAW_GPU=$(echo "$VAL_GPU" | awk '{print $1}')
      RAW_GPU="${RAW_GPU#\^}"
      RAW_DESKTOP=$(echo "$VAL_DESKTOP" | awk '{print $1}')
      RAW_DESKTOP="${RAW_DESKTOP#\^}"
      RAW_BROWSER=$(echo "$VAL_BROWSER" | awk '{print $1}')
      RAW_BROWSER="${RAW_BROWSER#\^}"
      RAW_DAVINCI=$(echo "$VAL_DAVINCI" | awk '{print $1}')
      RAW_DAVINCI="${RAW_DAVINCI#\^}"

      case "$RAW_DESKTOP" in
        Gnome*|gnome*) CHOSEN_DESKTOP="GNOME" ;;
        Cosmic*|cosmic*) CHOSEN_DESKTOP="COSMIC" ;;
        *) CHOSEN_DESKTOP="GNOME + COSMIC" ;;
      esac

      LAUNCHERS_LIST=""
      [ "$VAL_LAUNCHER_STEAM" = "TRUE" ] && LAUNCHERS_LIST+="Steam "
      [ "$VAL_LAUNCHER_LUTRIS" = "TRUE" ] && LAUNCHERS_LIST+="Lutris "
      [ "$VAL_LAUNCHER_HEROIC" = "TRUE" ] && LAUNCHERS_LIST+="Heroic "
      [ "$VAL_LAUNCHER_FAUGUS" = "TRUE" ] && LAUNCHERS_LIST+="Faugus "
      [ -z "$LAUNCHERS_LIST" ] && LAUNCHERS_LIST="Aucun"

      RECAP_TEXT="<span size='large' weight='bold' foreground='#cba6f7'>📋 RÉCAPITULATIF DE VOS SÉLECTIONS :</span>\n"
      RECAP_TEXT+="• <b>Compte :</b> <span foreground='#a6e3a1'>$VAL_USERNAME</span> ($VAL_FULLNAME) | Hôte : $VAL_HOSTNAME\n"
      RECAP_TEXT+="• <b>Carte Graphique :</b> <span foreground='#89b4fa'>$RAW_GPU</span> (Pilotes &amp; Noyau optimisés)\n"
      RECAP_TEXT+="• <b>Bureau :</b> <span foreground='#f5c2e7'>$CHOSEN_DESKTOP</span> | Navigateur : $RAW_BROWSER\n"
      RECAP_TEXT+="• <b>Jeux Vidéo :</b> Optimisations ($VAL_GAMING_ENABLE), Launchers: <span foreground='#a6e3a1'>$LAUNCHERS_LIST</span>\n"
      RECAP_TEXT+="• <b>Services :</b> Virt-Manager ($VAL_VIRT_ENABLE), Samba ($VAL_SAMBA_ENABLE)\n"
      RECAP_TEXT+="• <b>Création &amp; IA :</b> Blender ($VAL_BLENDER_ENABLE), Godot ($VAL_GODOT_ENABLE), DaVinci ($RAW_DAVINCI), IA ($VAL_AI_SUITE)\n"

      RET=0
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 6/6" \
        --window-icon="$LOGO_ICON" \
        --width=760 --height=580 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>💾 Récapitulatif &amp; Disque Cible</span> <span size='large' foreground='#a6adc8'>— Étape 6/$TOTAL_STEPS</span>\n\n$RECAP_TEXT\n<span foreground='#b4befe'>Sélectionnez le disque de destination pour l'installation de ChomiamOS (Ext4).</span>\n" \
        --separator="|" \
        --field="<span foreground='#f38ba8' weight='bold'>💾 Disque d'installation de destination :</span>:CB" "$VAL_TARGET_DISK" \
        --field="<span foreground='#f38ba8'><i>⚠️ ATTENTION : Le disque choisi sera entièrement formaté (ESP 1 Go + racine Ext4).</i></span>:LBL" "" \
        --button="⬅ Précédent:2" \
        --button="🚀 Lancer l'installation !:0") || RET=$?

      if [ $RET -eq 2 ]; then STEP=5; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r RAW_TARGET_DISK _ <<< "$OUTPUT"
      VAL_TARGET_DISK=$(mark_selected "$DISKS_CHOICES" "$RAW_TARGET_DISK")
      TARGET_DISK=$(echo "$RAW_TARGET_DISK" | awk '{print $1}')
      # Nettoyage de tout éventuel double préfixe /dev//dev/
      TARGET_DISK="${TARGET_DISK/#\/dev\/\/dev\//\/dev\/}"
      CHOSEN_FS="ext4"

      if [ -z "$TARGET_DISK" ] || [[ ! "$TARGET_DISK" =~ ^/dev/ ]]; then
        yad --css="$CSS_FILE" --error --center --text="❌ Aucun disque cible sélectionné. Veuillez choisir un disque valide."
        continue
      fi

      break
      ;;

  esac
done

# =============================================================================
# 4. ⚠️ AVERTISSEMENT DE SÉCURITÉ
# =============================================================================

if [ "$DRY_RUN" = true ]; then
  yad --css="$CSS_FILE" --info \
    --title="[SIMULATION] Prêt à simuler" \
    --width=540 \
    --center \
    --text="<span foreground='#89b4fa' size='x-large'><b>ℹ️ SIMULATION DU DÉPLOIEMENT</b></span>\n\n<b>Disque Cible :</b> $TARGET_DISK\n<b>Système de fichiers :</b> Ext4 (Standard NixOS)\n<b>Utilisateur :</b> $VAL_USERNAME\n\n<i>Cliquez sur Valider pour lancer la simulation des étapes et prévisualiser votre vars.nix Catppuccin !</i>" \
    --button="Valider et Lancer la Simulation ➔:0"
else
  yad --css="$CSS_FILE" --warning \
    --title="Confirmation Définitive de Formatage" \
    --width=540 \
    --center \
    --text="<span foreground='#f38ba8' size='x-large'><b>⚠️ ATTENTION : DESTRUCTION DES DONNÉES</b></span>\n\nLe disque <b>$TARGET_DISK</b> va être intégralement effacé et formaté en <b>Ext4</b>.\n\nÊtes-vous absolument sûr de vouloir formater et installer ChomiamOS ?" \
    --button="Non, Annuler:1" \
    --button="Oui, Formater et Installer:0"

  if [ $? -ne 0 ]; then
    exit 0
  fi
fi

# =============================================================================
# 5. 📄 GÉNÉRATION DU FICHIER VARS.NIX
# =============================================================================

CLEAN_SHELL=$(echo "$VAL_SHELL" | awk '{print $1}')
CLEAN_SHELL="${CLEAN_SHELL#\^}"

case "$RAW_DESKTOP" in
  Gnome*|gnome*|GNOME*) VAR_DESKTOP="gnome" ;;
  Cosmic*|cosmic*|COSMIC*) VAR_DESKTOP="cosmic" ;;
  *) VAR_DESKTOP="both" ;;
esac

HASHED_PW=""
if [ -n "$VAL_PASSWORD" ]; then
  HASHED_PW=$(mkpasswd -m sha-512 "$VAL_PASSWORD" 2>/dev/null || openssl passwd -6 "$VAL_PASSWORD" 2>/dev/null || true)
fi

HASHED_PW_LINE=""
if [ -n "$HASHED_PW" ]; then
  HASHED_PW_LINE="    initialHashedPassword = \"$HASHED_PW\";"
fi

GENERATED_VARS=$(cat << EOC
{
  # =========================================================================
  # ❄️ CHOMIAMOS — VARIABLES DU SYSTÈME & PROFIL UTILISATEUR
  # Généré automatiquement par l'assistant d'installation ChomiamOS
  # =========================================================================

  hostName = "$VAL_HOSTNAME";
  timeZone = "Europe/Paris";
  defaultLocale = "fr_FR.UTF-8";
  stateVersion = "26.05";

  user = {
    username = "$VAL_USERNAME";
    fullName = "$VAL_FULLNAME";
    homeDirectory = "/home/$VAL_USERNAME";
    shell = "$CLEAN_SHELL";
$HASHED_PW_LINE
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
    ];
  };

  # Virtualisation (Virt-Manager, KVM/QEMU, pilotes VirtIO Windows)
  virtualisation = {
    enable = $([ "$VAL_VIRT_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  };

  # Navigateur web par défaut
  browser = "$RAW_BROWSER";
  firewall = false;

  # Environnement graphique & Pilote GPU
  desktopEnv = "$VAR_DESKTOP";
  gpuDriver = "$RAW_GPU";

  # Suite Gaming & Divertissement
  gaming = {
    enable = $([ "$VAL_GAMING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    launchers = {
      steam = $([ "$VAL_LAUNCHER_STEAM" = "TRUE" ] && echo "true" || echo "false");
      lutris = $([ "$VAL_LAUNCHER_LUTRIS" = "TRUE" ] && echo "true" || echo "false");
      heroic = $([ "$VAL_LAUNCHER_HEROIC" = "TRUE" ] && echo "true" || echo "false");
      faugus = $([ "$VAL_LAUNCHER_FAUGUS" = "TRUE" ] && echo "true" || echo "false");
    };
    deckyLoader = $([ "$VAL_DECKY_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    geforceNow = $([ "$VAL_GEFORCE_NOW" = "TRUE" ] && echo "true" || echo "false");
    mountGamesDisk = false;
  };

  # Support des Volants SimRacing (Oversteer + drivers kernel)
  steeringWheelSupport = $([ "$VAL_STEERING" = "TRUE" ] && echo "true" || echo "false");

  # Applications de création
  davinciResolve = "$RAW_DAVINCI";
  blender = $([ "$VAL_BLENDER_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  godot = $([ "$VAL_GODOT_ENABLE" = "TRUE" ] && echo "true" || echo "false");

  # Suite IA Locale
  aiSuite = {
    enable = $([ "$VAL_AI_SUITE" = "TRUE" ] && echo "true" || echo "false");
    rocmOverrideGfx = "12.0.1";
    keepAlive = "0s";
    openWebUiPort = 8080;
    searxPort = 8888;
  };
}
EOC
)

# =============================================================================
# 6. 🚀 DÉROULEMENT DU DÉPLOIEMENT OU DE LA SIMULATION
# =============================================================================

if [ "$DRY_RUN" = true ]; then
  (
    echo "10"; echo "# [Simulation] Démontage des anciens montages..." ; sleep 1
    echo "25"; echo "# [Simulation] Création de la table de partitionnement GPT sur $TARGET_DISK..." ; sleep 1
    echo "40"; echo "# [Simulation] Formatage ESP (FAT32) et ROOT (Ext4 standard)..." ; sleep 1
    echo "55"; echo "# [Simulation] Détection matérielle de la machine (nixos-generate-config)..." ; sleep 1
    echo "70"; echo "# [Simulation] Téléchargement du framework officiel ChomiamOS..." ; sleep 1
    echo "85"; echo "# [Simulation] Injection du fichier vars.nix personnalisé..." ; sleep 1
    echo "95"; echo "# [Simulation] Compilation NixOS et installation du bootloader EFI..." ; sleep 1
    echo "100"; echo "# [Simulation] Déploiement terminé avec succès !" ; sleep 0.5
    echo "-> Exécution de la simulation en cours..."
  ) | yad --css="$CSS_FILE" --progress \
          --title="[Simulation] Déroulement de l'installation..." \
          --text="Initialisation de la simulation..." \
          --percentage=0 \
          --enable-log="Console & Journal d'installation" \
          --log-expanded \
          --log-height=180 \
          --auto-close \
          --width=750 \
          --center

  echo "$GENERATED_VARS" | yad --css="$CSS_FILE" --text-info \
    --title="[Simulation] Prévisualisation du vars.nix généré" \
    --width=700 --height=550 \
    --center \
    --button="Valider le fichier vars.nix ➔:0" || true

  yad --css="$CSS_FILE" --question \
      --title="[Simulation] Installation Terminée !" \
      --width=520 \
      --center \
      --text="<span size='large' weight='bold' foreground='#a6e3a1'>🎉 Félicitations !</span>\n\nChomiamOS Gaming Edition a été simulé avec succès (Ext4).\n\n<i>En conditions réelles sur le Live-CD, ce message vous propose de redémarrer immédiatement pour accéder à votre nouveau bureau ChomiamOS.</i>\n\nSouhaitez-vous redémarrer l'ordinateur dès maintenant ?" \
      --button="Non, plus tard:1" \
      --button="Oui, Redémarrer (Simulation):0"
  if [ $? -eq 0 ]; then
    yad --css="$CSS_FILE" --info \
      --title="[Simulation] Redémarrage" \
      --width=460 \
      --center \
      --text="<span foreground='#89b4fa' size='large'><b>🔄 Redémarrage simulé</b></span>\n\nDans l'installation réelle sur Live-CD, l'ordinateur redémarre instantanément." \
      --button="Terminer:0"
  fi
  exit 0
fi

# =============================================================================
# 7. ⚡ EXÉCUTION RÉELLE DE L'INSTALLATION NIXOS
# =============================================================================

LOG_FILE="/tmp/chomiamos-install.log"
rm -f "$LOG_FILE"

(
  set -e
  set -o pipefail

  IS_EFI=false
  if [ -d /sys/firmware/efi ]; then
    IS_EFI=true
  fi

  echo "5"; echo "# Démontage des volumes existants..."
  umount -R /mnt 2>/dev/null || true
  swapoff -a 2>/dev/null || true
  udevadm settle

  echo "10"; echo "# Nettoyage des anciennes signatures de disque..."
  wipefs -af "$TARGET_DISK" 2>/dev/null || true

  if [ "$IS_EFI" = true ]; then
    echo "15"; echo "# Partitionnement GPT (Mode UEFI) de $TARGET_DISK..."
    parted -s "$TARGET_DISK" -- mklabel gpt
    parted -s "$TARGET_DISK" -- mkpart ESP fat32 1MiB 1024MiB
    parted -s "$TARGET_DISK" -- set 1 esp on
    parted -s "$TARGET_DISK" -- mkpart root ext4 1024MiB 100%
  else
    echo "15"; echo "# Partitionnement GPT (Mode BIOS hérité) de $TARGET_DISK..."
    parted -s "$TARGET_DISK" -- mklabel gpt
    parted -s "$TARGET_DISK" -- mkpart bios_grub 1MiB 3MiB
    parted -s "$TARGET_DISK" -- set 1 bios_grub on
    parted -s "$TARGET_DISK" -- mkpart root ext4 3MiB 100%
  fi

  # Forcer le rechargement de la table de partition par le noyau
  sync
  partprobe "$TARGET_DISK" 2>/dev/null || true
  udevadm settle
  sleep 2

  if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    P1="${TARGET_DISK}p1"
    P2="${TARGET_DISK}p2"
  else
    P1="${TARGET_DISK}1"
    P2="${TARGET_DISK}2"
  fi

  if [ "$IS_EFI" = true ]; then
    BOOT_PART="$P1"
    ROOT_PART="$P2"
  else
    BOOT_PART=""
    ROOT_PART="$P2"
  fi

  echo "20"; echo "# Nettoyage approfondi des partitions..."
  [ -n "$BOOT_PART" ] && wipefs -af "$BOOT_PART" 2>/dev/null || true
  wipefs -af "$ROOT_PART" 2>/dev/null || true
  sync
  udevadm settle

  echo "25"; echo "# Formatage de la partition système en Ext4..."
  [ -n "$BOOT_PART" ] && mkfs.fat -F 32 -n BOOT "$BOOT_PART"
  mkfs.ext4 -F -L nixos "$ROOT_PART"
  sync
  udevadm settle
  sleep 1

  echo "35"; echo "# Montage des partitions système..."
  mkdir -p /mnt
  mount -t ext4 "$ROOT_PART" /mnt
  if [ -n "$BOOT_PART" ]; then
    mkdir -p /mnt/boot
    mount -t vfat "$BOOT_PART" /mnt/boot
  fi

  echo "45"; echo "# Téléchargement du framework ChomiamOS..."
  mkdir -p /mnt/etc
  if [ -d "/mnt/etc/nixos" ]; then
    rm -rf /mnt/etc/nixos
  fi
  git clone https://github.com/Chomiam/nix_config_gaming.git /mnt/etc/nixos

  echo "55"; echo "# Détection du matériel réel (nixos-generate-config)..."
  mkdir -p /tmp/nixos-hw
  nixos-generate-config --root /mnt --dir /tmp/nixos-hw

  if [ -f "/tmp/nixos-hw/hardware-configuration.nix" ]; then
    cp -f /tmp/nixos-hw/hardware-configuration.nix /mnt/etc/nixos/hosts/desktop/hardware-configuration.nix
  fi

  if [ "$IS_EFI" = false ]; then
    cat << EOC > /mnt/etc/nixos/hosts/desktop/mount.nix
{ config, lib, ... }:
{
  # Machine en mode BIOS hérité (non-UEFI)
  boot.loader.grub.efiSupport = lib.mkForce false;
  boot.loader.grub.device = lib.mkForce "${TARGET_DISK}";
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}
EOC
  else
    cat << 'EOC' > /mnt/etc/nixos/hosts/desktop/mount.nix
{ config, ... }:
{
  # Déclarez ici vos disques additionnels (ex: /mnt/Games)
}
EOC
  fi

  echo "65"; echo "# Injection du fichier vars.nix personnalisé..."
  echo "$GENERATED_VARS" > /mnt/etc/nixos/vars.nix

  # Flake git staging : indispensable pour que Nix voie les nouveaux fichiers
  git -C /mnt/etc/nixos add -A

  echo "70"; echo "# Démarrage du déploiement NixOS (nixos-install)..."
  
  # Lancement direct en arrière-plan avec écriture directe dans le fichier de log (0 surcharge CPU)
  nixos-install --flake /mnt/etc/nixos#default --no-root-password --show-trace >> "$LOG_FILE" 2>&1 &
  INSTALL_PID=$!

  PCT=70
  # Boucle de rafraîchissement légère : 1 seule mise à jour par seconde pour ne pas saturer GTK
  while kill -0 "$INSTALL_PID" 2>/dev/null; do
    sleep 1
    LAST_LINE=$(tail -n 10 "$LOG_FILE" 2>/dev/null | grep -E "copying path|building" | tail -n 1 || true)
    if [ -n "$LAST_LINE" ]; then
      PKG_NAME=$(echo "$LAST_LINE" | sed -E "s|.*/nix/store/[a-z0-9]+-([^ '.]*).*|\1|")
      if echo "$LAST_LINE" | grep -q "copying path"; then
        echo "# ⬇️ Téléchargement : $PKG_NAME"
      else
        echo "# ⚙️ Compilation : $PKG_NAME"
      fi
    fi
    if [ $PCT -lt 94 ]; then
      PCT=$((PCT + 1))
      echo "$PCT"
    fi
  done

  # Récupération du statut réel
  wait "$INSTALL_PID"
  INSTALL_STATUS=$?
  if [ $INSTALL_STATUS -ne 0 ]; then
    exit $INSTALL_STATUS
  fi

  echo "95"; echo "# Configuration et vérification du compte utilisateur..."
  if [ -n "$VAL_PASSWORD" ]; then
    echo "$VAL_USERNAME:$VAL_PASSWORD" | nixos-enter --root /mnt -c "chpasswd" 2>/dev/null || \
    echo "$VAL_USERNAME:$VAL_PASSWORD" | chroot /mnt /nix/var/nix/profiles/system/sw/bin/chpasswd 2>/dev/null || \
    echo "$VAL_USERNAME:$VAL_PASSWORD" | chroot /mnt /run/current-system/sw/bin/chpasswd 2>/dev/null || true
  fi

  echo "100"; echo "# Installation terminée avec succès !"
) 2>&1 | tee -a "$LOG_FILE" | yad --css="$CSS_FILE" --progress \
        --title="Installation de ChomiamOS en cours..." \
        --text="Préparation de l'installation..." \
        --percentage=0 \
        --enable-log="Console & Journal d'installation" \
        --log-expanded \
        --log-height=240 \
        --auto-close \
        --width=800 \
        --center

INSTALL_STATUS=${PIPESTATUS[0]}

if [ $INSTALL_STATUS -eq 0 ]; then
  yad --css="$CSS_FILE" --question \
      --title="Installation Terminée !" \
      --width=480 \
      --center \
      --text="<span size='large' weight='bold' foreground='#a6e3a1'>🎉 Félicitations !</span>\n\nChomiamOS Gaming Edition a été installé avec succès sur votre machine (Ext4).\n\nSouhaitez-vous redémarrer l'ordinateur dès maintenant ?" \
      --button="Non, plus tard:1" \
      --button="Oui, Redémarrer:0"
  if [ $? -eq 0 ]; then
    reboot
  fi
else
  ERROR_SNIPPET=$(tail -n 15 "$LOG_FILE" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  yad --css="$CSS_FILE" --error \
      --title="Erreur d'installation" \
      --width=720 --height=460 \
      --center \
      --text="<span size='large' weight='bold' foreground='#f38ba8'>❌ L'installation a rencontré une erreur !</span>\n\n<span foreground='#cdd6f4'>Dernières lignes du journal d'erreur :</span>\n<tt><span foreground='#f38ba8'>$ERROR_SNIPPET</span></tt>" \
      --button="Voir journal complet:2" \
      --button="Fermer:0"
  RET_ERR=$?
  if [ $RET_ERR -eq 2 ]; then
    yad --css="$CSS_FILE" --text-info --title="Journal d'installation complet" --filename="$LOG_FILE" --width=800 --height=600 --center
  fi
fi
