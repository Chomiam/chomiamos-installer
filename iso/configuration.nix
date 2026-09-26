{ pkgs, lib, omnis, ... }:

let
  catppuccinTheme = pkgs.catppuccin-gtk.override {
    variant = "mocha";
    accents = [ "lavender" ];
  };

  # Helper GVariant brut pour les pipelines personnalisés de Blur-My-Shell
  mkRawGVariant = str: {
    _type = "gvariant";
    type = "raw";
    value = str;
    __toString = self: str;
  };
  blurPipelines = mkRawGVariant "{'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}>]>}, 'pipeline_default_rounded': {'name': <'Default rounded'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000001'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}>]>}}";

  # Définition du caractère Échap (ESC / \u001b) pour sérialisation Fastfetch
  esc = builtins.fromJSON "\"\\u001b\"";

  # Configuration Fastfetch Catppuccin Macchiato personnalisée
  fastfetchConfig = pkgs.writeText "fastfetch-config.jsonc" (builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
    logo = {
      type = "kitty-direct";
      source = "~/.config/fastfetch/logo/chomiamos_logo.png";
      width = 40;
      height = 20;
      padding = {
        top = 2;
        left = 2;
        right = 2;
      };
    };
    display = {
      separator = " ${esc}[38;2;198;160;246m${esc}[0m ";
      constants = [
        "${esc}[38;2;240;198;198m─────────────────${esc}[0m"
      ];
      key = {
        type = "icon";
        paddingLeft = 2;
      };
    };
    modules = [
      {
        type = "custom";
        format = "${esc}[38;2;240;198;198m┌${esc}[0m{$1} ${esc}[38;2;198;160;246mHardware Information${esc}[0m {$1}${esc}[38;2;240;198;198m┐${esc}[0m";
      }
      {
        type = "host";
        keyColor = "#f5bde6";
      }
      {
        type = "cpu";
        keyColor = "#f5bde6";
      }
      {
        type = "gpu";
        keyColor = "#f5bde6";
      }
      {
        type = "disk";
        keyColor = "#f5bde6";
      }
      {
        type = "memory";
        keyColor = "#f5bde6";
      }
      {
        type = "display";
        keyColor = "#f5bde6";
      }
      {
        type = "custom";
        format = "${esc}[38;2;240;198;198m└${esc}[0m{$1}${esc}[38;2;240;198;198m──────────────────────${esc}[0m{$1}${esc}[38;2;240;198;198m┘${esc}[0m";
      }
      {
        type = "custom";
        format = "";
      }
      {
        type = "custom";
        format = "${esc}[38;2;240;198;198m┌${esc}[0m{$1} ${esc}[38;2;198;160;246mSoftware Information${esc}[0m {$1}${esc}[38;2;240;198;198m┐${esc}[0m";
      }
      {
        type = "os";
        keyColor = "#f5bde6";
      }
      {
        type = "kernel";
        keyColor = "#f5bde6";
      }
      {
        type = "lm";
        keyColor = "#f5bde6";
      }
      {
        type = "de";
        keyColor = "#f5bde6";
      }
      {
        type = "wm";
        keyColor = "#f5bde6";
      }
      {
        type = "shell";
        keyColor = "#f5bde6";
      }
      {
        type = "terminal";
        keyColor = "#f5bde6";
      }
      {
        type = "font";
        keyColor = "#f5bde6";
      }
      {
        type = "theme";
        keyColor = "#f5bde6";
      }
      {
        type = "icons";
        keyColor = "#f5bde6";
      }
      {
        type = "packages";
        keyColor = "#f5bde6";
      }
      {
        type = "uptime";
        keyColor = "#f5bde6";
      }
      {
        type = "locale";
        keyColor = "#f5bde6";
      }
      {
        type = "custom";
        format = "${esc}[38;2;240;198;198m└${esc}[0m{$1}${esc}[38;2;240;198;198m──────────────────────${esc}[0m{$1}${esc}[38;2;240;198;198m┘${esc}[0m";
      }
      {
        type = "colors";
        symbol = "circle";
        paddingLeft = 21;
      }
    ];
  });

  # Configuration du terminal Kitty (Catppuccin Mocha + JetBrainsMono Nerd Font)
  kittyConf = pkgs.writeText "kitty.conf" ''
    include ${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-Mocha.conf
    font_family JetBrainsMono Nerd Font
    font_size 11
    window_padding_width 8
    background_opacity 0.90
    cursor_shape block
    cursor_blink_interval 0.5
    confirm_os_window_close 0
  '';

  # Script de lancement robuste d'Omnis gérant l'attente du compositeur graphique et la détection d'instance
  omnis-launcher = pkgs.writeShellScriptBin "omnis-launcher" ''
    set -euo pipefail

    # Éviter les lancements concurrents
    if ${pkgs.procps}/bin/pgrep -x omnis >/dev/null 2>&1 || ${pkgs.procps}/bin/pgrep -x chomiamos-installer >/dev/null 2>&1; then
      exit 0
    fi

    # Attendre que la session graphique (Wayland ou X11) soit opérationnelle
    for i in $(seq 1 30); do
      if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -e "''${XDG_RUNTIME_DIR:-}/$WAYLAND_DISPLAY" ]; then
        break
      fi
      if [ -n "''${DISPLAY:-}" ]; then
        break
      fi
      sleep 0.5
    done

    # Laisser GNOME Shell stabiliser le bureau et les extensions
    sleep 1

    # Permettre à root de communiquer avec XWayland si DISPLAY est défini
    if [ -n "''${DISPLAY:-}" ] && command -v ${pkgs.xhost}/bin/xhost >/dev/null 2>&1; then
      ${pkgs.xhost}/bin/xhost +si:localuser:root >/dev/null 2>&1 || true
    fi

    # Lancement d'Omnis avec élévation des privilèges et préservation de l'environnement graphique
    exec sudo -E ${omnis}/bin/omnis "$@"
  '';

  # Fichier Desktop officiel pointant vers le lanceur Omnis
  omnisDesktop = pkgs.makeDesktopItem {
    name = "omnis";
    desktopName = "Installer ChomiamOS";
    genericName = "System Installer";
    comment = "Assistant d'installation graphique de ChomiamOS Gaming Edition";
    icon = "chomiamos";
    exec = "${omnis-launcher}/bin/omnis-launcher";
    startupWMClass = "omnis";
    terminal = false;
    categories = [ "Qt" "System" "Settings" ];
  };
in
{
  # =========================================================================
  # 💿 CONFIGURATION DU SYSTÈME LIVE-CD ISO CHOMIAMOS GAMING EDITION
  # =========================================================================

  # =========================================================================
  # 🎨 BRANDING DU LIVE-CD : BOOTLOADER GRUB & SPLASH PLYMOUTH
  # =========================================================================

  # Nommage personnalisé du menu de boot GRUB / Syslinux
  system.nixos.distroName = "ChomiamOS";
  system.nixos.label = "Installer";
  isoImage.appendToMenuLabel = "";

  # Thème GRUB Catppuccin Mocha pour le boot UEFI de l'ISO Live
  isoImage.grubTheme = pkgs.catppuccin-grub;

  # Compression Squashfs Zstandard ultra-rapide (niveau 19) :
  # Vitesse de décompression maximale dans le noyau Linux (~1,5 à 2,5 Go/s)
  # permettant une copie locale ultra-rapide depuis la clé USB sans freeze CPU.
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";

  # Thème Plymouth Catppuccin Mocha identique à la configuration système installée
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [ (pkgs.catppuccin-plymouth.override { variant = "mocha"; }) ];
  };

  # Paramètres noyau pour un démarrage silencieux avec splash screen animé
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # Optimisation invité pour Machines Virtuelles (QEMU, KVM, Virt-Manager, VMware, VirtualBox, Hyper-V)
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  systemd.services.spice-vdagentd.unitConfig.ConditionVirtualization = "vm";
  virtualisation.vmware.guest.enable = true;
  virtualisation.virtualbox.guest = {
    enable = lib.mkForce true;
    dragAndDrop = true;
    clipboard = true;
  };
  virtualisation.hypervGuest.enable = true;

  # Accélération graphique matérielle OpenGL/Vulkan (Mesa, VirtIO-GPU, VirGL)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Modules de virtualisation et d'accélération d'affichage invité
  boot.initrd.kernelModules = [ "virtio_gpu" "virtio_pci" "virtio_balloon" "virtio_console" "qxl" ];
  boot.kernelModules = [ "virtio_gpu" "qxl" ];

  # Support de tous les microcodes et firmwares pour compatibilité maximale
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  # Fonctionnalités Flakes activées par défaut dans l'environnement Live
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://chomiamos.cachix.org"
      "https://cache.nixos.org"
      "https://chomiamos-dashboard.cachix.org"
      "https://cosmic.cachix.org"
      "https://duckstation.cachix.org"
    ];
    trusted-public-keys = [
      "chomiamos.cachix.org-1:YB3RyqWQZagZxsfBwdVXcJ2219/yAsMFOGoh0pfSbjk="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "chomiamos-dashboard.cachix.org-1:DrjJpGp7tzIMJo6s4dQdwWDopszgo1EFkm34PEN+D+w="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmACbuUuRJDTOMs8ayE="
      "duckstation.cachix.org-1:tNC6UMoM5ZojxBRDdPNHC3xBlk7hnClCtsGsho3YiY4="
    ];
    trusted-substituters = [
      "https://chomiamos.cachix.org"
      "https://cache.nixos.org"
      "https://chomiamos-dashboard.cachix.org"
      "https://cosmic.cachix.org"
      "https://duckstation.cachix.org"
    ];
    trusted-users = [ "root" "@wheel" ];
  };

  # Environnement graphique GNOME pour le Live-CD
  services.xserver.enable = true;
  services.xserver.xkb.layout = "fr";
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Exclusion de Xterm au niveau serveur d'affichage
  services.xserver.excludePackages = [ pkgs.xterm ];

  # Exclusions d'applications GNOME indésirables dans le Live-CD
  environment.gnome.excludePackages = with pkgs; [
    totem
    gnome-maps
    yelp
    gnome-tour
    epiphany
    gnome-console
  ];

  # Polices d'écriture indispensables (Nerd Fonts, Font-Awesome, Noto Fonts)
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
    noto-fonts
  ];

  # Autologin sur l'utilisateur Live par défaut 'nixos'
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  # Fuseau horaire et localisation par défaut pour le Live
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  boot.zfs.forceImportRoot = false;

  # Configuration système pour Omnis Installer
  environment.etc."omnis/omnis.yaml".source = "${omnis}/share/omnis/omnis.yaml";
  environment.etc."omnis/config".source = "${omnis}/share/omnis/config";

  # Activation du shell Fish (shell par défaut de ChomiamOS, pré-embarqué pour éliminer la net install du shell)
  programs.fish = {
    enable = true;
  };

  # Feral GameMode (optimisation CPU/GPU pré-embarquée dans le store)
  programs.gamemode = {
    enable = true;
  };

  # Paquets d'outils requis pour le partitionnement, l'installation et socle minimal ChomiamOS (copie locale ultra-rapide)
  environment.systemPackages = with pkgs; [
    # -------------------------------------------------------------------------
    # 💽 Installateur ChomiamOS (Rust / Tauri v2) & Lanceur graphique
    # -------------------------------------------------------------------------
    omnis
    omnis-launcher
    omnisDesktop
    xhost

    # -------------------------------------------------------------------------
    # 🛠️ Outils de disque & partitionnement
    # -------------------------------------------------------------------------
    parted
    gparted
    gptfdisk
    e2fsprogs
    dosfstools
    btrfs-progs
    cryptsetup
    util-linux

    # -------------------------------------------------------------------------
    # 🌐 Détection matérielle, réseau & connectivité
    # -------------------------------------------------------------------------
    pciutils
    usbutils
    git
    gh
    zenity
    curl
    wget
    whois # Fournit mkpasswd
    spice-vdagent
    xrandr
    wireguard-tools

    # -------------------------------------------------------------------------
    # 🌍 Navigateur Web Live
    # -------------------------------------------------------------------------
    firefox

    # -------------------------------------------------------------------------
    # 🖥️ Environnement GNOME & Extensions officielles ChomiamOS
    # -------------------------------------------------------------------------
    gnomeExtensions.dash-to-dock
    gnomeExtensions.vitals
    gnomeExtensions.blur-my-shell
    gnomeExtensions.arcmenu
    gnomeExtensions.user-themes
    gnomeExtensions.no-overview
    gnomeExtensions.appindicator
    gnomeExtensions.clipboard-indicator
    gnome-tweaks
    gnome-extension-manager
    networkmanagerapplet
    catppuccinTheme
    (catppuccin-papirus-folders.override { flavor = "mocha"; accent = "lavender"; })
    catppuccin-cursors.mochaLavender

    # -------------------------------------------------------------------------
    # 🎨 Socle GTK & Libadwaita
    # -------------------------------------------------------------------------
    adw-gtk3
    libadwaita
    libappindicator-gtk3
    glib-networking

    # -------------------------------------------------------------------------
    # 💻 Terminaux, Rendu & Fastfetch
    # -------------------------------------------------------------------------
    kitty
    kitty-themes
    alacritty
    fastfetch
    chafa
    imagemagick

    # -------------------------------------------------------------------------
    # 🐚 Shell Fish & Plugins officiels (socle utilisateur par défaut)
    # -------------------------------------------------------------------------
    fish
    fishPlugins.fzf-fish
    fishPlugins.done
    fishPlugins.forgit
    fishPlugins.hydro
    fishPlugins.grc
    grc
    fzf

    # -------------------------------------------------------------------------
    # ⚙️ Utilitaires CLI ChomiamOS essentiels (évite tout téléchargement réseau)
    # -------------------------------------------------------------------------
    btop
    nh
    ripgrep
    fuse3

    # -------------------------------------------------------------------------
    # 📦 Compression & Archives système
    # -------------------------------------------------------------------------
    cabextract
    innoextract
    libarchive
    p7zip
    unzip

    # -------------------------------------------------------------------------
    # 🎮 Outils graphiques légers & Diagnostic
    # -------------------------------------------------------------------------
    mangohud
    vulkan-tools
    libva-utils
    easyeffects

    # -------------------------------------------------------------------------
    # 🐍 Environnement d'exécution de base
    # -------------------------------------------------------------------------
    python3
    uv
  ];

  # Lancement automatique de Fastfetch dans le terminal interactif
  programs.bash.interactiveShellInit = ''
    if [[ $- == *i* ]]; then
      fastfetch
    fi
  '';

  # Raccourci sur le bureau, lancement automatique & Thème Catppuccin Mocha Live
  systemd.tmpfiles.rules = [
    "d /run/omnis 0755 root root -"
    "d /home/nixos/Desktop 0755 nixos users -"
    "L+ /home/nixos/Desktop/omnis.desktop - - - - ${omnisDesktop}/share/applications/omnis.desktop"
    "z /home/nixos/Desktop/omnis.desktop 0755 nixos users -"

    # Raccourci autostart dans le profil utilisateur en complément du service systemd
    "d /home/nixos/.config 0755 nixos users -"
    "d /home/nixos/.config/autostart 0755 nixos users -"
    "L+ /home/nixos/.config/autostart/omnis.desktop - - - - ${omnisDesktop}/share/applications/omnis.desktop"
    "z /home/nixos/.config/autostart/omnis.desktop 0755 nixos users -"

    # Déploiement du thème Catppuccin Mocha pour GTK4 / Libadwaita et GTK3
    "d /home/nixos/.config 0755 nixos users -"
    "d /home/nixos/.config/gtk-4.0 0755 nixos users -"
    "L+ /home/nixos/.config/gtk-4.0/gtk.css - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk.css"
    "L+ /home/nixos/.config/gtk-4.0/gtk-dark.css - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk-dark.css"
    "L+ /home/nixos/.config/gtk-4.0/assets - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/assets"
    "d /home/nixos/.config/gtk-3.0 0755 nixos users -"
    "L+ /home/nixos/.config/gtk-3.0/gtk.css - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk.css"
    "L+ /home/nixos/.config/gtk-3.0/gtk-dark.css - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk-dark.css"
    "L+ /home/nixos/.config/gtk-3.0/assets - - - - ${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/assets"

    # Configuration Kitty Catppuccin Mocha
    "d /home/nixos/.config/kitty 0755 nixos users -"
    "L+ /home/nixos/.config/kitty/kitty.conf - - - - ${kittyConf}"

    # Configuration & Assets Fastfetch
    "d /home/nixos/.config/fastfetch 0755 nixos users -"
    "d /home/nixos/.config/fastfetch/logo 0755 nixos users -"
    "L+ /home/nixos/.config/fastfetch/config.jsonc - - - - ${fastfetchConfig}"
    "L+ /home/nixos/.config/fastfetch/logo/chomiamos_logo.png - - - - ${./assets/chomiamos_fastfetch.png}"
    "L+ /home/nixos/.config/fastfetch/logo/catppuccin_logo.txt - - - - ${./assets/catppuccin_logo.txt}"
  ];

  # Thème système global GTK4 & GTK3 (Fallback XDG)
  environment.etc."xdg/gtk-4.0/gtk.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk.css";
  environment.etc."xdg/gtk-4.0/gtk-dark.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk-dark.css";
  environment.etc."xdg/gtk-4.0/assets".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/assets";
  environment.etc."xdg/gtk-3.0/gtk.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk.css";
  environment.etc."xdg/gtk-3.0/gtk-dark.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk-dark.css";
  environment.etc."xdg/gtk-3.0/assets".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/assets";

  # Configuration système globale Fastfetch (Fallback XDG)
  environment.etc."xdg/fastfetch/config.jsonc".source = fastfetchConfig;
  environment.etc."xdg/fastfetch/logo/chomiamos_logo.png".source = ./assets/chomiamos_fastfetch.png;
  environment.etc."xdg/fastfetch/logo/catppuccin_logo.txt".source = ./assets/catppuccin_logo.txt;

  # Lancement automatique d'Omnis à l'ouverture de la session Live
  environment.etc."xdg/autostart/omnis.desktop".source =
    "${omnisDesktop}/share/applications/omnis.desktop";

  # Service de démarrage automatique d'Omnis à l'ouverture de la session graphique GNOME
  systemd.user.services.omnis-autostart = {
    description = "Assistant d'installation graphique ChomiamOS (Omnis)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${omnis-launcher}/bin/omnis-launcher";
      Restart = "no";
    };
  };

  # Configuration GNOME pour le Live-CD (Thème Catppuccin & Dash to Dock)
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/background" = {
          picture-uri = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper_0007.png";
          picture-uri-dark = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper_0007.png";
          picture-options = "zoom";
        };
        "org/gnome/desktop/screensaver" = {
          picture-uri = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper_0007.png";
          picture-options = "zoom";
        };
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "catppuccin-mocha-lavender-standard";
          icon-theme = "Papirus-Dark";
          cursor-theme = "catppuccin-mocha-lavender-cursors";
          accent-color = "purple";
          enable-animations = false;
        };
        "org/gnome/desktop/default-applications/terminal" = {
          exec = "kitty";
          exec-arg = "-e";
        };
        "org/gnome/shell" = {
          enabled-extensions = [
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "dash-to-dock@micxgx.gmail.com"
            "Vitals@CoreCoding.com"
            "blur-my-shell@aunetx"
            "arcmenu@arcmenu.com"
            "no-overview@fthx"
          ];
          favorite-apps = [
            "omnis.desktop"
            "org.gnome.Nautilus.desktop"
            "kitty.desktop"
            "firefox.desktop"
          ];
        };
        "org/gnome/shell/extensions/user-theme" = {
          name = "catppuccin-mocha-lavender-standard";
        };

        "org/gnome/shell/extensions/arcmenu" = {
          menu-button-appearance = "None";
          menu-layout = "runner";
          prefs-visible-page = lib.gvariant.mkInt32 0;
          search-entry-border-radius = lib.gvariant.mkTuple [ (lib.gvariant.mkBoolean true) (lib.gvariant.mkInt32 25) ];
          update-notifier-project-version = lib.gvariant.mkInt32 73;
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "icon:minimize,maximize,close";
        };

        "org/gnome/shell/extensions/blur-my-shell" = {
          pipelines = blurPipelines;
          rounded-blur-found = false;
          settings-version = lib.gvariant.mkInt32 2;
        };
        "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
          brightness = lib.gvariant.mkDouble 0.6;
          sigma = lib.gvariant.mkInt32 30;
        };
        "org/gnome/shell/extensions/blur-my-shell/applications" = {
          blur = true;
          blur-on-overview = true;
          dynamic-opacity = false;
          enable-all = false;
          pipeline = "pipeline_default";
          sigma = lib.gvariant.mkInt32 30;
          static-blur = false;
          whitelist = [ "org.gnome.Nautilus" ];
        };
        "org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab" = {
          pipeline = "pipeline_default";
        };
        "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
          blur = true;
          brightness = lib.gvariant.mkDouble 0.6;
          pipeline = "pipeline_default_rounded";
          sigma = lib.gvariant.mkInt32 30;
          static-blur = true;
          style-dash-to-dock = lib.gvariant.mkInt32 0;
        };
        "org/gnome/shell/extensions/blur-my-shell/lockscreen" = {
          pipeline = "pipeline_default";
        };
        "org/gnome/shell/extensions/blur-my-shell/overview" = {
          pipeline = "pipeline_default";
        };
        "org/gnome/shell/extensions/blur-my-shell/panel" = {
          brightness = lib.gvariant.mkDouble 0.6;
          corner-radius = lib.gvariant.mkInt32 0;
          pipeline = "pipeline_default";
          sigma = lib.gvariant.mkInt32 30;
        };
        "org/gnome/shell/extensions/blur-my-shell/screenshot" = {
          pipeline = "pipeline_default";
        };
        "org/gnome/shell/extensions/blur-my-shell/window-list" = {
          brightness = lib.gvariant.mkDouble 0.6;
          sigma = lib.gvariant.mkInt32 30;
        };

        "org/gnome/shell/extensions/dash-to-dock" = {
          dock-position = "LEFT";
          dock-fixed = true;
          extend-height = true;
          dash-max-icon-size = lib.gvariant.mkInt32 48;
          height-fraction = lib.gvariant.mkDouble 0.9;
          background-opacity = lib.gvariant.mkDouble 0.8;
          custom-theme-shrink = true;
          hide-tooltip = false;
          preferred-monitor = lib.gvariant.mkInt32 (-2);
          show-icons-notifications-counter = false;
          show-show-apps-button = false;
        };
      };
    }
  ];

  # Droits sudo sans mot de passe pour l'utilisateur Live et préservation de l'environnement d'affichage
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    extraConfig = ''
      Defaults env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY XAUTHORITY QT_QPA_PLATFORM"
    '';
  };
}
