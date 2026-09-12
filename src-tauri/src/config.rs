use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct InstallerSelections {
    pub hostname: String,
    pub username: String,
    pub fullname: String,
    pub password: Option<String>,
    pub desktop_env: String, // "gnome", "cinnamon", "kde", "cosmic"
    pub browser: String,
    pub browser_type: String, // "system" | "flatpak"
    pub mail_client: String,  // "thunderbird" | "mailspring" | "none"
    pub gamescope_session: bool,
    pub discord_client: String,
    pub keyboard_layout: String,
    pub keyboard_variant: String,
    pub timezone: String,
    pub target_disk: String,
    pub swap_size_mb: u64,
    pub gpu_driver: Option<String>,

    // Suite d'Émulation & Rétrogaming
    pub emu_es_de: bool,
    pub emu_retroarch: bool,
    pub emu_duckstation: bool,
    pub emu_pcsx2: bool,
    pub emu_rpcs3: bool,
    pub emu_dolphin: bool,
    pub emu_ppsspp: bool,
    pub emu_eden: bool,
    pub emu_azahar: bool,
    pub emu_melonds: bool,
    pub emu_mgba: bool,

    // Gaming
    pub steam: bool,
    pub lutris: bool,
    pub heroic: bool,
    pub faugus: bool,
    pub decky_loader: bool,
    pub geforce_now: bool,
    pub sunshine: bool,
    pub sober: bool,
    pub steering_wheels: bool,

    // Multimédia & Audio
    pub stremio: bool,
    pub vlc: bool,
    pub mpv: bool,
    pub davinci_resolve: String, // "none", "free", "studio"
    pub audacity: bool,
    pub ardour: bool,

    // Productivité & Création
    pub obs_studio: bool,
    pub kdenlive: bool,
    pub blender: bool,
    pub godot: bool,
    pub antigravity: bool,
    pub pear_desktop: bool,
    pub goverlay: bool,
    pub flatseal: bool,

    // Réseau & Partage
    pub tailscale: bool,
    pub localsend: bool,
    pub motrix: bool,

    // Impression 3D & Slicers
    pub slicer_orcaslicer: bool,
    pub slicer_prusaslicer: bool,
    pub slicer_bambustudio: bool,
    pub slicer_cura: bool,

    // Suite IA Locale
    pub ai_suite_enable: bool,
}

impl Default for InstallerSelections {
    fn default() -> Self {
        Self {
            hostname: "chomiamos".into(),
            username: "chomiam".into(),
            fullname: "ChomiamOS User".into(),
            password: None,
            desktop_env: "gnome".into(),
            browser: "chrome".into(),
            browser_type: "system".into(),
            mail_client: "thunderbird".into(),
            discord_client: "discord".into(),
            keyboard_layout: "fr".into(),
            keyboard_variant: "".into(),
            timezone: "Europe/Paris".into(),
            target_disk: "".into(),
            swap_size_mb: 8192,
            gpu_driver: None,
            emu_es_de: false,
            emu_retroarch: false,
            emu_duckstation: false,
            emu_pcsx2: false,
            emu_rpcs3: false,
            emu_dolphin: false,
            emu_ppsspp: false,
            emu_eden: false,
            emu_azahar: false,
            emu_melonds: false,
            emu_mgba: false,
            gamescope_session: true,
            steam: true,
            lutris: true,
            heroic: true,
            faugus: true,
            decky_loader: false,
            geforce_now: false,
            sunshine: false,
            sober: false,
            steering_wheels: false,
            stremio: true,
            vlc: true,
            mpv: true,
            davinci_resolve: "none".into(),
            audacity: false,
            ardour: false,
            obs_studio: false,
            kdenlive: false,
            blender: false,
            godot: false,
            antigravity: false,
            pear_desktop: true,
            goverlay: true,
            flatseal: true,
            tailscale: false,
            localsend: true,
            motrix: false,
            slicer_orcaslicer: false,
            slicer_prusaslicer: false,
            slicer_bambustudio: false,
            slicer_cura: false,
            ai_suite_enable: false,
        }
    }
}

pub fn generate_vars_nix(s: &InstallerSelections, hashed_password: Option<&str>, gpu_driver: &str) -> String {
    let pwd_field = match hashed_password {
        Some(h) => format!("\"{}\"", h),
        None => "null".to_string(),
    };

    let active_gpu = s.gpu_driver.as_deref().unwrap_or(gpu_driver);
    let gamescope_session = if active_gpu == "nvidia" || active_gpu == "nvidia-legacy" {
        "false"
    } else if s.gamescope_session {
        "true"
    } else {
        "false"
    };

    let emu_enable = s.emu_es_de
        || s.emu_retroarch
        || s.emu_duckstation
        || s.emu_pcsx2
        || s.emu_rpcs3
        || s.emu_dolphin
        || s.emu_ppsspp
        || s.emu_eden
        || s.emu_azahar
        || s.emu_melonds
        || s.emu_mgba;
    let emu_frontend = if s.emu_es_de { "es-de" } else { "none" };

    format!(
r#"{{
  # =========================================================================
  # ⚙️ VARIABLES DU SYSTÈME CHOMIAMOS GAMING EDITION
  # Généré par l'installateur ChomiamOS (Rust + Tauri v2)
  # =========================================================================

  # Nom d'hôte de la machine (Hostname)
  hostName = "{hostname}";

  # Localisation & Fuseau horaire
  timeZone = "{timezone}";
  defaultLocale = "fr_FR.UTF-8";

  # Disposition du clavier (universelle multi-DE)
  keyboard = {{
    layout = "{keyboard_layout}";
    variant = "{keyboard_variant}";
    keyMap = "{keyboard_layout}";
  }};

  # Version de l'état système NixOS / Home Manager
  stateVersion = "26.05";

  # Profil utilisateur principal
  user = {{
    username = "{username}";
    fullName = "{fullname}";
    homeDirectory = "/home/{username}";
    shell = "fish";
    initialHashedPassword = {pwd_field};
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
    ];
  }};

  virtualisation = {{
    enable = true;
  }};

  # Navigateur web principal & mode d'installation
  browser = "{browser}";
  browserPackageType = "{browser_type}";

  # Client de messagerie e-mail
  mailClient = "{mail_client}";

  # Client Discord
  discordClient = "{discord_client}";

  # Pare-feu réseau
  firewall = false;

  # Environnement de bureau
  desktopEnv = "{desktop_env}";

  # Matériel GPU
  gpuDriver = "{gpu_driver}";

  # Options du mode Gaming
  gaming = {{
    enable = true;
    gamescopeSession = {gamescope_session};
    launchers = {{
      steam = {steam};
      lutris = {lutris};
      heroic = {heroic};
      faugus = {faugus};
    }};
    deckyLoader = {decky_loader};
    geforceNow = {geforce_now};
    mountGamesDisk = false;
    sunshine = {sunshine};
    sober = {sober};
  }};

  # Volants & Simracing
  steeringWheelSupport = {steering_wheels};

  # Suite d'Émulation & Rétrogaming
  emulation = {{
    enable = {emu_enable};
    frontend = "{emu_frontend}";
    autoCheckUpdates = true;
    retroarch = {{
      enable = {emu_retroarch};
    }};
    standalone = {{
      duckstation = {emu_duckstation};
      eden = {emu_eden};
      dolphin = {emu_dolphin};
      pcsx2 = {emu_pcsx2};
      ppsspp = {emu_ppsspp};
      melonds = {emu_melonds};
      mgba = {emu_mgba};
      azahar = {emu_azahar};
      rpcs3 = {emu_rpcs3};
    }};
  }};

  # =========================================================================
  # 🎬 LOGICIEL DE MONTAGE DAVINCI RESOLVE
  # Options disponibles : "none" | "free" | "studio"
  # =========================================================================
  davinciResolve = "{davinci_resolve}";

  # =========================================================================
  # 🎨 LOGICIELS DE CRÉATION 3D & MOTEURS DE JEU (BLENDER & GODOT ENGINE)
  # =========================================================================
  blender = {blender};
  godot = {godot};

  # =========================================================================
  # 🌐 APPLICATIONS RÉSEAU, PARTAGE & TÉLÉCHARGEMENT
  # =========================================================================
  tailscale = {tailscale};
  localsend = {localsend};
  motrix = {motrix};

  # =========================================================================
  # 📺 MULTIMÉDIA & STREAMING
  # =========================================================================
  stremio = {stremio};
  vlc = {vlc};
  mpv = {mpv};

  # =========================================================================
  # 💻 PRODUCTIVITÉ & OUTILS
  # =========================================================================
  antigravity = {antigravity};
  pearDesktop = {pear_desktop};
  kdenlive = {kdenlive};
  obsStudio = {obs_studio};
  goverlay = {goverlay};
  flatseal = {flatseal};
  audacity = {audacity};
  ardour = {ardour};

  # Impression 3D & Slicers
  slicers = {{
    orcaslicer = {slicer_orcaslicer};
    prusaslicer = {slicer_prusaslicer};
    cura = {slicer_cura};
    bambustudio = {slicer_bambustudio};
  }};

  # =========================================================================
  # 🤖 SUITE IA LOCALE (OLLAMA + OPEN-WEBUI + SEARXNG)
  # =========================================================================
  aiSuite = {{
    enable = {ai_suite_enable};
    rocmOverrideGfx = "12.0.1";
    keepAlive = "0s";
    openWebUiPort = 8080;
    searxPort = 8888;
    openFirewall = false;
  }};
}}
"#,
        hostname = s.hostname,
        keyboard_layout = s.keyboard_layout,
        keyboard_variant = s.keyboard_variant,
        timezone = s.timezone,
        username = s.username,
        fullname = s.fullname,
        pwd_field = pwd_field,
        browser = s.browser,
        browser_type = if s.browser_type.is_empty() { "system" } else { &s.browser_type },
        mail_client = if s.mail_client.is_empty() { "thunderbird" } else { &s.mail_client },
        discord_client = s.discord_client,
        desktop_env = s.desktop_env,
        gpu_driver = active_gpu,
        gamescope_session = gamescope_session,
        emu_enable = emu_enable,
        emu_frontend = emu_frontend,
        emu_retroarch = s.emu_retroarch,
        emu_duckstation = s.emu_duckstation,
        emu_eden = s.emu_eden,
        emu_dolphin = s.emu_dolphin,
        emu_pcsx2 = s.emu_pcsx2,
        emu_ppsspp = s.emu_ppsspp,
        emu_melonds = s.emu_melonds,
        emu_mgba = s.emu_mgba,
        emu_azahar = s.emu_azahar,
        emu_rpcs3 = s.emu_rpcs3,
        steam = s.steam,
        lutris = s.lutris,
        heroic = s.heroic,
        faugus = s.faugus,
        decky_loader = s.decky_loader,
        geforce_now = s.geforce_now,
        sunshine = s.sunshine,
        sober = s.sober,
        steering_wheels = s.steering_wheels,
        davinci_resolve = s.davinci_resolve,
        blender = s.blender,
        godot = s.godot,
        tailscale = s.tailscale,
        localsend = s.localsend,
        motrix = s.motrix,
        stremio = s.stremio,
        vlc = s.vlc,
        mpv = s.mpv,
        antigravity = s.antigravity,
        pear_desktop = s.pear_desktop,
        kdenlive = s.kdenlive,
        obs_studio = s.obs_studio,
        goverlay = s.goverlay,
        flatseal = s.flatseal,
        audacity = s.audacity,
        ardour = s.ardour,
        slicer_orcaslicer = s.slicer_orcaslicer,
        slicer_prusaslicer = s.slicer_prusaslicer,
        slicer_cura = s.slicer_cura,
        slicer_bambustudio = s.slicer_bambustudio,
        ai_suite_enable = s.ai_suite_enable,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_vars_nix_emulation() {
        let mut selections = InstallerSelections::default();
        selections.emu_es_de = true;
        selections.emu_duckstation = true;
        selections.emu_pcsx2 = true;
        selections.emu_rpcs3 = false;
        let out = generate_vars_nix(&selections, None, "amd");
        assert!(out.contains("frontend = \"es-de\";"));
        assert!(out.contains("browserPackageType = \"system\";"));
        assert!(out.contains("mailClient = \"thunderbird\";"));
        assert!(out.contains("duckstation = true;"));
        assert!(out.contains("rpcs3 = false;"));
        assert!(out.contains("gamescopeSession = true;"));

        selections.emu_es_de = false;
        selections.emu_retroarch = false;
        selections.emu_duckstation = false;
        selections.emu_pcsx2 = false;
        selections.emu_rpcs3 = false;
        selections.emu_dolphin = false;
        selections.emu_ppsspp = false;
        selections.emu_eden = false;
        selections.emu_azahar = false;
        selections.emu_melonds = false;
        selections.emu_mgba = false;
        let out2 = generate_vars_nix(&selections, None, "amd");
        assert!(out2.contains("frontend = \"none\";"));
    }
}
