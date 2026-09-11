# 💿 ChomiamOS Installer & Générateur d'Image ISO (v1.1.0 - Rust & Tauri v2)

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS Version" />
  <img src="https://img.shields.io/badge/Rust-2021%20Edition-DEA584?style=for-the-badge&logo=rust&logoColor=black" alt="Rust Edition" />
  <img src="https://img.shields.io/badge/GUI-Tauri%20v2-24C8D8?style=for-the-badge&logo=tauri&logoColor=white" alt="Tauri v2" />
  <img src="https://img.shields.io/badge/Theme-Catppuccin%20Mocha-CBA6F7?style=for-the-badge&logo=catppuccin&logoColor=white" alt="Catppuccin Mocha" />
  <img src="https://img.shields.io/badge/Gaming-Ready-ED8796?style=for-the-badge&logo=steam&logoColor=white" alt="Gaming Ready" />
  <img src="https://img.shields.io/badge/License-GPL--3.0--or--later-8AADF4?style=for-the-badge" alt="GPL-3.0 License" />
</p>

Ce dépôt héberge le code source officiel de l'**installateur système de ChomiamOS Gaming Edition** ainsi que la recette Flake pour générer l'**image ISO Live d'installation bootable**.

Depuis la **version 1.1.0**, l'installateur a été **entièrement réécrit en Rust natif avec Tauri v2**, remplaçant l'ancienne pile Python/Qt6 pour offrir une vitesse d'exécution fulgurante, une empreinte mémoire minimale et une cohérence visuelle parfaite avec le **Dashboard ChomiamOS** grâce au thème **Catppuccin Mocha**.

---

## ⚡ La Révolution Rust + Tauri v2 (v1.0.0)

| Fonctionnalité | Ancienne version (v0.x) | Nouvelle version (v1.1.0) |
| :--- | :--- | :--- |
| **Backend & Logique Système** | Python 3.11 + Processus IPC lourd | **Rust natif** multithreadé, sans runtime |
| **Interface Graphique** | PySide6 / Qt6 QML | **Tauri v2** + Webview moderne ultra-fluide |
| **Création du Fichier Swap** | `dd` synchrone (long et bloquant) | **`posix_fallocate` Rust** instantané (~0.4 ms) |
| **Consommation Mémoire RAM** | ~350 - 500 Mo | **~45 - 75 Mo** |
| **Thème & Design** | Qt Quick personnalisé | **Catppuccin Mocha** officiel (identique au Dashboard) |
| **Compatibilité ISO Existantes** | Manuelle | **Pont de mise à jour automatique** transparent |

---

## 🌟 Fonctionnalités & Points Forts

### 1. 🎨 Interface Moderne Catppuccin Mocha
- **Design soigné & moderne** : Intégration complète de la palette *Catppuccin Mocha* (accents Mauve, Lavender, Peach, Teal et fond Crust/Base).
- **Composants fluides** : Menus déroulants personnalisés, indicateur d'étapes interactif, modales d'avertissement stylisées et animations CSS réactives.
- **Affichage fiable des versions des DEs** : Détection dynamique et rigoureuse des versions réelles des environnements de bureau (sans valeurs codées en dur).

### 2. ⚡ Performance & Swap Ultra-Rapide
- **Allocation POSIX en Rust** : Utilisation de l'appel système `posix_fallocate` pour créer des fichiers Swap de toute taille (1 Go à 16 Go+) en une fraction de milliseconde, éliminant les lenteurs d'installation.
- **Mode Sans Swap** : Possibilité de désactiver totalement le swap pour optimiser l'espace disque sur les configurations compactes ou machines virtuelles (60-80 Go).

### 3. 🖥️ Environnements de Bureau & Clavier Multi-DE
- **Bureaux pris en charge** :
  - **GNOME Shell**
  - **KDE Plasma 6**
  - **COSMIC Desktop**
  - **Cinnamon** (avec intégration spécifique et exclusion de `gnome-terminal`)
- **Synchronisation du clavier universelle** : La disposition de clavier choisie pendant l'installation (AZERTY, QWERTY, etc.) est appliquée immédiatement et enregistrée pour tous les bureaux (`xkb`, GSettings GNOME/Cinnamon, KDE `kxkbrc`, COSMIC).
- **Fonds d'écran ChomiamOS universels** : Déploiement automatique des wallpapers officiels, détectés et actifs pour tous les environnements (y compris Cinnamon).

### 4. 🎮 Gaming & Logiciels à la Carte
- **Gaming Suites** : Steam, Lutris, Heroic Games Launcher, Decky Loader, émulateurs rétro.
- **Options modulaires** :
  - Toggles optionnels pour **Sunshine** (streaming de jeux) et **Sober** (Roblox Flatpak).
  - Profils **Nvidia GeForce NOW** et **SimRacing** (décochés par défaut, activables d'un clic).
- **Navigateurs Web** : Choix libre (Brave, Firefox, Zen Browser, Google Chrome, etc.) sans présélection imposée.

### 5. 🔒 Partitionnement & Sécurité
- **Auto-détection intelligente** : Prise en charge des disques NVMe, SSD, SATA et virtuels avec filtrage strict pour protéger la clé USB d'installation.
- **Chiffrement intégral LUKS2** : Sécurisation de la partition racine avec confirmation du mot de passe.
- **Déploiement NixOS déclaratif** : Génération des configurations `vars.nix`, `mount.nix` et `hardware-configuration.nix`, puis exécution suivie de `nixos-install`.

### 6. 🔄 Système de Mise à Jour Automatique (Hot-Update)
- **Détection des nouvelles versions** : L'installateur vérifie automatiquement sur GitHub si une nouvelle version est disponible dès le démarrage de la session Live.
- **Compatibilité ascendante** : Les anciennes clés USB Live (ISO v0.x) téléchargent et exécutent automatiquement le nouveau binaire Rust sans nécessiter de réécrire l'image ISO.

---

## 🛠️ Architecture du Projet

```text
chomiamos-installer/
├── src-tauri/                 # Backend Rust (Tauri v2)
│   ├── src/
│   │   └── main.rs            # Logique système, commandes Tauri, API headless CLI
│   ├── Cargo.toml             # Dépendances Rust (tauri, nix, sysinfo, reqwest, serde)
│   └── tauri.conf.json        # Configuration de la fenêtre et sécurité Tauri
├── src/                       # Frontend Web Moderne
│   ├── index.html             # Structure HTML5 sous Catppuccin Mocha
│   ├── js/
│   │   └── app.js             # Logique d'interface, navigation et appels Tauri
│   └── omnis/                 # Pont de compatibilité pour les anciennes ISOs Python
├── data/
│   └── bin/
│       └── chomiamos-installer # Binaire Rust autonome précompilé
├── flake.nix                  # Déclaration Nix Flake (paquets & image ISO)
├── package.nix                # Dérivation Nix de compilation du binaire
└── .github/workflows/         # Intégration continue (CI/CD) et publication des releases
```

---

## 🚀 Compilation & Utilisation

### Prérequis
- Un système Linux avec [Nix](https://nixos.org/download.html) activé avec les Flakes :
  ```bash
  mkdir -p ~/.config/nix
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ```

### 1. Compiler et tester l'installateur localement
```bash
# Via Nix Flakes
nix build .#omnis
./result/bin/omnis --help
./result/bin/omnis

# Ou directement avec Cargo (développement Rust)
cd src-tauri
cargo build --release
./target/release/chomiamos-installer
```

### 2. Générer l'image ISO Live bootable
```bash
nix build .#iso
```
L'image ISO bootable sera générée dans `result/iso/nixos-*.iso`.

### 3. Flasher sur clé USB
```bash
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Remplacez `/dev/sdX` par le nœud de périphérique de votre clé USB, ex: `/dev/sdb`)*

---

## ⚖️ Licence & Crédits

Ce projet est distribué sous les termes de la licence libre **GNU General Public License v3.0 or later ([GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.fr.html))**.  
Le texte intégral est disponible dans le fichier [LICENSE](LICENSE).

### 💖 Remerciements & Attribution Open Source

* **Projet d'origine & architecture initiale** : [Omnis Installer](https://github.com/N3oTraX/Omnis) créé par **[N3oTraX](https://github.com/N3oTraX)** et l'équipe **GLF Team**.
  *Base conceptuelle du système de jobs modulaire et détection initiale des disques.*
* **ChomiamOS Installer (v1.1.0+)** : Réécrit, repensé et développé par **Chomiam** pour **ChomiamOS Gaming Edition**.
  *Réécriture complète en Rust natif + Tauri v2, allocation instantanée de swap POSIX, support multi-DE étendu (Cinnamon, GNOME, Plasma 6, COSMIC), synchronisation du clavier cross-desktop, refonte UI Catppuccin Mocha, intégration des suites de jeux et écosystème déclaratif NixOS.*

---

<p align="center">
  <i>Projet officiel associé à <a href="https://github.com/Chomiam/nix_config_gaming">Chomiam/nix_config_gaming</a></i>
</p>
