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
  blurPipelines = mkRawGVariant "{'pipeline_default': {'name': <'Default'>, 'effects': <[{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}]>}, 'pipeline_default_rounded': {'name': <'Default rounded'>, 'effects': <[{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000001'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}]>}}";
in
{
  # =========================================================================
  # 💿 CONFIGURATION DU SYSTÈME LIVE-CD ISO CHOMIAMOS GAMING EDITION
  # =========================================================================

  # Optimisation invité pour Machines Virtuelles (QEMU, KVM, Virt-Manager)
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Environnement graphique GNOME pour le Live-CD
  services.xserver.enable = true;
  services.xserver.xkb.layout = "fr";
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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

  # Paquets d'outils requis pour le partitionnement et l'installation
  environment.systemPackages = with pkgs; [
    # Installateur moderne Omnis (Qt6/QML/Python 3)
    omnis

    # Outils de disque & partitionnement
    parted
    gparted
    gptfdisk
    e2fsprogs
    dosfstools
    btrfs-progs
    cryptsetup
    util-linux

    # Détection matérielle & réseau
    pciutils
    usbutils
    git
    curl
    wget
    whois # Fournit mkpasswd

    # Navigateur Web
    firefox

    # Extensions GNOME & Thème Catppuccin Mocha
    gnomeExtensions.dash-to-dock
    gnomeExtensions.vitals
    gnomeExtensions.blur-my-shell
    gnomeExtensions.arcmenu
    gnomeExtensions.user-themes
    catppuccinTheme
    (catppuccin-papirus-folders.override { flavor = "mocha"; accent = "lavender"; })
    catppuccin-cursors.mochaLavender

    # Terminal & Outils Live
    kitty
    kitty-themes
    fastfetch
  ];

  # Raccourci sur le bureau, lancement automatique & Thème Catppuccin Mocha Live
  systemd.tmpfiles.rules = [
    "d /run/omnis 0755 root root -"
    "d /home/nixos/Desktop 0755 nixos users -"
    "L+ /home/nixos/Desktop/omnis.desktop - - - - ${omnis}/share/applications/omnis.desktop"
    "z /home/nixos/Desktop/omnis.desktop 0755 nixos users -"

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
    "L+ /home/nixos/.config/kitty/kitty.conf - - - - ${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-Mocha.conf"
  ];

  # Thème système global GTK4 & GTK3 (Fallback XDG)
  environment.etc."xdg/gtk-4.0/gtk.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk.css";
  environment.etc."xdg/gtk-4.0/gtk-dark.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/gtk-dark.css";
  environment.etc."xdg/gtk-4.0/assets".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-4.0/assets";
  environment.etc."xdg/gtk-3.0/gtk.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk.css";
  environment.etc."xdg/gtk-3.0/gtk-dark.css".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/gtk-dark.css";
  environment.etc."xdg/gtk-3.0/assets".source = "${catppuccinTheme}/share/themes/catppuccin-mocha-lavender-standard/gtk-3.0/assets";

  # Lancement automatique d'Omnis à l'ouverture de la session Live
  environment.etc."xdg/autostart/omnis.desktop".source =
    "${omnis}/share/applications/omnis.desktop";

  # Configuration GNOME pour le Live-CD (Thème Catppuccin & Dash to Dock)
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/background" = {
          picture-uri = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper.jpeg";
          picture-uri-dark = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper.jpeg";
          picture-options = "zoom";
        };
        "org/gnome/desktop/screensaver" = {
          picture-uri = "file://${omnis}/share/omnis/config/themes/chomiamos/wallpapers/wallpaper.jpeg";
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
        "org/gnome/shell" = {
          enabled-extensions = [
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "dash-to-dock@micxgx.gmail.com"
            "Vitals@CoreCoding.com"
            "blur-my-shell@aunetx"
            "arcmenu@arcmenu.com"
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

  # Droits sudo sans mot de passe pour l'utilisateur Live
  security.sudo.wheelNeedsPassword = false;
}
