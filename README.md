# 💿 ChomiamOS Installer & Générateur d'Image ISO

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS Version" />
  <img src="https://img.shields.io/badge/Live--CD-GNOME%20Edition-purple?style=for-the-badge&logo=gnome&logoColor=white" alt="Live CD GNOME" />
  <img src="https://img.shields.io/badge/Installer-Yad%20GUI-orange?style=for-the-badge" alt="Yad Installer" />
  <img src="https://img.shields.io/badge/Gaming-Ready-red?style=for-the-badge&logo=steam&logoColor=white" alt="Gaming Ready" />
</p>

Ce dépôt contient le code source permettant de compiler l'**image ISO Live d'installation officielle de ChomiamOS Gaming Edition**.

L'ISO démarre sur un environnement graphique Live complet sous **GNOME Shell** et lance un assistant d'installation interactif propulsé par **Yad**.

---

## 🌟 Fonctionnalités de l'Assistant d'Installation

1. **Auto-Détection Matérielle** :
   - Détection automatique de la carte graphique active (`AMD Radeon`, `NVIDIA`, `Intel`) via `lspci`.
   - Détection automatique des disques durs et SSDs disponibles pour l'installation (en excluant le média Live USB actuel).
2. **Personnalisation Interactive complète** :
   - Création du compte utilisateur (nom d'utilisateur, nom complet, mot de passe masqué).
   - Choix du bureau (`GNOME`, `COSMIC Desktop` ou les deux).
   - Activation à la carte : Decky Loader (Steam), GeForce NOW, Virt-Manager (KVM), Samba, SimRacing (Volants Fanatec, Thrustmaster, Logitech).
3. **Partitionnement & Déploiement Déclaratif** :
   - Partitionnement GPT automatique (ESP 1 Go + partition racine).
   - Génération du `hardware-configuration.nix` de la machine cible.
   - Écriture automatique du fichier `vars.nix` avec les réponses choisies.
   - Installation via `nixos-install --flake .#chomiamos`.

---

## 🚀 Comment compiler l'image ISO ?

### Prérequis
- Une machine sous Linux avec **Nix** installé et les fonctionnalités **Flakes** activées.

### Compilation de l'ISO
Pour compiler l'image ISO complète :

```bash
cd /home/chomiam/Projects/chomiamos-installer
nix build .#iso
```

Une fois la compilation terminée, l'image ISO bootable se trouvera dans :
```text
result/iso/nixos-*.iso
```

### Flasher sur une clé USB
Vous pouvez flasher le fichier `.iso` obtenu sur une clé USB avec **Ventoy**, **BalenaEtcher** ou en ligne de commande :
```bash
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Remplacez `/dev/sdX` par le périphérique de votre clé USB)*

---

## 📂 Structure du Projet

```text
chomiamos-installer/
├── flake.nix                  # Flake définissant la cible de compilation de l'image ISO
├── flake.lock
├── README.md                  # Documentation officielle
├── iso/
│   └── configuration.nix      # Module NixOS du système Live-CD (GNOME, autologin, paquets)
└── scripts/
    ├── chomiamos-installer.sh # Script principal d'installation (Yad + partitionnement + nixos-install)
    └── chomiamos-installer.desktop # Raccourci pour le bureau et le dock GNOME
```

---

<p align="center">
  <i>Projet associé à <a href="https://github.com/Chomiam/nix_config_gaming">Chomiam/nix_config_gaming</a></i>
</p>
