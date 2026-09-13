{
  lib,
  rustPlatform,
  pkg-config,
  wrapGAppsHook3,
  makeWrapper,
  webkitgtk_4_1,
  gtk3,
  libsoup_3,
  openssl,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  cairo,
  pango,
  gdk-pixbuf,
  harfbuzz,
  gptfdisk,
  parted,
  e2fsprogs,
  dosfstools,
  btrfs-progs,
  cryptsetup,
  util-linux,
  pciutils,
  systemd,
  whois,
  zenity,
}:

let
  runtimeTools = [
    gptfdisk
    parted
    e2fsprogs
    dosfstools
    btrfs-progs
    cryptsetup
    util-linux
    pciutils
    systemd
    whois
    openssl
    zenity
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "chomiamos-installer";
  version = "1.2.26";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    libsoup_3
    openssl
    glib
    glib-networking
    gsettings-desktop-schemas
    cairo
    pango
    gdk-pixbuf
    harfbuzz
  ];

  postInstall = ''
    # Symlinks for backwards compatibility with ISO launcher scripts (omnis, omnis-installer)
    ln -s $out/bin/chomiamos-installer $out/bin/omnis
    ln -s $out/bin/chomiamos-installer $out/bin/omnis-installer

    # Desktop entry
    mkdir -p $out/share/applications
    cat << 'ENTRY' > $out/share/applications/omnis.desktop
[Desktop Entry]
Type=Application
Version=1.0
Name=Installer ChomiamOS
GenericName=System Installer
Comment=Assistant d'installation graphique de ChomiamOS Gaming Edition (Rust + Tauri v2)
Exec=omnis
Icon=chomiamos
StartupWMClass=chomiamos-installer
Terminal=false
Categories=System;Settings;
ENTRY

    # Icons
    mkdir -p $out/share/icons/hicolor/256x256/apps $out/share/icons/hicolor/64x64/apps
    if [ -f config/themes/chomiamos/logos/logo-256.png ]; then
      cp config/themes/chomiamos/logos/logo-256.png $out/share/icons/hicolor/256x256/apps/chomiamos.png
      cp config/themes/chomiamos/logos/logo-64.png $out/share/icons/hicolor/64x64/apps/chomiamos.png
    fi

    # Wallpaper and theme assets preservation for ISO config
    mkdir -p $out/share/omnis
    if [ -d config ]; then
      cp -r config $out/share/omnis/config
      if [ -f config/chomiamos.yaml ]; then
        cp config/chomiamos.yaml $out/share/omnis/omnis.yaml
      fi
    fi

    # Ensure runtime disk & partitioning tools are in PATH and WebKit compatibility in VMs
    wrapProgram $out/bin/chomiamos-installer \
      --prefix PATH : ${lib.makeBinPath runtimeTools} \
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER "1"
  '';

  meta = with lib; {
    description = "ChomiamOS Installer - installateur natif ultra-rapide en Rust & Tauri v2";
    homepage = "https://github.com/Chomiam/chomiamos-installer";
    license = licenses.gpl3Plus;
    mainProgram = "omnis";
    platforms = platforms.linux;
  };
}
