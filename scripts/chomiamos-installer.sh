#!/usr/bin/env bash
# =============================================================================
# ❄️ CHOMIAMOS INSTALLER — Assistant Graphique d'Installation (Yad / Catppuccin)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_FILE="$SCRIPT_DIR/theme/catppuccin-mocha.css"

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
# 1. 🔍 AUTO-DÉTECTION DU MATÉRIEL
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
  GPU_CHOICES="^nvidia (Cartes récentes GTX 1650 / RTX, Pilotes stables, Kernel XanMod)!amd (Radeon RADV Vulkan, ROCm OpenCL, Kernel Zen)!intel (Arc / iGPU, Media Driver, Kernel XanMod)!nvidia-legacy (Cartes < GTX 1650 : 10xx, 9xx, Pilotes legacy 470)"
elif [ "$DETECTED_GPU" = "intel" ]; then
  GPU_CHOICES="^intel (Arc / iGPU, Media Driver, Kernel XanMod)!amd (Radeon RADV Vulkan, ROCm OpenCL, Kernel Zen)!nvidia (Cartes récentes GTX 1650 / RTX, Pilotes stables, Kernel XanMod)!nvidia-legacy (Cartes < GTX 1650 : 10xx, 9xx, Pilotes legacy 470)"
else
  GPU_CHOICES="^amd (Radeon RADV Vulkan, ROCm OpenCL, Kernel Zen)!nvidia (Cartes récentes GTX 1650 / RTX, Pilotes stables, Kernel XanMod)!intel (Arc / iGPU, Media Driver, Kernel XanMod)!nvidia-legacy (Cartes < GTX 1650 : 10xx, 9xx, Pilotes legacy 470)"
fi

# Détection des disques
DISKS=()
if [ "$DRY_RUN" = true ]; then
  DISKS+=("/dev/nvme0n1 (1.0 TB - Samsung SSD 990 PRO NVMe [SIMULATION])")
  DISKS+=("/dev/sda (2.0 TB - Crucial CT2000MX500 SSD [SIMULATION])")
else
  INSTALLER_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed -E 's/[0-9]+$//' | sed -E 's/p[0-9]+$//' || true)
  while read -r name size model; do
    dev="/dev/$name"
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

DISKS_CHOICES=$(IFS="!"; echo "${DISKS[*]}")

# =============================================================================
# 2. 🎛️ VALEURS PAR DÉFAUT DU FORMULAIRE
# =============================================================================

VAL_USERNAME="chomiam"
VAL_FULLNAME="Axel Valens"
VAL_PASSWORD=""
VAL_PASSWORD_CONFIRM=""
VAL_HOSTNAME="chomiamos"
VAL_SHELL="^fish (Recommandé)!zsh!bash"

VAL_GPU="$GPU_CHOICES"
VAL_STEERING="TRUE"

VAL_DESKTOP="^gnome (GNOME 48+ avec extensions &amp; modèles bureautiques)!cosmic (COSMIC Desktop Wayland en Rust)!both (Installer les deux environnements)"
VAL_BROWSER="^chrome (Google Chrome - Paquet Nix)!firefox (Mozilla Firefox - Paquet Nix)!zen (Zen Browser - Flatpak)!librewolf (LibreWolf - Paquet Nix)!opera-gx (Opera GX - Flatpak)!opera (Opera - Flatpak)"

VAL_GAMING_ENABLE="TRUE"
VAL_DECKY_ENABLE="TRUE"
VAL_GEFORCE_NOW="TRUE"

VAL_VIRT_ENABLE="TRUE"
VAL_SAMBA_ENABLE="TRUE"
VAL_BLENDER_ENABLE="TRUE"
VAL_GODOT_ENABLE="TRUE"
VAL_DAVINCI="^none (Désactivé)!free (DaVinci Resolve Gratuit)!studio (DaVinci Resolve Studio)"
VAL_AI_SUITE="FALSE"

VAL_TARGET_DISK="$DISKS_CHOICES"

# =============================================================================
# 3. 🧙 ASSISTANT MULTI-PAGES (CATPPUCCIN MOCHA WIZARD)
# =============================================================================

STEP=1
TOTAL_STEPS=6

while true; do
  case $STEP in

    # -------------------------------------------------------------------------
    # ÉTAPE 1 : IDENTITÉ & COMPTE UTILISATEUR
    # -------------------------------------------------------------------------
    1)
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 1/6" \
        --window-icon="system-software-install" \
        --width=720 --height=550 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>❄️ ChomiamOS</span> <span size='large' foreground='#a6adc8'>— Étape 1/$TOTAL_STEPS : Compte &amp; Système</span>\n<span foreground='#b4befe'>Configurez votre utilisateur principal et l'identité réseau de votre machine.</span>\n" \
        --separator="|" \
        --field="<b>Nom d'utilisateur</b> :" "$VAL_USERNAME" \
        --field="<b>Nom complet</b> :" "$VAL_FULLNAME" \
        --field="<b>Mot de passe</b> :H" "$VAL_PASSWORD" \
        --field="<b>Confirmation du mot de passe</b> :H" "$VAL_PASSWORD_CONFIRM" \
        --field="<b>Nom d'hôte (Hostname)</b> :" "$VAL_HOSTNAME" \
        --field="<b>Shell interactif par défaut</b> :CB" "$VAL_SHELL" \
        --button="Quitter!application-exit:1" \
        --button="Suivant ➔:0")

      RET=$?
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_USERNAME VAL_FULLNAME VAL_PASSWORD VAL_PASSWORD_CONFIRM VAL_HOSTNAME VAL_SHELL _ <<< "$OUTPUT"

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
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 2/6" \
        --window-icon="system-software-install" \
        --width=740 --height=520 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🖥️ Matériel &amp; Graphisme</span> <span size='large' foreground='#a6adc8'>— Étape 2/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Optimisations matérielles, sélection du pilote GPU et périphériques.</span>\n" \
        --separator="|" \
        --field="<b>Carte Graphique principale</b> :CB" "$VAL_GPU" \
        --field="<i>Le pilote adapté et le noyau Linux optimisé (Zen / XanMod) seront configurés automatiquement.</i>:LBL" "" \
        --field="<b>Support SimRacing &amp; Volants FFB</b> :CHK" "$VAL_STEERING" \
        --field="<i>Active les drivers noyau (Logitech, Fanatec, Thrustmaster) et l'outil GUI Oversteer.</i>:LBL" "" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0")

      RET=$?
      if [ $RET -eq 2 ]; then STEP=1; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_GPU _ VAL_STEERING _ <<< "$OUTPUT"
      STEP=3
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 3 : BUREAU & INTERFACE UTILISATEUR
    # -------------------------------------------------------------------------
    3)
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 3/6" \
        --window-icon="system-software-install" \
        --width=740 --height=520 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🎨 Bureau &amp; Navigation</span> <span size='large' foreground='#a6adc8'>— Étape 3/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Personnalisation de votre environnement de travail quotidien.</span>\n" \
        --separator="|" \
        --field="<b>Environnement de bureau</b> :CB" "$VAL_DESKTOP" \
        --field="<i>GNOME Shell propose le thème Catppuccin et les modèles bureautiques (.docx, .xlsx, .pptx). COSMIC Desktop est le nouveau bureau moderne en Rust.</i>:LBL" "" \
        --field="<b>Navigateur web par défaut</b> :CB" "$VAL_BROWSER" \
        --field="<i>Configuré automatiquement dans le dock et comme navigateur par défaut du système.</i>:LBL" "" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0")

      RET=$?
      if [ $RET -eq 2 ]; then STEP=2; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_DESKTOP _ VAL_BROWSER _ <<< "$OUTPUT"
      STEP=4
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 4 : GAMING & STEAM OPTIMISATIONS
    # -------------------------------------------------------------------------
    4)
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 4/6" \
        --window-icon="system-software-install" \
        --width=750 --height=550 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🕹️ Suite Gaming &amp; Divertissement</span> <span size='large' foreground='#a6adc8'>— Étape 4/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>L'arsenal ultime pour le jeu vidéo sous Linux.</span>\n" \
        --separator="|" \
        --field="<b>Activer la suite Gaming complète</b> :CHK" "$VAL_GAMING_ENABLE" \
        --field="<i>Inclut Steam FHS, GameMode, GameScope (Wayland HDR/FSR), Sunshine (Streaming), Lutris, Heroic et ProtonPlus.</i>:LBL" "" \
        --field="<b>Activer Decky Loader (Jovian-NixOS)</b> :CHK" "$VAL_DECKY_ENABLE" \
        --field="<i>Gestionnaire officiel de plugins Steam (thèmes, audio, animations) avec débogage distant CEF activé.</i>:LBL" "" \
        --field="<b>Accès rapide NVIDIA GeForce NOW</b> :CHK" "$VAL_GEFORCE_NOW" \
        --field="<i>Client de cloud gaming intégré avec gestion automatique de la fenêtre sous Wayland.</i>:LBL" "" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0")

      RET=$?
      if [ $RET -eq 2 ]; then STEP=3; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_GAMING_ENABLE _ VAL_DECKY_ENABLE _ VAL_GEFORCE_NOW _ <<< "$OUTPUT"
      STEP=5
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 5 : SERVICES, VIRTUALISATION & CRÉATION
    # -------------------------------------------------------------------------
    5)
      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 5/6" \
        --window-icon="system-software-install" \
        --width=780 --height=600 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>🛠️ Services, Virtualisation &amp; Création</span> <span size='large' foreground='#a6adc8'>— Étape 5/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Outils de virtualisation Windows et applications professionnelles.</span>\n" \
        --separator="|" \
        --field="<b>Virtualisation KVM / Virt-Manager</b> :CHK" "$VAL_VIRT_ENABLE" \
        --field="<i>Intègre libvirtd, VirtioFS, et les pilotes VirtIO certifiés Windows 10/11 et Windows 7 dans /etc.</i>:LBL" "" \
        --field="<b>Partage de fichiers Samba &amp; WSDD</b> :CHK" "$VAL_SAMBA_ENABLE" \
        --field="<i>Partage déclaratif de votre dossier personnel sur le réseau local avec découverte Windows sans config.</i>:LBL" "" \
        --field="<b>Logiciels de création 3D &amp; Moteur</b> :LBL" "" \
        --field="Installer Blender 3D (nixpkgs-unstable) :CHK" "$VAL_BLENDER_ENABLE" \
        --field="Installer Godot Engine 4 (nixpkgs-unstable) :CHK" "$VAL_GODOT_ENABLE" \
        --field="<b>Montage vidéo DaVinci Resolve</b> :CB" "$VAL_DAVINCI" \
        --field="<b>Suite IA Locale Privée (Ollama + WebUI + SearXNG)</b> :CHK" "$VAL_AI_SUITE" \
        --button="⬅ Précédent:2" \
        --button="Suivant ➔:0")

      RET=$?
      if [ $RET -eq 2 ]; then STEP=4; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r VAL_VIRT_ENABLE _ VAL_SAMBA_ENABLE _ _ VAL_BLENDER_ENABLE VAL_GODOT_ENABLE VAL_DAVINCI VAL_AI_SUITE _ <<< "$OUTPUT"
      STEP=6
      ;;

    # -------------------------------------------------------------------------
    # ÉTAPE 6 : DISQUE CIBLE & CONFIRMATION
    # -------------------------------------------------------------------------
    6)
      RAW_GPU=$(echo "$VAL_GPU" | awk '{print $1}')
      RAW_DESKTOP=$(echo "$VAL_DESKTOP" | awk '{print $1}')
      RAW_BROWSER=$(echo "$VAL_BROWSER" | awk '{print $1}')
      RAW_DAVINCI=$(echo "$VAL_DAVINCI" | awk '{print $1}')

      RECAP_TEXT="<span size='large' weight='bold' foreground='#cba6f7'>📋 RÉCAPITULATIF DE VOTRE CONFIGURATION :</span>\n\n"
      RECAP_TEXT+="• <b>Utilisateur :</b> <span foreground='#a6e3a1'>$VAL_USERNAME</span> ($VAL_FULLNAME)\n"
      RECAP_TEXT+="• <b>Machine :</b> $VAL_HOSTNAME | Shell : $(echo "$VAL_SHELL" | awk '{print $1}')\n"
      RECAP_TEXT+="• <b>Carte Graphique :</b> <span foreground='#89b4fa'>$RAW_GPU</span>\n"
      RECAP_TEXT+="• <b>Bureau :</b> <span foreground='#f5c2e7'>$RAW_DESKTOP</span> | Navigateur : $RAW_BROWSER\n"
      RECAP_TEXT+="• <b>Gaming :</b> Steam/Tweaks ($VAL_GAMING_ENABLE), Decky Loader ($VAL_DECKY_ENABLE), SimRacing ($VAL_STEERING)\n"
      RECAP_TEXT+="• <b>Virtualisation :</b> Virt-Manager ($VAL_VIRT_ENABLE) | Samba ($VAL_SAMBA_ENABLE)\n"
      RECAP_TEXT+="• <b>Création :</b> Blender ($VAL_BLENDER_ENABLE), Godot ($VAL_GODOT_ENABLE), DaVinci ($RAW_DAVINCI)\n"

      OUTPUT=$(yad --css="$CSS_FILE" --form \
        --title="ChomiamOS Installer — Étape 6/6" \
        --window-icon="system-software-install" \
        --width=760 --height=580 \
        --center \
        --text="<span size='xx-large' weight='bold' foreground='#cba6f7'>💾 Disque Cible &amp; Validation</span> <span size='large' foreground='#a6adc8'>— Étape 6/$TOTAL_STEPS</span>\n<span foreground='#b4befe'>Sélectionnez le disque de destination pour installer ChomiamOS.</span>\n" \
        --separator="|" \
        --field="$RECAP_TEXT:LBL" "" \
        --field="<span foreground='#f38ba8' weight='bold'>Sélectionnez le disque d'installation :</span>:CB" "$VAL_TARGET_DISK" \
        --field="<span foreground='#f38ba8'><i>⚠️ ATTENTION : Le disque choisi sera entièrement reformaté (table GPT + ESP 1 Go + partition racine).</i></span>:LBL" "" \
        --button="⬅ Précédent:2" \
        --button="🚀 Lancer l'installation !:0")

      RET=$?
      if [ $RET -eq 2 ]; then STEP=5; continue; fi
      if [ $RET -ne 0 ]; then exit 0; fi

      IFS="|" read -r _ RAW_TARGET_DISK _ <<< "$OUTPUT"
      TARGET_DISK=$(echo "$RAW_TARGET_DISK" | awk '{print $1}')

      # Sortie de la boucle pour démarrer l'installation
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
    --width=520 \
    --center \
    --text="<span foreground='#89b4fa' size='x-large'><b>ℹ️ SIMULATION DU DÉPLOIEMENT</b></span>\n\nTous vos paramètres ont été enregistrés avec succès.\n\n<i>Cliquez sur Valider pour exécuter la simulation des étapes et prévisualiser votre vars.nix Catppuccin !</i>" \
    --button="Valider et Lancer la Simulation ➔:0"
else
  yad --css="$CSS_FILE" --warning \
    --title="Confirmation Définitive de Formatage" \
    --width=540 \
    --center \
    --text="<span foreground='#f38ba8' size='x-large'><b>⚠️ ATTENTION : DESTRUCTION DES DONNÉES</b></span>\n\nLe disque <b>$TARGET_DISK</b> va être intégralement effacé.\n\nÊtes-vous absolument sûr de vouloir formater et installer ChomiamOS ?" \
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
  desktopEnv = "$RAW_DESKTOP";
  gpuDriver = "$RAW_GPU";

  # Suite Gaming & Divertissement
  gaming = {
    enable = $([ "$VAL_GAMING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
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
    echo "40"; echo "# [Simulation] Formatage de la partition EFI (FAT32) et Système (Ext4)..." ; sleep 1
    echo "55"; echo "# [Simulation] Détection matérielle de la machine (nixos-generate-config)..." ; sleep 1
    echo "70"; echo "# [Simulation] Téléchargement du framework officiel ChomiamOS..." ; sleep 1
    echo "85"; echo "# [Simulation] Injection du fichier vars.nix personnalisé..." ; sleep 1
    echo "95"; echo "# [Simulation] Compilation NixOS et installation du bootloader EFI..." ; sleep 1
    echo "100"; echo "# [Simulation] Déploiement terminé avec succès !" ; sleep 0.5
  ) | yad --css="$CSS_FILE" --progress \
          --title="[Simulation] Déroulement de l'installation..." \
          --text="Initialisation de la simulation..." \
          --percentage=0 \
          --auto-close \
          --width=600 \
          --center

  echo "$GENERATED_VARS" | yad --css="$CSS_FILE" --text-info \
    --title="[Simulation] Prévisualisation du vars.nix généré" \
    --width=700 --height=550 \
    --center \
    --button="Terminer la simulation!gtk-ok:0"

  yad --css="$CSS_FILE" --info \
    --title="Simulation Réussie !" \
    --width=480 \
    --center \
    --text="<span size='large' weight='bold' foreground='#a6e3a1'>🎉 Félicitations !</span>\n\nToutes les étapes ont été simulées avec succès dans le thème <b>Catppuccin Mocha</b>.\n\nAucune modification n'a été apportée à vos disques réels." \
    --button="Fermer:0"
  exit 0
fi

# =============================================================================
# 7. ⚡ EXÉCUTION RÉELLE DE L'INSTALLATION NIXOS
# =============================================================================

(
  echo "10"; echo "# Démontage des volumes existants..."
  umount -R /mnt 2>/dev/null || true
  swapoff -a 2>/dev/null || true

  echo "20"; echo "# Partitionnement GPT de $TARGET_DISK..."
  parted -s "$TARGET_DISK" mklabel gpt
  parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 1024MiB
  parted -s "$TARGET_DISK" set 1 esp on
  parted -s "$TARGET_DISK" mkpart primary 1024MiB 100%

  sleep 2
  udevadm settle

  if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
  else
    BOOT_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
  fi

  echo "35"; echo "# Formatage du système de fichiers..."
  mkfs.fat -F 32 -n BOOT "$BOOT_PART"
  mkfs.ext4 -F -L nixos "$ROOT_PART"

  echo "45"; echo "# Montage des partitions..."
  mount "$ROOT_PART" /mnt
  mkdir -p /mnt/boot
  mount "$BOOT_PART" /mnt/boot

  echo "55"; echo "# Détection du matériel réel (nixos-generate-config)..."
  nixos-generate-config --root /mnt

  echo "65"; echo "# Téléchargement du framework ChomiamOS..."
  mkdir -p /mnt/etc
  if [ -d "/mnt/etc/nixos" ]; then
    rm -rf /mnt/etc/nixos
  fi
  git clone https://github.com/Chomiam/nix_config_gaming.git /mnt/etc/nixos

  if [ -f "/mnt/etc/nixos/hardware-configuration.nix" ]; then
    cp -f /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/desktop/hardware-configuration.nix
  fi

  cat << 'EOC' > /mnt/etc/nixos/hosts/desktop/mount.nix
{ config, ... }:
{
  # Déclarez ici vos disques additionnels (ex: /mnt/Games)
}
EOC

  echo "75"; echo "# Génération personnalisée de vars.nix..."
  echo "$GENERATED_VARS" > /mnt/etc/nixos/vars.nix

  echo "85"; echo "# Compilation et déploiement du système (nixos-install)..."
  nixos-install --flake /mnt/etc/nixos#chomiamos --no-root-password

  echo "95"; echo "# Configuration du mot de passe utilisateur..."
  echo "$VAL_USERNAME:$VAL_PASSWORD" | chroot /mnt chpasswd

  echo "100"; echo "# Installation terminée avec succès !"
) | yad --css="$CSS_FILE" --progress \
        --title="Installation de ChomiamOS en cours..." \
        --text="Préparation de l'installation..." \
        --percentage=0 \
        --auto-close \
        --width=600 \
        --center

if [ $? -eq 0 ]; then
  yad --css="$CSS_FILE" --question \
      --title="Installation Terminée !" \
      --width=480 \
      --center \
      --text="<span size='large' weight='bold' foreground='#a6e3a1'>🎉 Félicitations !</span>\n\nChomiamOS Gaming Edition a été installé avec succès sur votre machine.\n\nSouhaitez-vous redémarrer l'ordinateur dès maintenant ?" \
      --button="Non, plus tard:1" \
      --button="Oui, Redémarrer:0"
  if [ $? -eq 0 ]; then
    reboot
  fi
fi
