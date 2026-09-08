#!/usr/bin/env bash
# =============================================================================
# ❄️ CHOMIAMOS INSTALLER — Assistant Graphique d'Installation (Yad)
# =============================================================================

set -e

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# =============================================================================
# 1. 🔍 AUTO-DÉTECTION DU MATÉRIEL (GPU & DISQUES)
# =============================================================================

# A. Détection GPU
DETECTED_GPU="amd"
if lspci | grep -i "vga\|3d" | grep -qi "nvidia"; then
  DETECTED_GPU="nvidia"
elif lspci | grep -i "vga\|3d" | grep -qi "intel"; then
  DETECTED_GPU="intel"
elif lspci | grep -i "vga\|3d" | grep -qi "amd\|ati"; then
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

# B. Détection des disques cibles (exclusion des loops, zram, cdrom et de la clé USB d'installation)
INSTALLER_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed -E 's/[0-9]+$//' | sed -E 's/p[0-9]+$//' || true)

DISKS=()
while read -r name size model; do
  dev="/dev/$name"
  # Ignore le support Live actuel
  if [ -n "$INSTALLER_DEV" ] && [ "$dev" = "$INSTALLER_DEV" ]; then
    continue
  fi
  DISKS+=("$dev ($size - $model)")
done < <(lsblk -dpno NAME,SIZE,MODEL | grep -v "loop\|zram\|sr[0-9]")

if [ ${#DISKS[@]} -eq 0 ]; then
  yad --error \
      --title="Erreur de détection" \
      --width=400 \
      --text="❌ Aucun disque de stockage détecté pour l'installation." \
      --button="Quitter:1"
  exit 1
fi

DISKS_CHOICES=$(IFS="!"; echo "${DISKS[*]}")

# =============================================================================
# 2. 📋 INTERFACE GRAPHIQUE YAD : FORMULAIRE D'INSTALLATION
# =============================================================================

OUTPUT=$(yad --form \
  --title="Assistant d'installation ChomiamOS Gaming Edition" \
  --window-icon="system-software-install" \
  --width=680 --height=580 \
  --center \
  --text="<b>Bienvenue dans l'installateur officiel de ChomiamOS !</b>\nConfigurez votre système selon votre matériel et vos préférences." \
  --separator="|" \
  --field="<b>👤 UTILISATEUR & SYSTÈME</b>:LBL" "" \
  --field="Nom d'utilisateur :" "chomiam" \
  --field="Nom complet :" "Axel Valens" \
  --field="Mot de passe du compte :H" "" \
  --field="Confirmation du mot de passe :H" "" \
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

# Nettoyage des valeurs
GPU_VAL=$(echo "$RAW_GPU" | awk '{print $1}')
DESKTOP_VAL=$(echo "$RAW_DESKTOP" | awk '{print $1}')
TARGET_DISK=$(echo "$RAW_DISK" | awk '{print $1}')

# Vérifications des champs
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  yad --error --title="Champs manquants" --text="❌ Le nom d'utilisateur et le mot de passe sont obligatoires."
  exit 1
fi

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
  yad --error --title="Erreur de mot de passe" --text="❌ Les deux mots de passe ne correspondent pas."
  exit 1
fi

if [ -z "$TARGET_DISK" ] || [ ! -b "$TARGET_DISK" ]; then
  yad --error --title="Disque invalide" --text="❌ Le disque sélectionné ($TARGET_DISK) est invalide."
  exit 1
fi

# =============================================================================
# 4. ⚠️ CONFIRMATION DE SÉCURITÉ
# =============================================================================

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

# =============================================================================
# 5. 🚀 EXÉCUTION DU PARTITIONNEMENT & INSTALLATION NIXOS
# =============================================================================

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

  # Détection du schéma de nommage des partitions (/dev/nvme0n1p1 vs /dev/sda1)
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

  # Remplacement du hardware-configuration.nix de la machine cible
  if [ -f "/mnt/etc/nixos/hardware-configuration.nix" ]; then
    cp -f /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/desktop/hardware-configuration.nix
  fi

  # Configuration d'un mount.nix neutre sans disques secondaires physiques pré-montés
  cat << 'EOC' > /mnt/etc/nixos/hosts/desktop/mount.nix
{ config, ... }:
{
  # Déclarez ici vos disques additionnels (ex: /mnt/Games)
}
EOC

  echo "75"; echo "# Génération personnalisée de vars.nix..."
  cat << EOC > /mnt/etc/nixos/vars.nix
{
  hostName = "$HOSTNAME";
  timeZone = "Europe/Paris";
  defaultLocale = "fr_FR.UTF-8";
  stateVersion = "26.05";

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

  virtualisation = {
    enable = $([ "$VIRT_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  };

  browser = "chrome";
  firewall = false;
  desktopEnv = "$DESKTOP_VAL";
  gpuDriver = "$GPU_VAL";

  gaming = {
    enable = $([ "$GAMING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    deckyLoader = $([ "$DECKY_ENABLE" = "TRUE" ] && echo "true" || echo "false");
    geforceNow = true;
    mountGamesDisk = false;
  };

  steeringWheelSupport = $([ "$STEERING_ENABLE" = "TRUE" ] && echo "true" || echo "false");
  davinciResolve = "none";
  blender = true;
  godot = true;

  aiSuite = {
    enable = false;
    rocmOverrideGfx = "12.0.1";
    keepAlive = "0s";
    openWebUiPort = 8080;
    searxPort = 8888;
  };
}
EOC

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
