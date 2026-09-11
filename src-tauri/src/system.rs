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
pub struct KeyboardLayoutInfo {
    pub code: String,
    pub name: String,
    pub variants: Vec<String>,
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
            code: "fr".into(),
            name: "Français (AZERTY)".into(),
            variants: vec!["".into(), "oss".into(), "mac".into(), "bepo".into()],
        },
        KeyboardLayoutInfo {
            code: "us".into(),
            name: "Anglais US (QWERTY)".into(),
            variants: vec!["".into(), "intl".into(), "altgr-intl".into(), "dvorak".into()],
        },
        KeyboardLayoutInfo {
            code: "de".into(),
            name: "Allemand (QWERTZ)".into(),
            variants: vec!["".into(), "mac".into(), "deadgraveacute".into()],
        },
        KeyboardLayoutInfo {
            code: "es".into(),
            name: "Espagnol".into(),
            variants: vec!["".into(), "cat".into(), "mac".into()],
        },
        KeyboardLayoutInfo {
            code: "it".into(),
            name: "Italien".into(),
            variants: vec!["".into(), "mac".into()],
        },
        KeyboardLayoutInfo {
            code: "gb".into(),
            name: "Anglais UK".into(),
            variants: vec!["".into(), "extd".into(), "mac".into()],
        },
        KeyboardLayoutInfo {
            code: "be".into(),
            name: "Belge".into(),
            variants: vec!["".into(), "oss".into()],
        },
        KeyboardLayoutInfo {
            code: "ca".into(),
            name: "Canadien Français".into(),
            variants: vec!["".into(), "fr-dvorak".into(), "fr-legacy".into()],
        },
        KeyboardLayoutInfo {
            code: "ch".into(),
            name: "Suisse".into(),
            variants: vec!["fr".into(), "de".into()],
        },
    ]
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
