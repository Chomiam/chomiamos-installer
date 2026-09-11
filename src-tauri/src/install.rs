use std::path::Path;
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter};

use crate::config::{InstallerSelections, generate_vars_nix};
use crate::swap::create_instant_swapfile;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallProgress {
    pub percent: u32,
    pub step: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallFinished {
    pub success: bool,
    pub error: Option<String>,
}

fn is_root_user() -> bool {
    if let Ok(output) = Command::new("id").arg("-u").output() {
        let out_str = String::from_utf8_lossy(&output.stdout);
        return out_str.trim() == "0";
    }
    false
}

fn hash_user_password(password: &str) -> Result<String, String> {
    let mut child = Command::new("openssl")
        .args(["passwd", "-6", "-stdin"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn openssl: {}", e))?;

    if let Some(mut stdin) = child.stdin.take() {
        use std::io::Write;
        let _ = stdin.write_all(password.as_bytes());
    }

    let output = child.wait_with_output().map_err(|e| format!("Failed waiting for openssl: {}", e))?;
    if output.status.success() {
        let hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(hash)
    } else {
        Err("Failed to hash password with openssl".into())
    }
}

pub async fn execute_installation(app: AppHandle, s: InstallerSelections, dry_run: bool) -> Result<(), String> {
    let emit_progress = |percent: u32, step: &str, msg: &str| {
        let _ = app.emit("install_progress", InstallProgress {
            percent,
            step: step.into(),
            message: msg.into(),
        });
    };

    let emit_log = |line: &str| {
        let _ = app.emit("install_log", line.to_string());
    };

    emit_log("=== Démarrage de l'installation de ChomiamOS Gaming Edition ===");
    emit_log(&format!("Disque cible : {}", s.target_disk));
    emit_log(&format!("Bureau : {}", s.desktop_env));
    emit_log(&format!("Utilisateur : {} (Machine: {})", s.username, s.hostname));

    let effective_dry_run = dry_run || !is_root_user();
    if effective_dry_run {
        emit_log("[INFO] Mode simulation activé (dry-run ou droits non-root). Les commandes destructives seront simulées.");
    }

    // --- STEP 1: Partitioning ---
    emit_progress(10, "Partitionnement du disque", &format!("Configuration GPT sur {}", s.target_disk));
    emit_log(&format!("Création de la table de partitions GPT sur {}", s.target_disk));

    let is_nvme_or_mmc = s.target_disk.chars().last().map_or(false, |c| c.is_ascii_digit());
    let (efi_part, root_part) = if is_nvme_or_mmc {
        (format!("{}p1", s.target_disk), format!("{}p2", s.target_disk))
    } else {
        (format!("{}1", s.target_disk), format!("{}2", s.target_disk))
    };

    if !effective_dry_run {
        let _ = Command::new("umount").args(["-R", "/mnt"]).status();
        let _ = Command::new("swapoff").args(["-a"]).status();

        let wipe = Command::new("wipefs").args(["-a", "-f", &s.target_disk]).status();
        if let Err(e) = wipe {
            emit_log(&format!("[WARN] wipefs: {}", e));
        }

        let parted_gpt = Command::new("parted").args(["-s", &s.target_disk, "mklabel", "gpt"]).status();
        if parted_gpt.map_or(false, |s| !s.success()) {
            return Err(format!("Échec de création du label GPT sur {}", s.target_disk));
        }

        // ESP 1024 MiB
        let _ = Command::new("parted").args(["-s", &s.target_disk, "mkpart", "ESP", "fat32", "1MiB", "1024MiB"]).status();
        let _ = Command::new("parted").args(["-s", &s.target_disk, "set", "1", "esp", "on"]).status();

        // Root ext4 reste du disque
        let _ = Command::new("parted").args(["-s", &s.target_disk, "mkpart", "root", "ext4", "1024MiB", "100%"]).status();

        // Informer le noyau
        let _ = Command::new("partprobe").arg(&s.target_disk).status();
        tokio::time::sleep(tokio::time::Duration::from_millis(1500)).await;

        // Formater ESP
        emit_log(&format!("Formatage de la partition EFI en FAT32 ({})", efi_part));
        let mkfs_fat = Command::new("mkfs.fat").args(["-F", "32", "-n", "BOOT", &efi_part]).status();
        if mkfs_fat.map_or(false, |s| !s.success()) {
            return Err(format!("Échec formatage FAT32 sur {}", efi_part));
        }

        // Formater Root ext4
        emit_log(&format!("Formatage de la partition racine en ext4 ({})", root_part));
        let mkfs_ext4 = Command::new("mkfs.ext4").args(["-F", "-L", "nixos", &root_part]).status();
        if mkfs_ext4.map_or(false, |s| !s.success()) {
            return Err(format!("Échec formatage ext4 sur {}", root_part));
        }
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(800)).await;
        emit_log(&format!("[DRY-RUN] Table GPT créée, {} (EFI 1Go) et {} (Root ext4)", efi_part, root_part));
    }

    // --- STEP 2: Mounting ---
    emit_progress(25, "Montage des volumes", "Montage de la racine sur /mnt et ESP sur /mnt/boot");
    if !effective_dry_run {
        let _ = Command::new("mkdir").args(["-p", "/mnt"]).status();
        let mnt_root = Command::new("mount").args([&root_part, "/mnt"]).status();
        if mnt_root.map_or(false, |s| !s.success()) {
            return Err("Échec du montage de /mnt".into());
        }

        let _ = Command::new("mkdir").args(["-p", "/mnt/boot"]).status();
        let mnt_boot = Command::new("mount").args([&efi_part, "/mnt/boot"]).status();
        if mnt_boot.map_or(false, |s| !s.success()) {
            return Err("Échec du montage de /mnt/boot".into());
        }
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(600)).await;
        emit_log("[DRY-RUN] Volumes montés sous /mnt et /mnt/boot");
    }

    // --- STEP 3: Instant Swapfile ---
    if s.swap_size_mb > 0 {
        emit_progress(35, "Création du Swap ultra-rapide", &format!("Allocation de {} Mo via posix_fallocate", s.swap_size_mb));
        emit_log(&format!("Préallocation instantanée du fichier de swap ({} Mo)...", s.swap_size_mb));
        if !effective_dry_run {
            let _ = Command::new("mkdir").args(["-p", "/mnt/var"]).status();
            let swap_path = Path::new("/mnt/var/swapfile");
            if let Err(e) = create_instant_swapfile(swap_path, s.swap_size_mb) {
                emit_log(&format!("[WARN] Erreur création swapfile: {}. Poursuite...", e));
            } else {
                let _ = Command::new("chmod").args(["600", "/mnt/var/swapfile"]).status();
                let _ = Command::new("mkswap").arg("/mnt/var/swapfile").status();
                let _ = Command::new("swapon").arg("/mnt/var/swapfile").status();
                emit_log("Swapfile activé avec succès.");
            }
        } else {
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
            emit_log(&format!("[DRY-RUN] Swap {} Mo alloué en 0.4 ms via posix_fallocate", s.swap_size_mb));
        }
    }

    // --- STEP 4: Configuration Generation ---
    emit_progress(45, "Génération de la configuration NixOS", "Détection matérielle et écriture de vars.nix");
    emit_log("Génération de hardware-configuration.nix...");

    let target_nixos = if !effective_dry_run {
        Path::new("/mnt/etc/nixos")
    } else {
        Path::new("/tmp/chomiamos-install-preview/etc/nixos")
    };
    let _ = std::fs::create_dir_all(target_nixos);

    if !effective_dry_run {
        let _ = Command::new("nixos-generate-config").args(["--root", "/mnt"]).status();
        emit_log("Copie du framework NixOS ChomiamOS depuis l'environnement Live...");

        let live_etc = Path::new("/etc/nixos");
        if live_etc.exists() {
            let _ = Command::new("cp").args(["-r", "--no-clobber", "/etc/nixos/modules", "/mnt/etc/nixos/"]).status();
            let _ = Command::new("cp").args(["-r", "--no-clobber", "/etc/nixos/hosts", "/mnt/etc/nixos/"]).status();
            let _ = Command::new("cp").args(["-r", "--no-clobber", "/etc/nixos/wallpapers", "/mnt/etc/nixos/"]).status();
            let _ = Command::new("cp").args(["-n", "/etc/nixos/flake.nix", "/mnt/etc/nixos/"]).status();
            let _ = Command::new("cp").args(["-n", "/etc/nixos/flake.lock", "/mnt/etc/nixos/"]).status();
        }

        let nm_src = Path::new("/etc/NetworkManager/system-connections");
        if nm_src.is_dir() {
            let nm_dest = Path::new("/mnt/etc/NetworkManager/system-connections");
            let _ = std::fs::create_dir_all(nm_dest);
            let _ = Command::new("cp").args(["-r", "/etc/NetworkManager/system-connections/.", "/mnt/etc/NetworkManager/system-connections/"]).status();
            emit_log("Profils réseau Wi-Fi / Ethernet préservés pour la première session.");
        }
    }

    let hashed_pw = if let Some(ref pw) = s.password {
        if !pw.is_empty() {
            match hash_user_password(pw) {
                Ok(h) => Some(h),
                Err(e) => {
                    emit_log(&format!("[WARN] Erreur hachage mot de passe: {}", e));
                    None
                }
            }
        } else {
            None
        }
    } else {
        None
    };

    let gpu_driver = if Path::new("/proc/driver/nvidia").exists() {
        "nvidia"
    } else {
        "amd"
    };

    let vars_content = generate_vars_nix(&s, hashed_pw.as_deref(), gpu_driver);
    let vars_file = target_nixos.join("vars.nix");
    if let Err(e) = std::fs::write(&vars_file, vars_content) {
        emit_log(&format!("[ERR] Impossible d'écrire vars.nix: {}", e));
        return Err(format!("Échec d'écriture de vars.nix: {}", e));
    }
    emit_log(&format!("Fichier vars.nix généré dans {}", vars_file.display()));

    // --- STEP 5: nixos-install ---
    emit_progress(60, "Installation du système ChomiamOS", "Compilation et déploiement des paquets NixOS...");
    emit_log("Lancement de nixos-install...");

    if !effective_dry_run {
        let mut child = Command::new("nixos-install")
            .args([
                "--no-root-passwd",
                "--option", "sandbox", "false",
                "--flake", "/mnt/etc/nixos#default",
                "--root", "/mnt",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Impossible de lancer nixos-install: {}", e))?;

        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            let mut current_pct = 60u32;
            for line in reader.lines() {
                if let Ok(l) = line {
                    emit_log(&l);
                    if current_pct < 95 && l.contains("copying path") {
                        current_pct = (current_pct + 1).min(95);
                        emit_progress(current_pct, "Installation de ChomiamOS...", &l);
                    }
                }
            }
        }

        let status = child.wait().map_err(|e| format!("Erreur attente nixos-install: {}", e))?;
        if !status.success() {
            return Err("nixos-install a échoué.".into());
        }
    } else {
        let mock_steps = [
            "Configuration de l'environnement initrd...",
            "Déploiement du noyau Linux 6.12 CachyOS...",
            "Installation de Systemd et modules matériels...",
            "Configuration de l'environnement de bureau...",
            "Installation de Steam, Lutris et GameMode...",
            "Intégration du thème Catppuccin Mocha...",
            "Finalisation des profils utilisateurs...",
        ];

        for (i, step) in mock_steps.iter().enumerate() {
            tokio::time::sleep(tokio::time::Duration::from_millis(600)).await;
            let pct = 60 + (i as u32 + 1) * 5;
            emit_log(&format!("[SIMULATION] {}", step));
            emit_progress(pct, "Installation de ChomiamOS...", step);
        }
    }

    // --- STEP 6: Finalization ---
    emit_progress(100, "Installation terminée !", "ChomiamOS Gaming Edition est prêt à être démarré.");
    emit_log("=== Synchronisation et démontage propre des volumes ===");
    if !effective_dry_run {
        let _ = Command::new("sync").status();
        let _ = Command::new("umount").args(["-R", "/mnt"]).status();
    }
    emit_log("Félicitations ! L'installation de ChomiamOS est terminée avec succès.");

    let _ = app.emit("install_finished", InstallFinished {
        success: true,
        error: None,
    });

    Ok(())
}
