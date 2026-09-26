# 💿 ChomiamOS Installer & Générateur d'Image ISO (v1.2.x - Rust & Tauri v2)

<p align="center">
  <img src="https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS Version" />
  <img src="https://img.shields.io/badge/Rust-2021%20Edition-DEA584?style=for-the-badge&logo=rust&logoColor=black" alt="Rust Edition" />
  <img src="https://img.shields.io/badge/GUI-Tauri%20v2-24C8D8?style=for-the-badge&logo=tauri&logoColor=white" alt="Tauri v2" />
  <img src="https://img.shields.io/badge/Theme-Catppuccin%20Mocha-CBA6F7?style=for-the-badge&logo=catppuccin&logoColor=white" alt="Catppuccin Mocha" />
  <img src="https://img.shields.io/badge/Gaming-Ready-ED8796?style=for-the-badge&logo=steam&logoColor=white" alt="Gaming Ready" />
  <img src="https://img.shields.io/badge/License-GPL--3.0--or--later-8AADF4?style=for-the-badge" alt="GPL-3.0 License" />
</p>

Ce dépôt héberge le code source officiel de l'**installateur système de ChomiamOS Gaming Edition** ainsi que la recette Flake pour générer l'**image ISO Live d'installation bootable**.

L'installateur est propulsé par une architecture **100% Rust natif et Tauri v2**, offrant une vitesse d'exécution fulgurante, une empreinte mémoire minimale (~50 Mo) et une cohérence visuelle parfaite avec le **Dashboard ChomiamOS** grâce au thème officiel **Catppuccin Mocha**.

---

## ⚡ Performance & Avantages Techniques

| Caractéristique | Spécification ChomiamOS Installer (v1.2.x) |
| :--- | :--- |
| **Moteur Système** | **Rust natif** multithreadé, sans runtime externe |
| **Interface Graphique** | **Tauri v2** + Webview moderne ultra-fluide & réactive |
| **Allocation du Fichier Swap** | **`posix_fallocate` Rust** instantané (~0.4 ms pour 16 Go) |
| **Consommation Mémoire RAM** | **~45 - 65 Mo** en cours d'exécution |
| **Thème & Design** | **Catppuccin Mocha** officiel (harmonie totale avec l'écosystème ChomiamOS) |
| **Déploiement NixOS** | Génération déclarative de `vars.nix`, `hardware-configuration.nix` et `disks.nix` |
| **Mise à Jour à Chaud** | Détection automatique des releases GitHub (Canaux **Stable** et **Testing**) |

---

## 🌟 Fonctionnalités Complètes

### 1. 🎨 Interface Moderne Catppuccin Mocha
- **Design soigné & accessible** : Palette officielle *Catppuccin Mocha* (accents Mauve, Lavender, Peach, Teal et fond Crust/Base).
- **Parcours utilisateur guidé** : Indicateur d'étapes interactif, résumés dynamiques, alertes contextuelles et animations fluides.
- **Sélecteur de version dynamique** : Prise en charge des canaux de mise à jour **Stable** et **Testing** avec prévisualisation des commits et versions disponibles.

### 2. 🖥️ Environnements de Bureau & Clavier Multi-DE
- **Bureaux pris en charge** :
  - **GNOME Shell** (extensions Blur-my-Shell, Dash-to-Dock préconfigurées)
  - **KDE Plasma 6**
  - **COSMIC Desktop** (versions récentes avec applets communautaires)
  - **Cinnamon** (intégré et optimisé)
- **Synchronisation du clavier universelle** : La disposition de clavier choisie pendant l'installation (AZERTY, QWERTY, etc.) est appliquée immédiatement en session live et transmise à tous les environnements de bureau (`xkb`, GSettings GNOME/Cinnamon, KDE `kxkbrc`, COSMIC).
- **Fonds d'écran officiels ChomiamOS** : Intégration et sélection automatique des fonds d'écran officiels selon l'environnement de bureau choisi.

### 3. 💾 Stockage, Systèmes de Fichiers & Swap
- **Auto-détection matérielle des disques** : Prise en charge des disques NVMe, SSD, SATA et disques virtuels avec protection stricte empêchant l'écrasement accidentel du média d'installation USB live.
- **Systèmes de fichiers modernes** :
  - **Btrfs** : Architecture optimisée avec sous-volumes déclaratifs (`@`, `@home`, `@nix`, `@snapshots`) et compression zstd.
  - **Ext4** : Robustesse éprouvée pour un partitionnement classique.
  - **ZFS** : Support des pools ZFS pour les configurations avancées.
  - **Chiffrement LUKS2** : Protection cryptographique intégrale de la partition racine avec confirmation du mot de passe.
- **Gestion du Swap haute performance** :
  - Création instantanée via `posix_fallocate` (aucun blocage `dd`).
  - Mode sans swap disponible pour les environnements virtualisés ou les disques compacts (60-80 Go).

### 4. 🎮 Gaming, Émulation & Outils Multimédia
- **Gaming Suites** : Steam avec intégration Decky Loader, Lutris, Heroic Games Launcher, GameScope session.
- **Émulateurs Rétro & Consoles** :
  - **xemu (Xbox Originale)** : Intégré avec détection automatique du PATH par ES-DE.
  - **DuckStation** (PlayStation 1)
  - **PCSX2** (PlayStation 2)
  - **RPCS3** (PlayStation 3)
  - **Ryujinx** (Nintendo Switch)
  - **Cemu** (Wii U)
- **Options Streaming & Gaming Avancées** : Toggles pour **Sunshine** (serveur de streaming) et **Sober** (Roblox Flatpak), profils **GeForce NOW** et **SimRacing**.

### 5. 💻 Environnements de Développement & IDEs (Choix Multiple)
Sélection granulaire et combinée des environnements de développement dès l'installation :
- ⚡ **Zed Editor** : Éditeur de code nouvelle génération ultra-rapide écrit en Rust.
- 🪐 **Google Antigravity** : Environnement de développement et assistant agentique officiel.
- 💻 **Visual Studio Code** : L'éditeur polyvalent et extensible de Microsoft.

### 6. 🧠 Intelligence Artificielle Locale (Suite IA)
- Intégration modulaire de la **Suite IA Locale** comprenant :
  - **Ollama** (moteur d'inférence LLM local)
  - **Open-WebUI** (interface web conversationnelle intuitive)
  - **Agent IA Hermes**
- **Accélération matérielle conditionnelle** : Détection et configuration automatique selon le GPU détecté (CUDA pour NVIDIA, ROCm pour AMD, ou mode CPU standard).

### 7. 🌐 Réseau, Miroirs & Diagnostic Intégré
- **Sélection des Miroirs & Datacenters** : Choix des meilleurs miroirs de distribution mondiaux pour accélérer le téléchargement des paquets NixOS.
- **Outil de Diagnostic & Pastebin sécurisé** : En cas de difficulté, génération d'un rapport de diagnostic complet avec possibilité de téléversement chiffré vers un service pastebin pour une assistance rapide.

---

## 🛠️ Architecture du Dépôt

```text
chomiamos-installer/
├── src-tauri/                 # Backend natif Rust (Tauri v2)
│   ├── src/
│   │   ├── main.rs            # Point d'entrée, commandes Tauri, API headless CLI
│   │   ├── config.rs          # Modèle de sélection & génération de vars.nix
│   │   ├── install.rs         # Moteur de partitionnement, formatage et déploiement NixOS
│   │   ├── system.rs          # Sondage matériel (CPU, GPU, RAM, DEs, claviers)
│   │   ├── network_mirror.rs  # Gestion des miroirs réseau mondiaux
│   │   ├── swap.rs            # Création instantanée du swap (posix_fallocate)
│   │   ├── updater.rs         # Détection des mises à jour (Stable & Testing)
│   │   └── pastebin.rs        # Envoi sécurisé des journaux de diagnostic
│   ├── Cargo.toml             # Métadonnées et dépendances Rust
│   └── tauri.conf.json        # Configuration Tauri v2 (fenêtre, sécurité, webview)
├── frontend/                  # Interface Utilisateur Web (Catppuccin Mocha)
│   ├── index.html             # Structure HTML5 moderne et accessible
│   ├── css/
│   │   └── style.css          # Feuilles de style Catppuccin Mocha, composants et responsive
│   └── js/
│       └── app.js             # Logique d'interface et communication avec Tauri
├── config/                    # Thèmes et identité visuelle
│   └── themes/                # Wallpapers officiels et logos vectoriels/PNG
├── iso/                       # Configuration de l'image ISO bootable
│   └── configuration.nix      # Recette du média Live GNOME avec lancement automatique
├── flake.nix                  # Déclaration Nix Flake officielle
├── package.nix                # Dérivation Nix de compilation du binaire
└── .github/workflows/         # Intégration continue (CI/CD) et publication automatique des releases
```

---

## 🚀 Compilation & Utilisation

### Prérequis
- Un système Linux avec [Nix](https://nixos.org/download.html) configuré avec les Flakes :
  ```bash
  mkdir -p ~/.config/nix
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ```

### 1. Compiler et tester l'installateur localement
```bash
# Compilation et vérification des tests unitaires Rust
cargo test --manifest-path src-tauri/Cargo.toml

# Compilation du paquet complet via Nix Flakes
nix build .#omnis
./result/bin/chomiamos-installer --help
./result/bin/chomiamos-installer
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
*(Remplacez `/dev/sdX` par le périphérique correspondant à votre clé USB, par exemple `/dev/sdb`)*

---

## ⚖️ Licence & Crédits

Ce projet est distribué sous les termes de la licence libre **GNU General Public License v3.0 or later ([GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.fr.html))**.  
Le texte intégral est disponible dans le fichier [LICENSE](LICENSE).

### 💖 Remerciements & Attribution Open Source

* **Projet d'origine & architecture initiale** : [Omnis Installer](https://github.com/N3oTraX/Omnis) créé par **[N3oTraX](https://github.com/N3oTraX)** et l'équipe **GLF Team**.  
  *Base conceptuelle du système de jobs modulaire et détection initiale des disques.*
* **ChomiamOS Installer (v1.2.x)** : Réécrit, modernisé et maintenu par **Chomiam** pour **ChomiamOS Gaming Edition**.  
  *Réécriture complète en Rust natif + Tauri v2, suppression du code historique Python/QML, swap instantané POSIX, support multi-DE étendu (GNOME, Plasma 6, COSMIC, Cinnamon), synchronisation clavier multi-environnements, sélection multiple d'IDEs, intégration xemu et suites de jeux, Suite IA locale, système de fichiers Btrfs/ZFS et déploiement déclaratif NixOS.*

---

<p align="center">
  <i>Projet officiel associé à <a href="https://github.com/Chomiam/nix_config_gaming">Chomiam/nix_config_gaming</a></i>
</p>
