{
  lib,
  python3Packages,
  qt6,
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
  openssl,
  makeFontsConf,
  poppins,
  roboto-mono,
  noto-fonts,
  noto-fonts-monochrome-emoji,
}:

let
  # Partition toolchain shelled out by the partition job. Bundled so the editor
  # works off the GLF ISO too (nixos-install stays live-only, unbundlable).
  runtimeTools = [
    gptfdisk
    parted
    e2fsprogs
    dosfstools
    btrfs-progs
    cryptsetup
    util-linux
    pciutils
    # udevadm lives in systemd, not util-linux: without it the partition job
    # died on "Required tool not found: udevadm" -- after wiping the disk.
    systemd
    # Password hashing for the generated NixOS config. mkpasswd ships in whois;
    # openssl is the fallback the job tries next.
    whois
    openssl
  ];

  # Fonts bundled so the UI renders identically off-host (AppImage): the theme
  # fonts (Poppins, Roboto Mono), Noto Sans for non-Latin locales, and the
  # monochrome emoji font that draws the requirement/section pictograms (color
  # emoji would clash with the flat UI). A self-contained fontconfig file is
  # pointed to by FONTCONFIG_FILE so font matching works without host /etc/fonts.
  fontsConf = makeFontsConf {
    fontDirectories = [
      poppins
      roboto-mono
      noto-fonts
      noto-fonts-monochrome-emoji
    ];
  };
in

# Omnis - modular GLF-OS installer (PySide6/QML). Packaged as a Qt-wrapped
# Python application so QML imports and Qt platform plugins resolve at runtime.
python3Packages.buildPythonApplication {
  pname = "omnis-installer";
  version = "0.6.3";

  src = ./.;

  pyproject = true;

  build-system = [ python3Packages.hatchling ];

  # Qt wrapping: exposes QT_PLUGIN_PATH + QML2_IMPORT_PATH to the `omnis`
  # entry point. qtdeclarative provides QtQuick + QtQuick.Controls; qtsvg
  # renders the SVG icons used across the wizard.
  nativeBuildInputs = [ qt6.wrapQtAppsHook ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
  ];

  # wrapQtAppsHook wraps the entry point but does NOT inject the QML import
  # path for a Python app, so QtQuick / QtQuick.Controls (bundled in
  # qtdeclarative) are not found and the QML interface fails to load. The
  # Python wrapper honors makeWrapperArgs, so set QML2_IMPORT_PATH there
  # (mirrors the working dev launcher run-omnis.sh).
  makeWrapperArgs = [
    "--prefix QML2_IMPORT_PATH : ${qt6.qtdeclarative}/lib/qt-6/qml"
    "--prefix PATH : ${lib.makeBinPath runtimeTools}"
    "--set-default FONTCONFIG_FILE ${fontsConf}"
    # qsvg imageformats plugin: PySide6's QImageReader ships no SVG support, so
    # QML Image { source: "*.svg" } fails with "unsupported format" until the
    # bundled qtsvg plugin is on the plugin path (theme icons are SVG).
    "--prefix QT_PLUGIN_PATH : ${qt6.qtsvg}/lib/qt-6/plugins"
  ];

  dependencies = with python3Packages; [
    pyside6
    pydantic
    pyyaml
    tzdata
  ];

  # PySide6 + QML cannot be import-checked headlessly in the sandbox.
  pythonImportsCheck = [ ];
  doCheck = false;

  # Ship the config + theme tree so the NixOS module can provision
  # /etc/omnis/omnis.yaml and the theme assets from the same versioned source.
  postInstall = ''
    python -m compileall -q src
    mkdir -p $out/share/omnis
    cp -r config $out/share/omnis/config
    cp config/chomiamos.yaml $out/share/omnis/omnis.yaml

    mkdir -p $out/share/icons/hicolor/256x256/apps $out/share/icons/hicolor/64x64/apps
    cp config/themes/chomiamos/logos/logo-256.png $out/share/icons/hicolor/256x256/apps/chomiamos.png
    cp config/themes/chomiamos/logos/logo-64.png $out/share/icons/hicolor/64x64/apps/chomiamos.png

    mkdir -p $out/share/applications
    cat << 'ENTRY' > $out/share/applications/omnis.desktop
[Desktop Entry]
Type=Application
Version=1.0
Name=Installer ChomiamOS
GenericName=System Installer
Comment=Assistant d'installation graphique de ChomiamOS Gaming Edition
Exec=omnis
Icon=chomiamos
StartupWMClass=omnis
Terminal=false
Categories=Qt;System;Settings;
ENTRY
  '';

  meta = {
    description = "ChomiamOS Installer - installateur graphique modulaire (basé sur Omnis par N3oTraX)";
    homepage = "https://github.com/Chomiam/chomiamos-installer";
    license = lib.licenses.gpl3Plus;
    mainProgram = "omnis";
    platforms = lib.platforms.linux;
  };
}
