use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallerSelections {
    pub hostname: String,
    pub username: String,
    pub fullname: String,
    pub password: Option<String>,
    pub desktop_env: String, // "gnome", "cinnamon", "kde", "cosmic"
    pub browser: String,
    pub discord_client: String,
    pub keyboard_layout: String,
    pub keyboard_variant: String,
    pub target_disk: String,
    pub swap_size_mb: u64,
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
            discord_client: "discord".into(),
            keyboard_layout: "fr".into(),
            keyboard_variant: "".into(),
            target_disk: "".into(),
            swap_size_mb: 8192,
            steam: true,
            lutris: true,
            heroic: true,
            faugus: true,
            decky_loader: false,
            geforce_now: false,
            sunshine: false,
            sober: false,
            steering_wheels: false,
        }
    }
}

pub fn generate_vars_nix(s: &InstallerSelections, hashed_password: Option<&str>, gpu_driver: &str) -> String {
    let pwd_field = match hashed_password {
        Some(h) => format!("\"{}\"", h),
        None => "null".to_string(),
    };

    let gamescope_session = if gpu_driver == "nvidia" || gpu_driver == "nvidia-legacy" {
        "false"
    } else {
        "true"
    };

    format!(
r#"{{
  # =========================================================================
  # ⚙️ VARIABLES DU SYSTÈME CHOMIAMOS GAMING EDITION
  # Généré par le nouvel installateur ChomiamOS (Rust + Tauri v2)
  # =========================================================================

  # Nom d'hôte de la machine (Hostname)
  hostName = "{hostname}";

  # Localisation & Fuseau horaire
  timeZone = "Europe/Paris";
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

  # Navigateur web principal
  browser = "{browser}";

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
    enable = false;
    frontend = "es-de";
    autoCheckUpdates = true;
    retroarch = {{
      enable = true;
    }};
    standalone = {{
      duckstation = true;
      eden = true;
      dolphin = true;
      pcsx2 = true;
      ppsspp = true;
      melonds = true;
      mgba = true;
      azahar = true;
      rpcs3 = false;
    }};
  }};
}}
"#,
        hostname = s.hostname,
        keyboard_layout = s.keyboard_layout,
        keyboard_variant = s.keyboard_variant,
        username = s.username,
        fullname = s.fullname,
        pwd_field = pwd_field,
        browser = s.browser,
        discord_client = s.discord_client,
        desktop_env = s.desktop_env,
        gpu_driver = gpu_driver,
        gamescope_session = gamescope_session,
        steam = s.steam,
        lutris = s.lutris,
        heroic = s.heroic,
        faugus = s.faugus,
        decky_loader = s.decky_loader,
        geforce_now = s.geforce_now,
        sunshine = s.sunshine,
        sober = s.sober,
        steering_wheels = s.steering_wheels,
    )
}
