#!/usr/bin/env bash
# =============================================================================
# ❄️ CHOMIAMOS INSTALLER — Assistant Graphique d'Installation (Yad)
# =============================================================================

set -e

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

# A. Détection GPU
DETECTED_GPU="amd"
if lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "nvidia"; then
  DETECTED_GPU="nvidia"
elif lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "intel"; then
  DETECTED_GPU="intel"
elif lspci 2>/dev/null | grep -i "vga\|3d" | grep -qi "amd\|ati"; then
  DETECTED_GPU="amd"
fi

# Construction de la liste des choix GPU avec détection en premier
if [ "$DETECTED_GPU" = "nvidia" ]; then
  GPU_CHOICES="^nvidia (Détecté)!amd!intel!nvidia-legacy"
elif [ "$DETECTED_GPU" = "intel" ]; then
  GPU_CHOICES="^intel (Détecté)!amd!nvidia!nvidia-legacy"
else
  GPU_CHOICES="^amd (Détecté)!nvidia!intel!nvidia-legacy"
fi

# B. Détection des disques cibles
DISKS=()
if [ "$DRY_RUN" = true ]; then
  DISKS+=("/dev/nvme0n1 (1.0 TB - Samsung SSD 990 PRO [SIMULATION])")
  DISKS+=("/dev/sda (2.0 TB - Crucial CT2000MX500 [SIMULATION])")
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
  yad --error \
      --title="Erreur de détection" \
      --width=400 \
      --text="❌ Aucun disque de stockage détecté pour l'installation." \
      --button="Quitter:1"
  exit 1
fi

DISKS_CHOICES=$(IFS="!"; echo "${DISKS[*]}")

# Titre de la fenêtre
WINDOW_TITLE="Assistant d'installation ChomiamOS Gaming Edition"
HEADER_TEXT="<b>Bienvenue dans l'installateur officiel de ChomiamOS !</b>\nConfigurez votre système selon votre matériel et vos préférences."

if [ "$DRY_RUN" = true ]; then
  WINDOW_TITLE="[MODE SIMULATION] Assistant d'installation ChomiamOS"
  HEADER_TEXT="<span foreground='blue'><b>MODE SIMULATION ACTIVÉ</b></span>\n<i>Aucun disque ne sera formaté ni modifié.</i>"
fi

# =============================================================================
# 2. 📋 INTERFACE GRAPHIQUE YAD : FORMULAIRE D'INSTALLATION
# =============================================================================

OUTPUT=$(yad --form \
  --title="$WINDOW_TITLE" \
  --window-icon="system-software-install" \
  --width=680 --height=580 \
  --center \
  --text="$HEADER_TEXT" \
  --separator="|" \
  --field="<b>👤 UTILISATEUR & SYSTÈME</b>:LBL" "" \
  --field="Nom d'utilisateur :" "chomiam" \
  --field="Nom complet :" "Axel Valens" \
  --field="Mot de passe du compte :H" "secret" \
  --field="Confirmation du mot de passe :H" "secret" \
  --field="Nom d'hôte (Hostname) :" "chomiamos" \
  --field="<b>🎮 MATÉRIEL & GAMING</b>:LBL" "" \
  --field="Carte graphique principale :CB" "$GPU_CHOICES" \
  --field="Environnement de bureau :CB" "^gnome!cosmic!both" \
  --field="Activer la Suite Gaming & Steam :CHK" TRUE \
  --field="Activer Decky Loader (Steam) :CHK" TRUE \
  --field="Activer le support des Volants SimRacing :CHK" TRUE \
  --field="<b>🖥️ VIRTUALISATION & SERVICES</b>:LBL" "" \
  --field="Activer Virt-Manager / KVM (Windows 10/11/7) :CHK" TRUE \
  --field="Activer le partage réseau Samba (SMB / CIFS) :CHK" TRUE \
  --field="<b>💾 DISQUE CIBLE</b>:LBL" "" \
  --field="Disque d'installation :CB" "$DISKS_CHOICES" \
  --button="Annuler!application-exit:1" \
  --button="Lancer l'installation !:0")

if [ $? -ne 0 ] || [ -z "$OUTPUT" ]; then
  exit 0
fi

# =============================================================================
# 3. ⚙️ TRAITEMENT DES VALEURS DU FORMULAIRE
# =============================================================================

IFS="|" read -r _ USERNAME FULLNAME PASSWORD PASSWORD_CONFIRM HOSTNAME \
                _ RAW_GPU RAW_DESKTOP GAMING_ENABLE DECKY_ENABLE STEERING_ENABLE \
                _ VIRT_ENABLE SAMBA_ENABLE \
                _ RAW_DISK _ <<< "$OUTPUT"

GPU_VAL=$(echo "$RAW_GPU" | awk '{print $1}')
DESKTOP_VAL=$(echo "$RAW_DESKTOP" | awk '{print $1}')
TARGET_DISK=$(echo "$RAW_DISK" | awk '{print $1}')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  yad --error --title="Champs manquants" --text="❌ Le nom d'utilisateur et le mot de passe sont obligatoires."
  exit 1
fi

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
  yad --error --title="Erreur de mot de passe" --text="❌ Les deux mots de passe ne correspondent pas."
  exit 1
fi

# =============================================================================
# 4. ⚠️ CONFIRMATION
# =============================================================================

if [ "$DRY_RUN" = true ]; then
  yad --info \
    --title="Confirmation Simulation" \
    --width=520 \
    --center \
    --text="<span foreground='blue' size='large'><b>ℹ️ SIMULATION D'INSTALLATION</b></span>\n\n<b>Disque Cible :</b> $TARGET_DISK\n<b>Utilisateur :</b> $USERNAME ($FULLNAME)\n<b>GPU :</b> $GPU_VAL\n<b>Bureau :</b> $DESKTOP_VAL\n<b>Decky Loader :</b> $DECKY_ENABLE\n<b>Virt-Manager :</b> $VIRT_ENABLE\n\n<i>Cliquez sur Valider pour lancer la simulation des étapes et prévisualiser vars.nix !</i>" \
    --button="Valider la simulation:0"
else
  yad --warning \
    --title="Confirmation de formatage" \
    --width=520 \
    --center \
    --text="<span foreground='red' size='large'><b>⚠️ ATTENTION : DESTRUCTION DES DONNÉES</b></span>\n\nLe disque <b>$TARGET_DISK</b> va être intégralement effacé et partitionné pour installer ChomiamOS.\n\n<b>Utilisateur :</b> $USERNAME\n<b>Carte Graphique :</b> $GPU_VAL\n<b>Bureau :</b> $DESKTOP_VAL\n\nÊtes-vous absolument certain de vouloir continuer ?" \
    --button="Non, Annuler:1" \
    --button="Oui, Formater et Installer:0"

  if [ $? -ne 0 ]; then
    exit 0
  fi
fi

# =============================================================================
# 5. 🚀 EXÉCUTION OU SIMULATION
# =============================================================================

GENERATED_VARS=$(cat << EOC
{
  # Nom d'hôte et paramètres régionaux
  hostName = "$HOSTNAME";
  timeZone = "Europe/Paris";
  defaultLocale = "fr_FR.UTF-8";
  stateVersion = "26.05";

  # Profil utilisateur principal
  user = {
    username = "$USERNAME";
    fullName = "$FULLNAME";
    homeDirectory = "/home/$USERNAME";
    shell = "fish";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
    ];
  };

  # Virtualisation (Virt-Manager, KVM/QEMU, pilotes VirtIO)
  virtualisation = {
    enable = $([ "$VIRT_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  };

  # Navigateur web par défaut
  browser = "chrome";
  firewall = false;

  # Environnement graphique & Pilote GPU
  desktopEnv = "$DESKTOP_VAL";
  gpuDriver = "$GPU_VAL";

  # Suite Gaming & Divertissement
  gaming = {
    enable = $([ "$GAMING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    deckyLoader = $([ "$DECKY_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    geforceNow = true;
    mountGamesDisk = false;
  };

  # Volants SimRacing & Création
  steeringWheelSupport = $([ "$STEERING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  davinciResolve = "none";
  blender = true;
  godot = true;

  # Suite IA Locale
  aiSuite = {
    enable = false;
    rocmOverrideGfx = "12.0.1";
    keepAlive = "0s";
    openWebUiPort = 8080;
    searxPort = 8888;
  };
}
EOC
)

if [ "$DRY_RUN" = true ]; then
  (
    echo "10"; echo "# [Simulation] Démontage des anciens montages..." ; sleep 1
    echo "25"; echo "# [Simulation] Partitionnement GPT de $TARGET_DISK..." ; sleep 1
    echo "40"; echo "# [Simulation] Formatage ESP (FAT32) et ROOT (Ext4)..." ; sleep 1
    echo "55"; echo "# [Simulation] Détection du matériel réel (nixos-generate-config)..." ; sleep 1
    echo "70"; echo "# [Simulation] Téléchargement du framework ChomiamOS..." ; sleep 1
    echo "85"; echo "# [Simulation] Génération personnalisée de vars.nix..." ; sleep 1
    echo "95"; echo "# [Simulation] Compilation NixOS & installation du bootloader..." ; sleep 1
    echo "100"; echo "# [Simulation] Installation terminée avec succès !" ; sleep 0.5
  ) | yad --progress \
          --title="[Simulation] Déroulement de l'installation..." \
          --text="Initialisation de la simulation..." \
          --percentage=0 \
          --auto-close \
          --width=550 \
          --center

  echo "$GENERATED_VARS" | yad --text-info \
    --title="[Simulation] Prévisualisation du vars.nix généré" \
    --width=650 --height=500 \
    --center \
    --button="Terminer la simulation!gtk-ok:0"

  yad --info \
    --title="Simulation réussie !" \
    --width=450 \
    --center \
    --text="<b>🎉 La simulation s'est terminée avec succès !</b>\n\nLe script a correctement traité tous vos choix et généré le fichier de configuration sans modifier votre machine physique." \
    --button="Super !:0"
  exit 0
fi

# Mode Réel
(
  echo "10"; echo "# Démontage des anciens montages..."
  umount -R /mnt 2>/dev/null || true
  swapoff -a 2>/dev/null || true

  echo "20"; echo "# Création de la table de partitionnement GPT sur $TARGET_DISK..."
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

  echo "35"; echo "# Formatage des partitions (BOOT en FAT32, ROOT en Ext4)..."
  mkfs.fat -F 32 -n BOOT "$BOOT_PART"
  mkfs.ext4 -F -L nixos "$ROOT_PART"

  echo "45"; echo "# Montage des partitions sous /mnt..."
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

  echo "85"; echo "# Compilation et installation du système NixOS (nixos-install)..."
  nixos-install --flake /mnt/etc/nixos#chomiamos --no-root-password

  echo "95"; echo "# Configuration du mot de passe utilisateur..."
  echo "$USERNAME:$PASSWORD" | chroot /mnt chpasswd

  echo "100"; echo "# Installation terminée avec succès !"
) | yad --progress \
        --title="Installation de ChomiamOS en cours..." \
        --text="Préparation de l'installation..." \
        --percentage=0 \
        --auto-close \
        --width=550 \
        --center

if [ $? -eq 0 ]; then
  yad --question \
      --title="Installation terminée !" \
      --width=450 \
      --center \
      --text="<b>Félicitations !</b>\nChomiamOS a été installé avec succès sur votre machine.\n\nSouhaitez-vous redémarrer l'ordinateur dès maintenant ?" \
      --button="Non, plus tard:1" \
      --button="Oui, Redémarrer:0"
  if [ $? -eq 0 ]; then
    reboot
  fi
fi
