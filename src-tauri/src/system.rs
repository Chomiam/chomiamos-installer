use std::process::Command;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use sysinfo::System;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemPrerequisites {
    pub is_efi: bool,
    pub total_ram_gb: f64,
    pub ram_ok: bool,
    pub cpu_cores: usize,
    pub has_internet: bool,
    pub disks_count: usize,
    pub is_laptop: bool,
    pub battery_ok: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskInfo {
    pub name: String,
    pub path: String,
    pub size_gb: f64,
    pub model: String,
    pub is_rotational: bool, // false = SSD/NVMe, true = HDD
    pub is_nvme: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyboardVariantInfo {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyboardLayoutInfo {
    pub id: String,
    pub code: String,
    pub name: String,
    pub variants: Vec<KeyboardVariantInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimezoneInfo {
    pub id: String,
    pub name: String,
    pub region: String,
}

pub fn check_prerequisites() -> SystemPrerequisites {
    let mut sys = System::new_all();
    sys.refresh_all();

    let is_efi = Path::new("/sys/firmware/efi").exists();
    let total_ram_gb = (sys.total_memory() as f64) / (1024.0 * 1024.0 * 1024.0);
    let ram_ok = total_ram_gb >= 3.5;
    let cpu_cores = sys.cpus().len();

    // Internet check (DNS socket or ping check)
    let has_internet = std::net::TcpStream::connect_timeout(
        &"1.1.1.1:53".parse().unwrap(),
        std::time::Duration::from_millis(1500),
    ).is_ok();

    // Check battery / laptop
    let power_supply = Path::new("/sys/class/power_supply");
    let mut is_laptop = false;
    let mut battery_ok = true;

    if power_supply.exists() {
        if let Ok(entries) = fs::read_dir(power_supply) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("BAT") {
                    is_laptop = true;
                    // Check if charging or > 20%
                    let capacity_path = entry.path().join("capacity");
                    if let Ok(cap_str) = fs::read_to_string(capacity_path) {
                        if let Ok(cap) = cap_str.trim().parse::<u32>() {
                            if cap < 20 {
                                battery_ok = false;
                            }
                        }
                    }
                }
            }
        }
    }

    let disks = list_disks();

    SystemPrerequisites {
        is_efi,
        total_ram_gb: (total_ram_gb * 10.0).round() / 10.0,
        ram_ok,
        cpu_cores,
        has_internet,
        disks_count: disks.len(),
        is_laptop,
        battery_ok,
    }
}

pub fn list_disks() -> Vec<DiskInfo> {
    let mut disks = Vec::new();
    let block_dir = Path::new("/sys/block");

    if !block_dir.exists() {
        return disks;
    }

    if let Ok(entries) = fs::read_dir(block_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();

            // Ignore loop devices, ramdisks, optical drives, zram
            if name.starts_with("loop") || name.starts_with("ram") || name.starts_with("sr") || name.starts_with("zram") {
                continue;
            }

            let path = format!("/dev/{}", name);
            let size_path = entry.path().join("size");
            let size_gb = if let Ok(size_str) = fs::read_to_string(size_path) {
                let sectors = size_str.trim().parse::<u64>().unwrap_or(0);
                (sectors * 512) as f64 / (1024.0 * 1024.0 * 1024.0)
            } else {
                0.0
            };

            if size_gb < 1.0 {
                continue; // Ignore drives < 1GB (likely USB installer or pseudo block)
            }

            let model_path = entry.path().join("device/model");
            let model = fs::read_to_string(model_path)
                .map(|s| s.trim().to_string())
                .unwrap_or_else(|_| name.clone());

            let rotational_path = entry.path().join("queue/rotational");
            let is_rotational = fs::read_to_string(rotational_path)
                .map(|s| s.trim() == "1")
                .unwrap_or(false);

            let is_nvme = name.starts_with("nvme");

            disks.push(DiskInfo {
                name,
                path,
                size_gb: (size_gb * 10.0).round() / 10.0,
                model,
                is_rotational,
                is_nvme,
            });
        }
    }

    disks.sort_by(|a, b| a.name.cmp(&b.name));
    disks
}

pub fn get_keyboard_layouts() -> Vec<KeyboardLayoutInfo> {
    vec![
        KeyboardLayoutInfo {
            id: "fr".into(),
            code: "fr".into(),
            name: "Français (AZERTY)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard (Par défaut)".into() },
                KeyboardVariantInfo { id: "oss".into(), name: "Alternative / OSS".into() },
                KeyboardVariantInfo { id: "bepo".into(), name: "Ergonomique BÉPO".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
                KeyboardVariantInfo { id: "latin9".into(), name: "Latin-9 alternatif".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "us".into(),
            code: "us".into(),
            name: "Anglais US (QWERTY)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard QWERTY".into() },
                KeyboardVariantInfo { id: "intl".into(), name: "International (touches mortes)".into() },
                KeyboardVariantInfo { id: "altgr-intl".into(), name: "AltGr International".into() },
                KeyboardVariantInfo { id: "dvorak".into(), name: "Dvorak".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "be".into(),
            code: "be".into(),
            name: "Belge (AZERTY)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Belge".into() },
                KeyboardVariantInfo { id: "oss".into(), name: "Belge Alternative OSS".into() },
                KeyboardVariantInfo { id: "iso-alternate".into(), name: "Belge ISO alternative".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "ch".into(),
            code: "ch".into(),
            name: "Suisse (QWERTZ)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "fr".into(), name: "Suisse Romand (Français)".into() },
                KeyboardVariantInfo { id: "de".into(), name: "Suisse Alémanique (Allemand)".into() },
                KeyboardVariantInfo { id: "fr_mac".into(), name: "Suisse Romand (Mac)".into() },
                KeyboardVariantInfo { id: "de_mac".into(), name: "Suisse Alémanique (Mac)".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "ca".into(),
            code: "ca".into(),
            name: "Canadien Français (QWERTY)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Canadien".into() },
                KeyboardVariantInfo { id: "fr-legacy".into(), name: "Canadien Français Hérité".into() },
                KeyboardVariantInfo { id: "fr-dvorak".into(), name: "Canadien Dvorak".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "de".into(),
            code: "de".into(),
            name: "Allemand (QWERTZ)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Allemand".into() },
                KeyboardVariantInfo { id: "deadgraveacute".into(), name: "Touches mortes".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
                KeyboardVariantInfo { id: "neo".into(), name: "Neo 2".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "gb".into(),
            code: "gb".into(),
            name: "Anglais UK (QWERTY)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard UK".into() },
                KeyboardVariantInfo { id: "extd".into(), name: "UK International étendu".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "es".into(),
            code: "es".into(),
            name: "Espagnol".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Espagnol".into() },
                KeyboardVariantInfo { id: "cat".into(), name: "Catalan".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "it".into(),
            code: "it".into(),
            name: "Italien".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Italien".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "pt".into(),
            code: "pt".into(),
            name: "Portugais".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Portugais".into() },
                KeyboardVariantInfo { id: "mac".into(), name: "Apple Macintosh".into() },
                KeyboardVariantInfo { id: "nativo".into(), name: "Nativo".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "br".into(),
            code: "br".into(),
            name: "Brésilien (ABNT2)".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard ABNT2".into() },
                KeyboardVariantInfo { id: "nativo".into(), name: "Nativo".into() },
            ],
        },
        KeyboardLayoutInfo {
            id: "ara".into(),
            code: "ara".into(),
            name: "Arabe".into(),
            variants: vec![
                KeyboardVariantInfo { id: "".into(), name: "Standard Arabe".into() },
                KeyboardVariantInfo { id: "azerty".into(), name: "Arabe (AZERTY)".into() },
                KeyboardVariantInfo { id: "qwerty".into(), name: "Arabe (QWERTY)".into() },
            ],
        },
    ]
}

pub fn get_timezones() -> Vec<TimezoneInfo> {
    vec![
        // Europe & francophonie proche
        TimezoneInfo { id: "Europe/Paris".into(), name: "Europe/Paris (France, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Brussels".into(), name: "Europe/Brussels (Belgique, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Zurich".into(), name: "Europe/Zurich (Suisse, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Luxembourg".into(), name: "Europe/Luxembourg (Luxembourg, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Monaco".into(), name: "Europe/Monaco (Monaco, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/London".into(), name: "Europe/London (Royaume-Uni, UTC+0 / UTC+1)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Berlin".into(), name: "Europe/Berlin (Allemagne, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Madrid".into(), name: "Europe/Madrid (Espagne, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Rome".into(), name: "Europe/Rome (Italie, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Amsterdam".into(), name: "Europe/Amsterdam (Pays-Bas, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Lisbon".into(), name: "Europe/Lisbon (Portugal, UTC+0 / UTC+1)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Dublin".into(), name: "Europe/Dublin (Irlande, UTC+0 / UTC+1)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Athens".into(), name: "Europe/Athens (Grèce, UTC+2 / UTC+3)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Warsaw".into(), name: "Europe/Warsaw (Pologne, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Prague".into(), name: "Europe/Prague (Tchéquie, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Stockholm".into(), name: "Europe/Stockholm (Suède, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Oslo".into(), name: "Europe/Oslo (Norvège, UTC+1 / UTC+2)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Helsinki".into(), name: "Europe/Helsinki (Finlande, UTC+2 / UTC+3)".into(), region: "Europe".into() },
        TimezoneInfo { id: "Europe/Copenhagen".into(), name: "Europe/Copenhagen (Danemark, UTC+1 / UTC+2)".into(), region: "Europe".into() },

        // Amériques & Outre-mer
        TimezoneInfo { id: "America/Montreal".into(), name: "America/Montreal (Canada Est, Québec, UTC-5 / UTC-4)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Toronto".into(), name: "America/Toronto (Canada Est, UTC-5 / UTC-4)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Vancouver".into(), name: "America/Vancouver (Canada Ouest, UTC-8 / UTC-7)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/New_York".into(), name: "America/New_York (États-Unis Est, UTC-5 / UTC-4)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Chicago".into(), name: "America/Chicago (États-Unis Centre, UTC-6 / UTC-5)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Denver".into(), name: "America/Denver (États-Unis Montagnes, UTC-7 / UTC-6)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Los_Angeles".into(), name: "America/Los_Angeles (États-Unis Pacifique, UTC-8 / UTC-7)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Guadeloupe".into(), name: "America/Guadeloupe (Antilles françaises, UTC-4)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Martinique".into(), name: "America/Martinique (Antilles françaises, UTC-4)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Cayenne".into(), name: "America/Cayenne (Guyane française, UTC-3)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Sao_Paulo".into(), name: "America/Sao_Paulo (Brésil, UTC-3)".into(), region: "Amériques".into() },
        TimezoneInfo { id: "America/Argentina/Buenos_Aires".into(), name: "America/Buenos_Aires (Argentine, UTC-3)".into(), region: "Amériques".into() },

        // Outre-mer, Océan Indien & Pacifique
        TimezoneInfo { id: "Indian/Reunion".into(), name: "Indian/Reunion (La Réunion, UTC+4)".into(), region: "Outre-Mer".into() },
        TimezoneInfo { id: "Indian/Mayotte".into(), name: "Indian/Mayotte (Mayotte, UTC+3)".into(), region: "Outre-Mer".into() },
        TimezoneInfo { id: "Pacific/Noumea".into(), name: "Pacific/Noumea (Nouvelle-Calédonie, UTC+11)".into(), region: "Outre-Mer".into() },
        TimezoneInfo { id: "Pacific/Tahiti".into(), name: "Pacific/Tahiti (Polynésie française, UTC-10)".into(), region: "Outre-Mer".into() },
        TimezoneInfo { id: "Pacific/Wallis".into(), name: "Pacific/Wallis (Wallis-et-Futuna, UTC+12)".into(), region: "Outre-Mer".into() },
        TimezoneInfo { id: "Pacific/Auckland".into(), name: "Pacific/Auckland (Nouvelle-Zélande, UTC+12 / UTC+13)".into(), region: "Pacifique".into() },
        TimezoneInfo { id: "Australia/Sydney".into(), name: "Australia/Sydney (Australie Est, UTC+10 / UTC+11)".into(), region: "Pacifique".into() },

        // Afrique
        TimezoneInfo { id: "Africa/Casablanca".into(), name: "Africa/Casablanca (Maroc, UTC+1)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Algiers".into(), name: "Africa/Algiers (Algérie, UTC+1)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Tunis".into(), name: "Africa/Tunis (Tunisie, UTC+1)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Dakar".into(), name: "Africa/Dakar (Sénégal, UTC+0)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Abidjan".into(), name: "Africa/Abidjan (Côte d'Ivoire, UTC+0)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Cairo".into(), name: "Africa/Cairo (Égypte, UTC+2 / UTC+3)".into(), region: "Afrique".into() },
        TimezoneInfo { id: "Africa/Johannesburg".into(), name: "Africa/Johannesburg (Afrique du Sud, UTC+2)".into(), region: "Afrique".into() },

        // Asie & Moyen-Orient
        TimezoneInfo { id: "Asia/Tokyo".into(), name: "Asia/Tokyo (Japon, UTC+9)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Seoul".into(), name: "Asia/Seoul (Corée du Sud, UTC+9)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Shanghai".into(), name: "Asia/Shanghai (Chine, UTC+8)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Hong_Kong".into(), name: "Asia/Hong_Kong (Hong Kong, UTC+8)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Singapore".into(), name: "Asia/Singapore (Singapour, UTC+8)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Bangkok".into(), name: "Asia/Bangkok (Thaïlande, UTC+7)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Dubai".into(), name: "Asia/Dubai (Émirats arabes unis, UTC+4)".into(), region: "Asie".into() },
        TimezoneInfo { id: "Asia/Jerusalem".into(), name: "Asia/Jerusalem (Israël, UTC+2 / UTC+3)".into(), region: "Asie".into() },

        // Standard UTC
        TimezoneInfo { id: "UTC".into(), name: "UTC (Temps universel coordonné)".into(), region: "Monde".into() },
    ]
}

pub fn get_current_timezone() -> String {
    // 1. Essai via timedatectl
    if let Ok(output) = Command::new("timedatectl").args(["show", "--property=Timezone", "--value"]).output() {
        let val = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !val.is_empty() {
            return val;
        }
    }

    // 2. Essai via lien symbolique /etc/localtime
    if let Ok(target) = std::fs::read_link("/etc/localtime") {
        let path_str = target.to_string_lossy();
        if let Some(pos) = path_str.find("zoneinfo/") {
            let tz = &path_str[pos + 9..];
            if !tz.is_empty() {
                return tz.to_string();
            }
        }
    }

    // 3. Essai via /etc/timezone
    if let Ok(content) = std::fs::read_to_string("/etc/timezone") {
        let val = content.trim().to_string();
        if !val.is_empty() {
            return val;
        }
    }

    "Europe/Paris".to_string()
}


#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DesktopEnvInfo {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    pub icon: String,
}

pub fn get_desktop_environments() -> Vec<DesktopEnvInfo> {
    // 1. Détection dynamique de la version réelle de GNOME
    let gnome_ver_str = if let Ok(output) = Command::new("gnome-shell").arg("--version").output() {
        let text = String::from_utf8_lossy(&output.stdout);
        // Ex: "GNOME Shell 50.4"
        let parts: Vec<&str> = text.split_whitespace().collect();
        if parts.len() >= 3 {
            let ver = parts[2].split('.').next().unwrap_or("50");
            format!("GNOME {}", ver)
        } else {
            "GNOME 50".to_string()
        }
    } else {
        "GNOME 50".to_string()
    };

    vec![
        DesktopEnvInfo {
            id: "gnome".into(),
            name: gnome_ver_str,
            version: "50".into(),
            description: "Thème Catppuccin Mocha, extensions Dash to Dock et Blur-my-Shell préconfigurées.".into(),
            icon: "🔵".into(),
        },
        DesktopEnvInfo {
            id: "cinnamon".into(),
            name: "Cinnamon 6.6".into(),
            version: "6.6".into(),
            description: "Bureau traditionnel ultra-rapide avec barre des tâches, menu classique et fonds d'écran officiels.".into(),
            icon: "🌿".into(),
        },
        DesktopEnvInfo {
            id: "kde".into(),
            name: "KDE Plasma 6".into(),
            version: "6.6".into(),
            description: "Personnalisation extrême, Catppuccin Mocha Lavender et session Wayland moderne.".into(),
            icon: "❄️".into(),
        },
        DesktopEnvInfo {
            id: "cosmic".into(),
            name: "COSMIC Desktop (Alpha)".into(),
            version: "Epoch 1".into(),
            description: "Nouvelle génération développée en Rust par System76 avec fenêtrage dynamique.".into(),
            icon: "🚀".into(),
        },
    ]
}
