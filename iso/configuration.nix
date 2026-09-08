{ pkgs, lib, ... }:

let
  installerPkg = pkgs.stdenv.mkDerivation {
    name = "chomiamos-installer";
    src = ../scripts;
    installPhase = ''
      mkdir -p $out/bin $out/share/chomiamos-installer/theme
      cp -r theme/* $out/share/chomiamos-installer/theme/
      cp chomiamos-installer.sh $out/bin/chomiamos-installer
      chmod +x $out/bin/chomiamos-installer
      sed -i "s|CSS_FILE=.*|CSS_FILE=$out/share/chomiamos-installer/theme/catppuccin-mocha.css|g" $out/bin/chomiamos-installer
    '';
  };

  installerDesktop = pkgs.makeDesktopItem {
    name = "chomiamos-installer";
    desktopName = "Installer ChomiamOS";
    comment = "Assistant d'installation graphique de ChomiamOS Gaming Edition";
    exec = "sudo ${installerPkg}/bin/chomiamos-installer";
    icon = "system-software-install";
    terminal = false;
    type = "Application";
    categories = [ "System" "Settings" ];
  };
in
{
  # =========================================================================
  # 💿 CONFIGURATION DU SYSTÈME LIVE-CD ISO CHOMIAMOS
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

  # Forcer la résolution d'affichage minimale à 1920x1080 dès le démarrage
  boot.kernelParams = [
    "video=1920x1080@60"
  ];



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

  # Paquets d'outils requis pour le partitionnement et l'installation
  environment.systemPackages = with pkgs; [
    # Assistant Yad thémé Catppuccin et script d'installation
    yad
    installerPkg
    installerDesktop

    # Outils de disque & partitionnement
    parted
    gparted
    e2fsprogs
    dosfstools
    btrfs-progs
    util-linux

    # Détection matérielle & réseau
    pciutils
    usbutils
    git
    curl
    wget
  ];

  # Raccourci sur le bureau et lancement automatique
  systemd.tmpfiles.rules = [
    "d /home/nixos/Desktop 0755 nixos users -"
    "L+ /home/nixos/Desktop/chomiamos-installer.desktop - - - - ${installerDesktop}/share/applications/chomiamos-installer.desktop"
    "z /home/nixos/Desktop/chomiamos-installer.desktop 0755 nixos users -"
  ];

  # Lancement automatique de l'installateur à l'ouverture de la session Live
  environment.etc."xdg/autostart/chomiamos-installer.desktop".source =
    "${installerDesktop}/share/applications/chomiamos-installer.desktop";

  # Favoris du dock GNOME pour le Live-CD
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita-dark";
          enable-animations = false;
        };
        "org/gnome/shell" = {
          favorite-apps = [
            "chomiamos-installer.desktop"
            "org.gnome.Nautilus.desktop"
            "kitty.desktop"
            "google-chrome.desktop"
          ];
        };
      };
    }
  ];

  # Droits sudo sans mot de passe pour l'utilisateur Live
  security.sudo.wheelNeedsPassword = false;
}
