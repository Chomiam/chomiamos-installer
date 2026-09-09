{ pkgs, lib, omnis, ... }:

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

    # Extensions GNOME (Dash to Dock, Vitals) & Thème Catppuccin
    gnomeExtensions.dash-to-dock
    gnomeExtensions.vitals
    gnomeExtensions.blur-my-shell
    (catppuccin-papirus-folders.override { flavor = "mocha"; accent = "lavender"; })
    catppuccin-cursors.mochaLavender
  ];

  # Raccourci sur le bureau et lancement automatique
  systemd.tmpfiles.rules = [
    "d /run/omnis 0755 root root -"
    "d /home/nixos/Desktop 0755 nixos users -"
    "L+ /home/nixos/Desktop/omnis.desktop - - - - ${omnis}/share/applications/omnis.desktop"
    "z /home/nixos/Desktop/omnis.desktop 0755 nixos users -"
  ];

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
          gtk-theme = "Adwaita-dark";
          icon-theme = "Papirus-Dark";
          cursor-theme = "catppuccin-mocha-lavender-cursors";
          accent-color = "purple";
          enable-animations = false;
        };
        "org/gnome/shell" = {
          enabled-extensions = [
            "dash-to-dock@micxgx.gmail.com"
            "Vitals@CoreCoding.com"
            "blur-my-shell@aunetx"
          ];
          favorite-apps = [
            "omnis.desktop"
            "org.gnome.Nautilus.desktop"
            "kitty.desktop"
            "google-chrome.desktop"
          ];
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "icon:minimize,maximize,close";
        };

        "org/gnome/shell/extensions/blur-my-shell" = {
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
