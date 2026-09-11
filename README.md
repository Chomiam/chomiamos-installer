# 💿 ChomiamOS Installer & Générateur d'Image ISO

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS Version" />
  <img src="https://img.shields.io/badge/GUI-Qt6%20%2F%20QML-41CD52?style=for-the-badge&logo=qt&logoColor=white" alt="Qt6 QML" />
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.11+" />
  <img src="https://img.shields.io/badge/License-GPL--3.0--or--later-blue?style=for-the-badge" alt="GPL-3.0 License" />
  <img src="https://img.shields.io/badge/Gaming-Ready-red?style=for-the-badge&logo=steam&logoColor=white" alt="Gaming Ready" />
</p>

Ce dépôt contient le code source de l'**installateur officiel de ChomiamOS Gaming Edition** ainsi que les configurations permettant de compiler l'**image ISO Live d'installation bootable**.

L'application est développée en **Python 3 / PySide6 (Qt6) / QML**, avec une séparation stricte entre l'interface utilisateur et le moteur privilégié d'installation via un bus IPC sécurisé.

---

## 🌟 Fonctionnalités de l'Installateur ChomiamOS

1. **Expérience Graphique Moderne & Thème Catppuccin** :
   - Interface réactive conçue en Qt6/QML avec le thème officiel **Catppuccin Mocha**.
   - Détection en direct de la connexion internet, résolution DNS et test de débit réseau multi-serveurs intégré.
   - Système de mise à jour à chaud (*hot-update*) permettant à l'installateur Live de se mettre à jour en direct depuis GitHub sans réécrire l'ISO.

2. **Personnalisation Complète à la Carte** :
   - Sélection du profil utilisateur, mot de passe, auto-login et privilèges administrateur.
   - Choix de l'environnement de bureau (`GNOME Shell`, `KDE Plasma`, `COSMIC Desktop`).
   - Sélection des suites logicielles : Steam, Lutris, Heroic Games Launcher, Decky Loader, émulateurs de jeux rétro, logiciels de création 3D/vidéo (Blender, DaVinci Resolve, Godot), et pilotes de volants SimRacing (Fanatec, Thrustmaster, Logitech).
   - Intégration native des fonds d'écran officiels ChomiamOS déployés à plat pour tous les environnements de bureau.

3. **Partitionnement Avancé & Gestion du Swap** :
   - Auto-détection des disques NVMe, SSD et SATA (avec exclusion automatique du média d'installation Live).
   - **Gestion granulaire du fichier d'échange (Swap)** : option de désactivation complète (« Sans swap », idéal pour économiser l'espace disque sur machines virtuelles de 60 à 80 Go) ou réglage personnalisé (1 Go, 2 Go, 4 Go, 8 Go, 16 Go ou Automatique).
   - Support du chiffrement intégral du disque racine via **LUKS2**.
   - Prévisualisation dynamique des partitions avant application.

4. **Déploiement Déclaratif NixOS** :
   - Génération automatique de `hardware-configuration.nix` et de `mount.nix` (support UEFI et BIOS).
   - Injection du fichier personnalisé `vars.nix` adapté aux choix de l'utilisateur.
   - Déploiement direct via `nixos-install` et conservation d'un état Git propre, intègre et signé.

---

## 🚀 Compilation & Utilisation

### Tester l'installateur localement (sans ISO)
```bash
nix build .#omnis
./result/bin/omnis
```

### Compiler l'image ISO complète
```bash
nix build .#iso
```
L'image ISO bootable sera générée dans `result/iso/nixos-*.iso`.

### Flasher sur clé USB
```bash
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Remplacez `/dev/sdX` par le périphérique de votre clé USB)*

---

## ⚖️ Licence & Crédits

Ce projet est distribué sous les termes de la licence libre **GNU General Public License v3.0 or later ([GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.fr.html))**.  
Le texte intégral de la licence est disponible dans le fichier [LICENSE](LICENSE).

### 💖 Remerciements & Attribution Open Source

* **Projet d'origine & architecture de base** : [Omnis Installer](https://github.com/N3oTraX/Omnis) créé par **[N3oTraX](https://github.com/N3oTraX)** et l'équipe **GLF Team**.
  *Architecture IPC, système de jobs modulaire, détection de disques et base d'interface QML originale.*
* **ChomiamOS Installer** : Développé et adapté par **Chomiam** pour la distribution **ChomiamOS Gaming Edition**.
  *Intégration du framework modulaire NixOS, gestion et dimensionnement du swap / mode sans swap, intégration des suites de jeux et émulateurs, testeur de débit réseau, synchronisation des fonds d'écran, auto-update intégré et thématisation Catppuccin.*

---

<p align="center">
  <i>Projet officiel associé à <a href="https://github.com/Chomiam/nix_config_gaming">Chomiam/nix_config_gaming</a></i>
</p>
