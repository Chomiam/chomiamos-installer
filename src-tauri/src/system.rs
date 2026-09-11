use std::process::Command;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use sysinfo::System;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuInfo {
    pub name: String,
    pub vendor: String,
    pub driver_type: String, // "vm", "nvidia", "nvidia-legacy", "amd", "intel"
    pub is_supported: bool,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemPrerequisites {
    pub is_efi: bool,

    // RAM
    pub total_ram_gb: f64,
    pub ram_level: String, // "optimal" (>8GB, vert), "warning" (4-8GB, orange), "error" (<4GB, rouge)
    pub ram_message: String,

    // CPU
    pub cpu_cores: usize,
    pub cpu_model: String,
    pub cpu_level: String, // "optimal" (>=8, vert), "warning" (4-7, orange), "error" (<4, rouge)
    pub cpu_message: String,

    // Disk
    pub max_disk_gb: f64,
    pub has_80gb_disk: bool,
    pub disk_level: String, // "optimal" (>=80GB, vert), "error" (<80GB, rouge)
    pub disk_message: String,

    // GPU
    pub gpu: GpuInfo,

    // Network & Laptop
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DesktopEnvInfo {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    pub icon: String,
}

fn check_is_vm() -> Option<String> {
    // 1. Check systemd-detect-virt
    if let Ok(output) = Command::new("systemd-detect-virt").output() {
        if output.status.success() {
            let virt = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !virt.is_empty() && virt != "none" {
                return Some(virt);
            }
        }
    }

    // 2. Check DMI sysfs
    let dmi_paths = [
        "/sys/class/dmi/id/sys_vendor",
        "/sys/class/dmi/id/product_name",
        "/sys/class/dmi/id/bios_vendor",
    ];
    for p in &dmi_paths {
        if let Ok(val) = fs::read_to_string(p) {
            let lower = val.to_lowercase();
            if lower.contains("qemu")
                || lower.contains("kvm")
                || lower.contains("virtualbox")
                || lower.contains("vmware")
                || lower.contains("innotek")
                || lower.contains("bochs")
                || lower.contains("xen")
                || lower.contains("hyper-v")
            {
                return Some(val.trim().to_string());
            }
        }
    }
    None
}

fn clean_gpu_name(line: &str) -> String {
    if let Some(pos) = line.find(": ") {
        let part = &line[pos + 2..];
        let cleaned = if let Some(rev_pos) = part.rfind(" (rev ") {
            &part[..rev_pos]
        } else {
            part
        };
        cleaned.trim().to_string()
    } else {
        line.trim().to_string()
    }
}

fn is_nvidia_legacy(line: &str) -> bool {
    let lower = line.to_lowercase();
    // Modern RTX or GTX 16xx (Turing or newer)
    if lower.contains("rtx") || lower.contains("1650") || lower.contains("1660") || lower.contains("titan rtx") {
        return false;
    }
    // Older generations: Pascal (10xx), Maxwell (9xx), Kepler (7xx, 6xx), Fermi, Tesla
    if lower.contains("gtx 10")
        || lower.contains("gtx 9")
        || lower.contains("gtx 7")
        || lower.contains("gtx 6")
        || lower.contains("gt 7")
        || lower.contains("gt 6")
        || lower.contains("gt 10")
        || lower.contains("quadro k")
        || lower.contains("quadro m")
        || lower.contains("quadro p")
    {
        return true;
    }
    // Check PCI ID [10de:xxxx]
    if let Some(pos) = lower.find("[10de:") {
        let sub = &lower[pos + 6..];
        if let Some(end) = sub.find(']') {
            let hex_str = &sub[..end];
            if let Ok(dev_id) = u32::from_str_radix(hex_str, 16) {
                // Turing starts around 0x1e00 (TU102/TU104/TU106)
                return dev_id < 0x1e00;
            }
        }
    }
    false
}

pub fn detect_gpu() -> GpuInfo {
    // 1. Virtual machine check
    if let Some(vm_name) = check_is_vm() {
        return GpuInfo {
            name: format!("Machine Virtuelle ({})", vm_name),
            vendor: "Virtual Machine".into(),
            driver_type: "vm".into(),
            is_supported: true,
            detail: "Pilotes invités & accélération 3D Mesa VirtIO / SVGA".into(),
        };
    }

    // 2. lspci check
    if let Ok(output) = Command::new("lspci").args(&["-nn"]).output() {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let mut detected = Vec::new();
            for line in stdout.lines() {
                let lower = line.to_lowercase();
                if lower.contains("vga compatible controller")
                    || lower.contains("3d controller")
                    || lower.contains("display controller")
                {
                    detected.push(line.to_string());
                }
            }

            if !detected.is_empty() {
                // Prioritize NVIDIA dGPU for proper driver selection
                for line in &detected {
                    let lower = line.to_lowercase();
                    if lower.contains("nvidia") || lower.contains("[10de:") {
                        let legacy = is_nvidia_legacy(line);
                        let driver = if legacy { "nvidia-legacy" } else { "nvidia" };
                        let name = clean_gpu_name(line);
                        let detail = if legacy {
                            "Pilote propriétaire NVIDIA Legacy 470 (cartes < GTX 1650)".into()
                        } else {
                            "Pilote propriétaire NVIDIA moderne officiel (RTX / GTX 16xx)".into()
                        };
                        return GpuInfo {
                            name,
                            vendor: "NVIDIA".into(),
                            driver_type: driver.into(),
                            is_supported: true,
                            detail,
                        };
                    }
                }

                // AMD Radeon
                for line in &detected {
                    let lower = line.to_lowercase();
                    if lower.contains("amd")
                        || lower.contains("radeon")
                        || lower.contains("advanced micro devices")
                        || lower.contains("[1002:")
                    {
                        let name = clean_gpu_name(line);
                        return GpuInfo {
                            name,
                            vendor: "AMD".into(),
                            driver_type: "amd".into(),
                            is_supported: true,
                            detail: "Pilote haute performance open-source amdgpu & ROCm".into(),
                        };
                    }
                }

                // Intel
                for line in &detected {
                    let lower = line.to_lowercase();
                    if lower.contains("intel") || lower.contains("[8086:") {
                        let name = clean_gpu_name(line);
                        return GpuInfo {
                            name,
                            vendor: "Intel".into(),
                            driver_type: "intel".into(),
                            is_supported: true,
                            detail: "Pilote Intel Media Driver / Arc & UHD Graphics".into(),
                        };
                    }
                }
            }
        }
    }

    // 3. Sysfs fallback: /sys/bus/pci/devices/
    if let Ok(entries) = fs::read_dir("/sys/bus/pci/devices") {
        for entry in entries.flatten() {
            let class_path = entry.path().join("class");
            if let Ok(class_str) = fs::read_to_string(class_path) {
                let class_trim = class_str.trim();
                if class_trim.starts_with("0x0300")
                    || class_trim.starts_with("0x0302")
                    || class_trim.starts_with("0x0380")
                {
                    let vendor_path = entry.path().join("vendor");
                    let vendor = fs::read_to_string(vendor_path).unwrap_or_default().trim().to_lowercase();
                    let device_path = entry.path().join("device");
                    let device_str = fs::read_to_string(device_path).unwrap_or_default().trim().to_lowercase();

                    if vendor == "0x10de" {
                        let dev_id = u32::from_str_radix(device_str.trim_start_matches("0x"), 16).unwrap_or(0);
                        let legacy = dev_id < 0x1e00;
                        let driver = if legacy { "nvidia-legacy" } else { "nvidia" };
                        return GpuInfo {
                            name: format!("NVIDIA Graphics Card ({})", device_str),
                            vendor: "NVIDIA".into(),
                            driver_type: driver.into(),
                            is_supported: true,
                            detail: if legacy { "Pilote NVIDIA Legacy 470".into() } else { "Pilote NVIDIA Moderne".into() },
                        };
                    } else if vendor == "0x1002" {
                        return GpuInfo {
                            name: format!("AMD Radeon Graphics ({})", device_str),
                            vendor: "AMD".into(),
                            driver_type: "amd".into(),
                            is_supported: true,
                            detail: "Pilote amdgpu / ROCm".into(),
                        };
                    } else if vendor == "0x8086" {
                        return GpuInfo {
                            name: format!("Intel Graphics ({})", device_str),
                            vendor: "Intel".into(),
                            driver_type: "intel".into(),
                            is_supported: true,
                            detail: "Pilote Intel Media".into(),
                        };
                    } else if vendor == "0x1af4" || vendor == "0x15ad" || vendor == "0x80ee" || vendor == "0x1234" {
                        return GpuInfo {
                            name: "Machine Virtuelle (VM Graphics)".into(),
                            vendor: "Virtual Machine".into(),
                            driver_type: "vm".into(),
                            is_supported: true,
                            detail: "Pilote invité VM / Mesa".into(),
                        };
                    }
                }
            }
        }
    }

    // Default fallback
    GpuInfo {
        name: "Carte Graphique Standard".into(),
        vendor: "Standard".into(),
        driver_type: "amd".into(),
        is_supported: true,
        detail: "Pilote standard Mesa / Gallium".into(),
    }
}

pub fn check_prerequisites() -> SystemPrerequisites {
    let mut sys = System::new_all();
    sys.refresh_all();

    let is_efi = Path::new("/sys/firmware/efi").exists();

    // 1. RAM check: > 8 GB vert, 4-8 GB orange, < 4 GB rouge
    let total_ram_gb = (sys.total_memory() as f64) / (1024.0 * 1024.0 * 1024.0);
    let total_ram_gb_rounded = (total_ram_gb * 10.0).round() / 10.0;
    let (ram_level, ram_message) = if total_ram_gb > 8.0 {
        ("optimal".to_string(), format!("{:.1} Go installés (Optimal, > 8 Go)", total_ram_gb_rounded))
    } else if total_ram_gb >= 4.0 {
        ("warning".to_string(), format!("{:.1} Go installés (Minimum atteint, 8 Go recommandés)", total_ram_gb_rounded))
    } else {
        ("error".to_string(), format!("{:.1} Go installés (Insuffisant, minimum 4 Go requis)", total_ram_gb_rounded))
    };

    // 2. CPU check: >= 8 cores vert (conseillé), 4-7 cores orange (mini), < 4 cores rouge
    let cpu_cores = sys.cpus().len();
    let cpu_model = sys
        .cpus()
        .first()
        .map(|c| c.brand().trim().to_string())
        .unwrap_or_else(|| "Processeur x86_64".to_string());

    let (cpu_level, cpu_message) = if cpu_cores >= 8 {
        ("optimal".to_string(), format!("{} cœurs (Optimal, ≥ 8 cœurs conseillés)", cpu_cores))
    } else if cpu_cores >= 4 {
        ("warning".to_string(), format!("{} cœurs (Minimum 4 cœurs atteint, 8 conseillés)", cpu_cores))
    } else {
        ("error".to_string(), format!("{} cœurs (Insuffisant, 4 cœurs minimum requis)", cpu_cores))
    };

    // 3. Disk check: au moins un disque >= 80 Go pour pavé vert
    let disks = list_disks();
    let mut max_disk_gb: f64 = 0.0;
    let mut max_disk_model = String::new();
    for d in &disks {
        if d.size_gb > max_disk_gb {
            max_disk_gb = d.size_gb;
            max_disk_model = if d.model.is_empty() { d.name.clone() } else { d.model.clone() };
        }
    }
    let has_80gb_disk = max_disk_gb >= 80.0;
    let (disk_level, disk_message) = if has_80gb_disk {
        ("optimal".to_string(), format!("{:.0} Go disponibles sur {} (≥ 80 Go requis)", max_disk_gb, max_disk_model))
    } else if max_disk_gb > 0.0 {
        ("error".to_string(), format!("Disque max de {:.0} Go insuffisant (minimum 80 Go requis)", max_disk_gb))
    } else {
        ("error".to_string(), "Aucun disque de stockage détecté".to_string())
    };

    // 4. GPU check
    let gpu = detect_gpu();

    // 5. Internet check
    let has_internet = std::net::TcpStream::connect_timeout(
        &"1.1.1.1:53".parse().unwrap(),
        std::time::Duration::from_millis(1500),
    )
    .is_ok();

    // 6. Battery / Laptop
    let power_supply = Path::new("/sys/class/power_supply");
    let mut is_laptop = false;
    let mut battery_ok = true;

    if power_supply.exists() {
        if let Ok(entries) = fs::read_dir(power_supply) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("BAT") {
                    is_laptop = true;
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

    SystemPrerequisites {
        is_efi,
        total_ram_gb: total_ram_gb_rounded,
        ram_level,
        ram_message,
        cpu_cores,
        cpu_model,
        cpu_level,
        cpu_message,
        max_disk_gb: (max_disk_gb * 10.0).round() / 10.0,
        has_80gb_disk,
        disk_level,
        disk_message,
        gpu,
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
                continue;
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
    ]
}

pub fn get_current_timezone() -> String {
    if let Ok(output) = Command::new("timedatectl").output() {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            for line in stdout.lines() {
                if line.contains("Time zone:") {
                    let parts: Vec<&str> = line.split(':').collect();
                    if parts.len() >= 2 {
                        let tz = parts[1].split_whitespace().next().unwrap_or("").trim();
                        if !tz.is_empty() {
                            return tz.to_string();
                        }
                    }
                }
            }
        }
    }

    if let Ok(target) = fs::read_link("/etc/localtime") {
        let path_str = target.to_string_lossy().to_string();
        if let Some(pos) = path_str.find("zoneinfo/") {
            let tz = &path_str[pos + 9..];
            if !tz.is_empty() {
                return tz.to_string();
            }
        }
    }

    "Europe/Paris".to_string()
}

pub fn get_desktop_environments() -> Vec<DesktopEnvInfo> {
    let gnome_ver_str = if let Ok(output) = Command::new("gnome-shell").arg("--version").output() {
        let text = String::from_utf8_lossy(&output.stdout);
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
