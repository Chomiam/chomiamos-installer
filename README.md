# 💿 ChomiamOS Installer & Générateur d'Image ISO

<p align="center">
  <img src="https://img.shields.io/badge/ChomiamOS%20Installer-v1.2.31-CBA6F7?style=for-the-badge&logo=rocket&logoColor=white" alt="Version 1.2.31" />
  <img src="https://img.shields.io/badge/NixOS-26.05-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS Version" />
  <img src="https://img.shields.io/badge/Rust-2021%20Edition-DEA584?style=for-the-badge&logo=rust&logoColor=black" alt="Rust Edition" />
  <img src="https://img.shields.io/badge/GUI-Tauri%20v2.3-24C8D8?style=for-the-badge&logo=tauri&logoColor=white" alt="Tauri v2" />
  <img src="https://img.shields.io/badge/Theme-Catppuccin%20Mocha-CBA6F7?style=for-the-badge&logo=catppuccin&logoColor=white" alt="Catppuccin Mocha" />
  <img src="https://img.shields.io/badge/Gaming-Ready-ED8796?style=for-the-badge&logo=steam&logoColor=white" alt="Gaming Ready" />
  <img src="https://img.shields.io/badge/License-GPL--3.0--or--later-8AADF4?style=for-the-badge" alt="GPL-3.0 License" />
</p>

Ce dépôt héberge le code source officiel de l'**installateur système de ChomiamOS Gaming Edition** ainsi que la recette déclarative Nix Flake pour générer l'**image ISO Live d'installation bootable**.

L'application est construite sur une architecture **100% Rust natif et Tauri v2**, offrant une exécution instantanée, une empreinte mémoire minimale (~45-65 Mo) et une cohérence visuelle parfaite avec l'écosystème **ChomiamOS** grâce au thème officiel **Catppuccin Mocha**.

> [!NOTE]
> **Évolution v1.2.31 :** L'ancien socle historique hérité d'Omnis (Python 3, PyQt6, QML) a été intégralement supprimé et purgé du dépôt. L'installateur repose désormais exclusivement sur du code Rust moderne multithreadé et une interface Webview Tauri v2 légère et autonome.

---

## ⚡ Performance & Fiche Technique

| Caractéristique | Spécification ChomiamOS Installer (v1.2.31) |
| :--- | :--- |
| **Moteur Backend** | **Rust natif** multithreadé (Tokio, Sysinfo, Nix fs), sans runtime externe |
| **Interface Graphique** | **Tauri v2.3** + Webview moderne fluide & réactive |
| **Consommation Mémoire** | **~45 à 65 Mo** de RAM en cours d'exécution |
| **Allocation Swap** | **`posix_fallocate` Rust** instantané (~0.4 ms pour 16 Go) |
| **Systèmes de Fichiers** | **Btrfs** (sous-volumes `@`, `@home`, `@nix`, `@swap` + zstd) ou **Ext4** |
| **Chiffrement** | **LUKS2** intégral de la partition racine |
| **Thème & Design** | **Catppuccin Mocha** officiel (harmonie totale avec le Dashboard ChomiamOS) |
| **Déploiement NixOS** | Génération déclarative de `vars.nix`, partitionnement `parted` et déploiement `nixos-install` |
| **Mise à Jour à Chaud** | Détection automatique des releases GitHub (Canaux **Stable** et **Testing**) avec restart `exec` |
| **Support de Diagnostic** | Export local des logs et téléversement sécurisé vers **Pastebin API** en cas d'erreur |

---

## 🌟 Fonctionnalités Détaillées (Parcours en 11 Étapes)

```
[1. Accueil/Hardware] ➔ [2. Clavier/Langue] ➔ [3. Bureau/DE] ➔ [4. Navigateurs/Mail]
         ➔ [5. Gamescope] ➔ [6. Gaming/Émulation] ➔ [7. Multimédia/Audio]
         ➔ [8. IDEs/Dev] ➔ [9. Réseau/Suite IA] ➔ [10. Disques/Swap] ➔ [11. Utilisateur]
                                 ➔ 🚀 Déploiement & Diagnostic
```

### 1. 🔍 Accueil & Vérification Matérielle Temps Réel
- Sondage matériel automatique :
  - **CPU** : Détection du nombre de cœurs physiques/logiques et de l'architecture (`x86_64`).
  - **RAM** : Calcul de la mémoire vive totale (seuil d'avertissement et optimal à 16 Go).
  - **GPU** : Identification automatique du constructeur (**AMD**, **NVIDIA**, **Intel**, ou **VM/Émulation**) avec adaptation conditionnelle des options ultérieures.
  - **Disque, EFI & Connectivité** : Détection de l'amorçage UEFI, niveau de batterie et test de connexion Internet.

### 2. ⌨️ Clavier, Langue & Synchronisation Multi-DE
- **Zone de test interactive** : Clavier dynamique avec indicateurs visuels d'état en direct pour le verrouillage majuscule (*Caps Lock*) et numérique (*Num Lock*).
- **Synchronisation universelle** : La disposition choisie (AZERTY français, QWERTY, etc.) est appliquée immédiatement en session Live et configurée de manière transparente pour l'ensemble des bureaux installés (`xkb`, GSettings GNOME/Cinnamon, KDE `kxkbrc`, COSMIC).

### 3. 🖥️ Environnements de Bureau & Fonds d'Écran
- Sélection du bureau principal parmi 4 environnements optimisés :
  - **GNOME Shell** : Épuré et moderne, enrichi des extensions *Dash-to-Dock*, *Blur-my-Shell*, *Vitals* et *ArcMenu*.
  - **KDE Plasma 6** : Personnalisation avancée, performance graphique et réactivité.
  - **Cinnamon** : Bureau classique, fluide et familier avec intégration fine des arrière-plans XDG.
  - **COSMIC Desktop** : L'environnement nouvelle génération en Rust développé par System76.
- Application automatique du fond d'écran officiel Catppuccin ChomiamOS adapté à l'environnement.

### 4. 🌐 Navigateurs Web & Clients Mail
- **Choix du navigateur favori** : Google Chrome, Mozilla Firefox, Brave, LibreWolf, Microsoft Edge, Vivaldi, Zen Browser.
- **Switch d'installation** : Choix entre paquet natif système (NixOS) et paquet conteneurisé **Flatpak**.
- **Client de messagerie** : Mozilla Thunderbird, Mailspring, ou aucun.

### 5. 🎮 Session Steam Gamescope (Mode Console Dédié)
- Option d'activation d'une session directe **Steam Big Picture sous Gamescope** (expérience type Steam Deck ou console de salon).
- **Sécurité GPU NVIDIA** : Détection matérielle et verrouillage assisté prévenant les instabilités connues de Gamescope sous Wayland avec les pilotes propriétaires NVIDIA.

### 6. 🕹️ Suites de Jeux & Émulation Rétro Complète
- **Outils Gaming** : Steam, Lutris, Heroic Games Launcher, Faugus Launcher, Decky Loader, Sober (Roblox), Sunshine (serveur de streaming de jeu), profils SimRacing.
- **Suite d'Émulation Étendue** :
  - **xemu** : Émulateur officiel Xbox originale avec injection automatique dans le PATH pour ES-DE.
  - **DuckStation** (PlayStation 1)
  - **PCSX2** (PlayStation 2)
  - **RPCS3** (PlayStation 3)
  - **Dolphin** (GameCube / Wii)
  - **PPSSPP** (PlayStation Portable)
  - **Eden**, **Azahar**, **melonDS** (Nintendo DS), **mGBA** (Game Boy Advance).

### 7. 🎬 Multimédia, Audio & Studio
- **Montage Vidéo** : DaVinci Resolve (Option *Aucun*, *Gratuit* ou *DaVinci Resolve Studio* avec pilote OpenCL/CUDA dédié), Kdenlive, OBS Studio.
- **Création 3D & Moteur** : Blender 3D, Godot Engine.
- **Station Audio** : Audacity, Ardour DAW.
- **Lecteurs Média** : Stremio, VLC Media Player, MPV.
- **Utilitaires Système** : GOverlay (MangoHud), Flatseal (permissions Flatpak), Pear Desktop.

### 8. 💻 Environnements de Développement (Sélection Multiple) & Slicers 3D
- Possibilité de cocher simultanément plusieurs IDEs dès l'installation :
  - ⚡ **Zed Editor** : Éditeur de code nouvelle génération ultra-rapide écrit en Rust.
  - 🪐 **Google Antigravity** : Environnement de développement et assistant agentique avancé.
  - 💻 **Visual Studio Code** : L'éditeur polyvalent et extensible de Microsoft.
- **Impression 3D & Découpeurs** : OrcaSlicer, PrusaSlicer, BambuStudio, Ultimaker Cura.

### 9. 🌐 Réseau, Miroirs & Suite IA Locale
- **Outils Réseau** : Tailscale (VPN maillé), LocalSend (partage local P2P), Motrix (gestionnaire de téléchargement accéléré).
- **Suite IA Locale (Souveraine & Hors-ligne)** :
  - **Ollama** : Moteur d'inférence de modèles de langage (LLM) en local.
  - **Open-WebUI** : Interface web conversationnelle moderne et intuitive.
  - **Hermes** : Agent IA local autonome.
  - Configuration automatique de l'accélération matérielle (CUDA sur GPU NVIDIA, ROCm sur GPU AMD, ou mode CPU standard).

### 10. 💾 Stockage, Systèmes de Fichiers & Swap POSIX
- **Protection anti-écrasement** : Détection et exclusion automatique du support USB Live source pour éviter tout effacement accidentel.
- **Systèmes de Fichiers** :
  - **Btrfs** : Création automatique de sous-volumes déclaratifs (`@`, `@home`, `@nix`, `@swap`) avec compression transparente au choix (`zstd:1`, `zstd:3`, `zstd:6`, ou aucune).
  - **Ext4** : Robustesse éprouvée pour partitionnement standard.
- **Swap Haute Performance** : Allocation instantanée par appel système `posix_fallocate` (aucun blocage `dd`), configurable via curseur dynamique (Désactivé, 4 Go, 8 Go, 16 Go, 32 Go).
- **Chiffrement de disque** : Option de chiffrement complet de la partition système via **LUKS2**.

### 11. 👤 Utilisateur, Sécurité & Déploiement
- **Norme POSIX stricte** : Validation en direct de l'identifiant utilisateur (minuscules, sans accents, sans espaces ni caractères spéciaux).
- **Indicateur de force du mot de passe** : Évaluation d'entropie en direct avec exigences de sécurité.
- **Hashage sécurisé SHA-512** : Génération du hash via `mkpasswd` (`initialHashedPassword`) directement injecté dans la configuration déclarative NixOS.
- **Déploiement en Direct** : Suivi en direct avec barre de progression, coloration des étapes et journalisation continue.
- **Téléversement Pastebin Intégré** : En cas d'erreur ou d'échec d'installation, génération d'un rapport d'incident complet téléversable de façon sécurisée vers l'API Pastebin pour un dépannage rapide avec la communauté.

---

## 🔄 Mise à Jour à Chaud Intégrée (Self-Updater)

L'installateur intègre un système de mise à jour autonome directement dans son en-tête :
- **Canaux de distribution** : Basculement facile entre le canal **Stable** et le canal **Testing**.
- **Comparaison sémantique SemVer** : Détection précise des montées de version comme des rétrogradations (*downgrades*).
- **Processus sécurisé** : Téléchargement du binaire natif depuis GitHub Releases, validation d'intégrité (en-tête Linux ELF `\x7fELF` et taille minimale), attribution des permissions `0755` et redémarrage en mémoire via l'appel `exec`.

---

## 🛠️ Architecture du Dépôt

```text
chomiamos-installer/
├── src-tauri/                 # Backend natif Rust (Tauri v2)
│   ├── src/
│   │   ├── main.rs            # Point d'entrée, gestionnaire IPC Tauri et dispatching des commandes
│   │   ├── config.rs          # Structure InstallerSelections et générateur du code déclaratif vars.nix
│   │   ├── install.rs         # Moteur d'installation (partitionnement parted/LUKS, formatage, chroot NixOS)
│   │   ├── system.rs          # Sondage matériel (CPU, GPU, RAM, DEs disponibles, dispositions claviers)
│   │   ├── swap.rs            # Allocation instantanée du fichier swap via posix_fallocate
│   │   ├── network_mirror.rs  # Analyse et sélection des miroirs réseau NixOS
│   │   ├── updater.rs         # Client de mise à jour à chaud (canaux Stable/Testing, téléchargement, exec)
│   │   └── pastebin.rs        # Téléversement chiffré des journaux d'incident vers Pastebin
│   ├── Cargo.toml             # Dépendances et métadonnées du paquet Rust (v1.2.31)
│   └── tauri.conf.json        # Configuration de la fenêtre et sécurité Webview Tauri v2
├── frontend/                  # Interface Utilisateur Web (Thème Catppuccin Mocha)
│   ├── index.html             # Structure HTML5 complète (11 étapes guidées, modals, console de log)
│   ├── css/
│   │   └── style.css          # Design system complet Catppuccin Mocha, composants et responsive
│   └── js/
│       └── app.js             # Contrôleur frontend, validation des formulaires et appels IPC Tauri
├── config/                    # Thèmes et identité visuelle
│   └── themes/                # Wallpapers officiels et logos vectoriels/PNG
├── iso/                       # Configuration de l'image ISO bootable
│   ├── configuration.nix      # Recette NixOS du média Live GNOME avec démarrage automatique
│   └── assets/                # Logos Catppuccin ASCII et bannières Fastfetch
├── dist/                      # Outils d'assemblage des images ISO découpées
│   ├── assemble-iso.sh        # Script d'assemblage sous Linux (concaténation et vérification SHA256)
│   └── assemble-iso.bat       # Script d'assemblage sous Windows (cmd copy /b)
├── flake.nix                  # Déclaration Nix Flake officielle pour le paquet et l'ISO
├── package.nix                # Dérivation Nix de compilation du binaire Rust/Tauri
└── .github/workflows/         # Intégration continue (CI/CD) et publication automatique des releases
```

---

## 🚀 Compilation & Utilisation

### Prérequis
Un système Linux avec [Nix](https://nixos.org/download.html) configuré avec le support des Flakes :
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 1. Compiler l'installateur localement avec Nix
```bash
# Compilation du paquet natif chomiamos-installer
nix build .#omnis

# Exécution de l'installateur compilé
./result/bin/chomiamos-installer --help
./result/bin/chomiamos-installer
```

### 2. Exécuter les tests unitaires Rust
```bash
nix-shell -p pkg-config gtk3 webkitgtk_4_1 openssl dbus --run "cargo test --manifest-path src-tauri/Cargo.toml"
```

### 3. Générer l'image ISO Live bootable
```bash
nix build .#iso
```
L'image ISO bootable sera générée dans `result/iso/nixos-*.iso`.

### 4. Flasher sur clé USB
```bash
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Remplacez `/dev/sdX` par le périphérique correspondant à votre clé USB, par exemple `/dev/sdb`)*

### 5. Assembler l'image ISO multi-parties (Dépôt Git)
Dans le dossier `dist/`, pour contourner la limite de taille des pièces jointes GitHub, l'image ISO est stockée sous forme découpée (`.part-*`) :

**Sous Linux :**
```bash
cd dist
./assemble-iso.sh
```

**Sous Windows :**
Double-cliquez sur `assemble-iso.bat` ou exécutez dans l'invite de commande (CMD) :
```cmd
cd dist
assemble-iso.bat
```

---

## ⚖️ Licence & Crédits

Ce projet est distribué sous les termes de la licence libre **GNU General Public License v3.0 or later ([GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.fr.html))**.  
Le texte intégral est disponible dans le fichier [LICENSE](LICENSE).

### 💖 Remerciements & Historique Open Source

* **Projet d'origine & architecture initiale** : [Omnis Installer](https://github.com/N3oTraX/Omnis) créé par **[N3oTraX](https://github.com/N3oTraX)** et l'équipe **GLF Team**.  
  *Base conceptuelle du partitionnement initial et inspiration du pipeline séquentiel d'installation.*
* **ChomiamOS Installer (v1.2.x)** : Développé, modernisé et maintenu par **Chomiam** pour **ChomiamOS Gaming Edition**.  
  *Réécriture complète en Rust natif multithreadé + Tauri v2, suppression intégrale du code mort historique Python/QML, swap instantané POSIX, support multi-DE étendu (GNOME, Plasma 6, COSMIC, Cinnamon), synchronisation universelle du clavier, sélection multiple d'IDEs, intégration xemu et suites d'émulation complètes, Suite IA locale autonome, système de fichiers Btrfs avec sous-volumes et déploiement déclaratif NixOS.*

---

<p align="center">
  <i>Projet officiel associé à <a href="https://github.com/Chomiam/nix_config_gaming">Chomiam/nix_config_gaming</a></i>
</p>
