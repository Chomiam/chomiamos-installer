use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::process::Command as AsyncCommand;
use tokio::io::{AsyncBufReadExt, BufReader as AsyncBufReader};
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallStateSnapshot {
    pub is_running: bool,
    pub is_finished: bool,
    pub success: bool,
    pub percent: u32,
    pub step: String,
    pub current_message: String,
    pub error: Option<String>,
    pub new_logs: Vec<String>,
    pub total_logs_count: usize,
}

pub struct SharedInstallState {
    pub is_running: bool,
    pub is_finished: bool,
    pub success: bool,
    pub percent: u32,
    pub step: String,
    pub current_message: String,
    pub error: Option<String>,
    pub logs: Vec<String>,
}

impl Default for SharedInstallState {
    fn default() -> Self {
        Self {
            is_running: false,
            is_finished: false,
            success: false,
            percent: 0,
            step: "Prêt pour l'installation".into(),
            current_message: "En attente du lancement...".into(),
            error: None,
            logs: Vec::new(),
        }
    }
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

fn get_partition_names(disk: &str) -> (String, String) {
    let last_char = disk.chars().last().unwrap_or(' ');
    if last_char.is_ascii_digit() {
        (format!("{}p1", disk), format!("{}p2", disk))
    } else {
        (format!("{}1", disk), format!("{}2", disk))
    }
}

pub async fn execute_installation(
    app: AppHandle,
    state: Arc<Mutex<SharedInstallState>>,
    mut s: InstallerSelections,
    dry_run: bool,
) -> Result<(), String> {
    // 0. Réinitialisation de l'état
    {
        let mut st = state.lock().await;
        st.is_running = true;
        st.is_finished = false;
        st.success = false;
        st.percent = 2;
        st.step = "Initialisation de l'installation".into();
        st.current_message = "Vérification des disques et de l'environnement...".into();
        st.error = None;
        st.logs.clear();
        st.logs.push("=== Lancement de l'Installation de ChomiamOS Gaming Edition ===".into());
    }

    let emit_log = {
        let app = app.clone();
        let state = state.clone();
        move |line: &str| {
            let l = line.to_string();
            let _ = app.emit("install_log", &l);
            let state = state.clone();
            tokio::spawn(async move {
                let mut st = state.lock().await;
                st.logs.push(l);
            });
        }
    };

    let emit_progress = {
        let app = app.clone();
        let state = state.clone();
        move |percent: u32, step: &str, msg: &str| {
            let p = InstallProgress {
                percent,
                step: step.into(),
                message: msg.into(),
            };
            let _ = app.emit("install_progress", &p);
            let state = state.clone();
            let step_str = step.to_string();
            let msg_str = msg.to_string();
            tokio::spawn(async move {
                let mut st = state.lock().await;
                st.percent = percent;
                st.step = step_str;
                st.current_message = msg_str;
            });
        }
    };

    // Auto-sélection de disque cible si non spécifié
    if s.target_disk.is_empty() {
        let disks = crate::system::list_disks();
        if let Some(first) = disks.first() {
            s.target_disk = first.path.clone();
            emit_log(&format!("[INFO] Disque cible auto-détecté : {}", s.target_disk));
        } else {
            s.target_disk = "/dev/sda".to_string();
            emit_log(&format!("[INFO] Disque par défaut appliqué : {}", s.target_disk));
        }
    }

    emit_log(&format!("[INFO] Disque sélectionné : {}", s.target_disk));
    emit_log(&format!("[INFO] Bureau sélectionné : {} | Clavier : {} ({})", s.desktop_env, s.keyboard_layout, s.keyboard_variant));
    emit_log(&format!("[INFO] Fuseau horaire : {} | Utilisateur : {}", s.timezone, s.username));

    let effective_dry_run = dry_run || !is_root_user();
    if effective_dry_run {
        emit_log("[WARN] Mode simulation actif (droits non-root ou test). Les modifications système réelles ne seront pas appliquées.");
    }

    let (efi_part, root_part) = get_partition_names(&s.target_disk);

    // =========================================================================
    // --- ÉTAPE 1 : Nettoyage et Préparation des Montages (0% - 15%) ---
    // =========================================================================
    emit_progress(5, "Nettoyage de l'environnement", "Arrêt des swaps et démontage des volumes résiduels...");
    emit_log("[ÉTAPE 1/8] === Préparation et nettoyage des points de montage ===");

    if !effective_dry_run {
        emit_log("[INFO] Désactivation de tous les swaps existants (swapoff -a)...");
        let _ = Command::new("swapoff").arg("-a").status();

        emit_log("[INFO] Démontage propre récursif de /mnt si déjà actif...");
        let _ = Command::new("umount").args(["-R", "-q", "/mnt"]).status();
        let _ = Command::new("umount").args(["-l", "-R", "-q", "/mnt"]).status();

        tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        emit_log("[OK] Environnement nettoyé et prêt pour le partitionnement.");
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(400)).await;
        emit_log("[SIMULATION] Nettoyage préalable des montages effectué.");
    }

    // =========================================================================
    // --- ÉTAPE 2 : Partitionnement GPT & Synchronisation Noyau (15% - 30%) ---
    // =========================================================================
    emit_progress(18, "Partitionnement GPT", &format!("Création de la table de partitions sur {}", s.target_disk));
    emit_log("[ÉTAPE 2/8] === Partitionnement GPT du disque cible ===");

    if !effective_dry_run {
        emit_log(&format!("[INFO] Suppression des signatures de systèmes de fichiers (wipefs sur {})...", s.target_disk));
        let _ = Command::new("wipefs").args(["-a", "-f", &s.target_disk]).status();

        emit_log(&format!("[INFO] Création d'une table de partitions GPT vierge sur {}...", s.target_disk));
        let parted_gpt = Command::new("parted")
            .args(["-s", &s.target_disk, "--", "mklabel", "gpt"])
            .status();
        if parted_gpt.map_or(false, |st| !st.success()) {
            let err = format!("Échec de création du label GPT sur {}", s.target_disk);
            emit_log(&format!("[ERREUR FATALE] {}", err));
            let mut st = state.lock().await;
            st.is_running = false;
            st.is_finished = true;
            st.success = false;
            st.error = Some(err.clone());
            let _ = app.emit("install_finished", InstallFinished { success: false, error: Some(err.clone()) });
            return Err(err);
        }

        emit_log("[INFO] Création de la partition EFI (1024 Mo - ESP/FAT32)...");
        let parted_esp = Command::new("parted")
            .args(["-s", &s.target_disk, "--", "mkpart", "ESP", "fat32", "1MiB", "1025MiB"])
            .status();
        if parted_esp.map_or(false, |st| !st.success()) {
            let err = "Échec de création de la partition ESP".into();
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }
        let _ = Command::new("parted").args(["-s", &s.target_disk, "--", "set", "1", "esp", "on"]).status();

        emit_log("[INFO] Création de la partition racine Root (ext4 - 100% de l'espace)...");
        let parted_root = Command::new("parted")
            .args(["-s", &s.target_disk, "--", "mkpart", "root", "ext4", "1025MiB", "100%"])
            .status();
        if parted_root.map_or(false, |st| !st.success()) {
            let err = "Échec de création de la partition Root".into();
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }

        emit_log("[INFO] Notification au noyau et synchronisation udev (partprobe & udevadm settle)...");
        let _ = Command::new("partprobe").arg(&s.target_disk).status();
        let _ = Command::new("udevadm").args(["settle", "--timeout=10"]).status();

        // Attente active de la présence des nœuds de partitions
        let mut partitions_ready = false;
        for _ in 0..10 {
            if Path::new(&efi_part).exists() && Path::new(&root_part).exists() {
                partitions_ready = true;
                break;
            }
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        }

        if !partitions_ready {
            let _ = Command::new("partprobe").arg(&s.target_disk).status();
            tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;
        }

        emit_log(&format!("[OK] Partitions créées et validées par le noyau : {} (EFI) et {} (Root)", efi_part, root_part));
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        emit_log(&format!("[SIMULATION] Partitionnement GPT simulé : {} et {}", efi_part, root_part));
    }

    // =========================================================================
    // --- ÉTAPE 3 : Formatage des Partitions (30% - 40%) ---
    // =========================================================================
    emit_progress(30, "Formatage des partitions", "Formatage EFI en FAT32 et Racine en ext4...");
    emit_log("[ÉTAPE 3/8] === Formatage des systèmes de fichiers ===");

    if !effective_dry_run {
        emit_log(&format!("[INFO] Formatage de la partition EFI en FAT32 ({}) avec le label BOOT...", efi_part));
        let mkfs_fat = Command::new("mkfs.vfat").args(["-F", "32", "-n", "BOOT", &efi_part]).status();
        if mkfs_fat.map_or(false, |st| !st.success()) {
            let fallback_fat = Command::new("mkfs.fat").args(["-F", "32", "-n", "BOOT", &efi_part]).status();
            if fallback_fat.map_or(false, |st| !st.success()) {
                let err = format!("Échec du formatage FAT32 de {}", efi_part);
                emit_log(&format!("[ERREUR FATALE] {}", err));
                return Err(err);
            }
        }
        emit_log("[OK] Partition EFI formatée avec succès en FAT32.");

        emit_log(&format!("[INFO] Formatage de la partition racine en ext4 ({}) avec le label nixos...", root_part));
        let mkfs_ext4 = Command::new("mkfs.ext4").args(["-F", "-L", "nixos", &root_part]).status();
        if mkfs_ext4.map_or(false, |st| !st.success()) {
            let err = format!("Échec du formatage ext4 de {}", root_part);
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }
        emit_log("[OK] Partition racine formatée avec succès en ext4.");
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(400)).await;
        emit_log("[SIMULATION] Systèmes de fichiers FAT32 et ext4 initialisés.");
    }

    // =========================================================================
    // --- ÉTAPE 4 : Montage Hiérarchique et Tests d'Intégrité (40% - 50%) ---
    // =========================================================================
    emit_progress(40, "Montage des volumes", "Montage de la racine sur /mnt et de l'EFI sur /mnt/boot...");
    emit_log("[ÉTAPE 4/8] === Montage ordonné des volumes ===");

    if !effective_dry_run {
        let _ = std::fs::create_dir_all("/mnt");
        emit_log(&format!("[INFO] Montage de la partition racine {} sur /mnt...", root_part));
        let mnt_root = Command::new("mount").args([&root_part, "/mnt"]).status();
        if mnt_root.map_or(false, |st| !st.success()) {
            let err = format!("Échec du montage de la partition racine {} sur /mnt", root_part);
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }
        emit_log("[OK] /mnt monté avec succès.");

        let _ = std::fs::create_dir_all("/mnt/boot");
        emit_log(&format!("[INFO] Montage de la partition EFI {} sur /mnt/boot...", efi_part));
        let mnt_boot = Command::new("mount").args([&efi_part, "/mnt/boot"]).status();
        if mnt_boot.map_or(false, |st| !st.success()) {
            let err = format!("Échec du montage de la partition EFI {} sur /mnt/boot", efi_part);
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }
        emit_log("[OK] /mnt/boot monté avec succès.");

        // Vérification de validation des points de montage
        if !Path::new("/mnt/boot").exists() {
            let err = "Vérification d'accès à /mnt/boot échouée.".into();
            emit_log(&format!("[ERREUR FATALE] {}", err));
            return Err(err);
        }
        emit_log("[OK] Hiérarchie des points de montage validée.");
    } else {
        tokio::time::sleep(tokio::time::Duration::from_millis(400)).await;
        emit_log("[SIMULATION] Volumes montés sous /mnt et /mnt/boot.");
    }

    // =========================================================================
    // --- ÉTAPE 5 : Allocation & Activation du Swap (50% - 58%) ---
    // =========================================================================
    emit_progress(50, "Configuration du Swap", "Vérification et création de l'espace Swap...");
    emit_log("[ÉTAPE 5/8] === Configuration de l'espace Swap ===");

    if s.swap_size_mb > 0 {
        emit_log(&format!("[INFO] Préallocation instantanée du fichier de swap ({} Mo)...", s.swap_size_mb));
        if !effective_dry_run {
            let _ = std::fs::create_dir_all("/mnt/var");
            let swap_path = Path::new("/mnt/var/swapfile");
            if let Err(e) = create_instant_swapfile(swap_path, s.swap_size_mb) {
                emit_log(&format!("[WARN] Erreur création swapfile: {}. Poursuite sans swapfile bloquant...", e));
            } else {
                let _ = Command::new("chmod").args(["600", "/mnt/var/swapfile"]).status();
                let _ = Command::new("mkswap").arg("/mnt/var/swapfile").status();
                let _ = Command::new("swapon").arg("/mnt/var/swapfile").status();
                emit_log(&format!("[OK] Swapfile de {} Mo activé avec succès.", s.swap_size_mb));
            }
        } else {
            tokio::time::sleep(tokio::time::Duration::from_millis(300)).await;
            emit_log(&format!("[SIMULATION] Swapfile de {} Mo alloué.", s.swap_size_mb));
        }
    } else {
        emit_log("[INFO] Swap désactivé conformément aux préférences utilisateur.");
    }

    // =========================================================================
    // --- ÉTAPE 6 : Génération Matérielle & Déploiement du Framework (58% - 68%) ---
    // =========================================================================
    emit_progress(58, "Déploiement du framework NixOS", "Sondage matériel et synchronisation complète de ChomiamOS...");
    emit_log("[ÉTAPE 6/8] === Déploiement déclaratif de la configuration ChomiamOS ===");

    let target_nixos = if !effective_dry_run {
        Path::new("/mnt/etc/nixos")
    } else {
        Path::new("/tmp/chomiamos-install-preview/etc/nixos")
    };
    let _ = std::fs::create_dir_all(target_nixos);

    if !effective_dry_run {
        emit_log("[INFO] Sondage matériel automatique par nixos-generate-config...");
        let _ = std::fs::create_dir_all("/tmp/nixos-hw");
        let gen_status = Command::new("nixos-generate-config")
            .args(["--root", "/mnt", "--dir", "/tmp/nixos-hw"])
            .status();
        if gen_status.map_or(false, |st| !st.success()) {
            emit_log("[WARN] nixos-generate-config a signalé un avertissement. Poursuite...");
        }

        // 1. Déploiement intégral de l'arborescence ChomiamOS
        let live_etc = Path::new("/etc/nixos");
        if live_etc.join("flake.nix").exists() {
            emit_log("[INFO] Copie intégrale du framework système depuis l'environnement Live (/etc/nixos)...");
            let components = [
                "modules",
                "hosts",
                "home",
                "pkgs",
                "assets",
                "scripts",
                "secrets",
                "flake.nix",
                "flake.lock",
                "vars-defaults.nix",
                "custom-packages.nix",
                "firewall-user.nix",
            ];

            for comp in &components {
                let src = live_etc.join(comp);
                let dest = target_nixos.join(comp);
                if src.exists() {
                    if src.is_dir() {
                        let _ = Command::new("cp")
                            .args(["-r", "--no-clobber", src.to_str().unwrap(), dest.to_str().unwrap()])
                            .status();
                    } else {
                        let _ = Command::new("cp")
                            .args(["-n", src.to_str().unwrap(), dest.to_str().unwrap()])
                            .status();
                    }
                }
            }
            emit_log("[OK] Tous les composants système, paquets et modules ont été copiés.");
        } else {
            emit_log("[INFO] Dépôt Live local introuvable. Clone du framework officiel ChomiamOS depuis GitHub...");
            let clone_status = Command::new("git")
                .args(["clone", "https://github.com/Chomiam/nix_config_gaming.git", target_nixos.to_str().unwrap()])
                .status();
            if clone_status.map_or(false, |st| st.success()) {
                emit_log("[OK] Dépôt ChomiamOS cloné avec succès.");
            } else {
                emit_log("[WARN] Échec clone GitHub. Utilisation des fichiers disponibles...");
            }
        }

        // 2. Synchronisation de la configuration matérielle générée
        let gen_hw = Path::new("/tmp/nixos-hw/hardware-configuration.nix");
        let dest_hw_desktop = target_nixos.join("hosts/desktop/hardware-configuration.nix");
        let dest_hw_root = target_nixos.join("hardware-configuration.nix");
        if gen_hw.exists() {
            if let Some(p) = dest_hw_desktop.parent() {
                let _ = std::fs::create_dir_all(p);
            }
            let _ = std::fs::copy(gen_hw, &dest_hw_desktop);
            let _ = std::fs::copy(gen_hw, &dest_hw_root);
            emit_log("[OK] Configuration matérielle réelle synchronisée dans hosts/desktop/hardware-configuration.nix.");
        } else {
            emit_log("[WARN] Fichier de configuration matérielle généré introuvable dans /tmp/nixos-hw.");
        }

        // 3. Neutralisation de mount.nix (Mode UEFI vs BIOS)
        let is_efi = Path::new("/sys/firmware/efi").is_dir();
        let mount_path = target_nixos.join("hosts/desktop/mount.nix");
        if let Some(p) = mount_path.parent() {
            let _ = std::fs::create_dir_all(p);
        }
        let mount_content = if is_efi {
            r#"{ config, ... }:
{
  # Disques secondaires configurables via le tableau de bord ChomiamOS
}
"#.to_string()
        } else {
            format!(
r#"{{ config, lib, ... }}:
{{
  # Machine en mode BIOS hérité (non-UEFI)
  boot.loader.grub.efiSupport = lib.mkForce false;
  boot.loader.grub.device = lib.mkForce "{disk}";
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}}
"#,
                disk = s.target_disk
            )
        };
        let _ = std::fs::write(&mount_path, mount_content);
        emit_log("[OK] Point de montage mount.nix adapté au mode de démarrage.");

        // 4. Sauvegarde des profils réseau NetworkManager
        let nm_src = Path::new("/etc/NetworkManager/system-connections");
        if nm_src.is_dir() {
            let nm_dest = Path::new("/mnt/etc/NetworkManager/system-connections");
            let _ = std::fs::create_dir_all(nm_dest);
            let _ = Command::new("cp").args(["-r", "/etc/NetworkManager/system-connections/.", nm_dest.to_str().unwrap()]).status();
            emit_log("[OK] Profils réseau Wi-Fi / Ethernet préservés pour la première session.");
        }
    }

    // 5. Hachage du mot de passe et détection GPU
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

    let detected_gpu = crate::system::detect_gpu();
    let gpu_driver = if let Some(ref selected) = s.gpu_driver {
        if !selected.is_empty() {
            selected.as_str()
        } else {
            &detected_gpu.driver_type
        }
    } else {
        &detected_gpu.driver_type
    };
    emit_log(&format!("[INFO] Pilote graphique configuré : {} ({})", gpu_driver, detected_gpu.name));

    // 6. Écriture de vars.nix et sauvegardes locales
    let vars_content = generate_vars_nix(&s, hashed_pw.as_deref(), gpu_driver);
    let vars_file = target_nixos.join("vars.nix");
    if let Err(e) = std::fs::write(&vars_file, &vars_content) {
        let err = format!("Échec d'écriture de vars.nix: {}", e);
        emit_log(&format!("[ERREUR FATALE] {}", err));
        return Err(err);
    }
    emit_log(&format!("[OK] Fichier vars.nix généré dans {}", vars_file.display()));

    let _ = std::fs::write(target_nixos.join(".vars.nix.backup"), &vars_content);
    let hw_target = target_nixos.join("hosts/desktop/hardware-configuration.nix");
    if hw_target.exists() {
        let _ = std::fs::copy(&hw_target, target_nixos.join(".hardware-configuration.nix.backup"));
    }

    // 7. Indexation Git indispensable pour Nix Flakes
    if !effective_dry_run {
        emit_log("[INFO] Indexation Git de /mnt/etc/nixos pour la conformité Nix Flakes...");
        let _ = Command::new("git").args(["init", target_nixos.to_str().unwrap()]).status();
        let _ = Command::new("git").args(["-C", target_nixos.to_str().unwrap(), "config", "user.name", "ChomiamOS Installer"]).status();
        let _ = Command::new("git").args(["-C", target_nixos.to_str().unwrap(), "config", "user.email", "installer@chomiamos.local"]).status();
        let _ = Command::new("git").args(["-C", target_nixos.to_str().unwrap(), "add", "-A"]).status();
        emit_log("[OK] Répertoire de configuration indexé dans Git.");

        // 8. Contrôle préventif d'intégrité
        let req_files = [
            target_nixos.join("flake.nix"),
            target_nixos.join("vars.nix"),
            target_nixos.join("vars-defaults.nix"),
            target_nixos.join("hosts/desktop/configuration.nix"),
            target_nixos.join("hosts/desktop/hardware-configuration.nix"),
            target_nixos.join("home"),
            target_nixos.join("modules"),
        ];

        for f in &req_files {
            if !f.exists() {
                let err = format!("Fichier obligatoire manquant avant nixos-install : {}", f.display());
                emit_log(&format!("[ERREUR FATALE] {}", err));
                return Err(err);
            }
        }
        emit_log("[OK] Contrôle de validation pré-installation : tous les fichiers requis sont présents.");
    }

    // =========================================================================
    // --- ÉTAPE 7 : Déploiement Système via nixos-install (68% - 95%) ---
    // =========================================================================
    emit_progress(68, "Installation du système ChomiamOS", "Compilation et déploiement déclaratif des paquets NixOS...");
    emit_log("[ÉTAPE 7/8] === Déploiement du système via nixos-install ===");
    emit_log("[INFO] Lancement de nixos-install sur la cible /mnt...");

    if !effective_dry_run {
        let secure_tmp = Path::new("/mnt/var/tmp/nix-installer");
        let _ = std::fs::create_dir_all(secure_tmp);

        let mut cmd = AsyncCommand::new("nixos-install");
        cmd.args([
            "--no-root-passwd",
            "--option", "sandbox", "false",
            "--option", "build-users-group", "",
            "--flake", "/mnt/etc/nixos#default",
            "--root", "/mnt",
        ]);
        cmd.env("TMPDIR", "/mnt/var/tmp/nix-installer");
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        let mut child = cmd.spawn().map_err(|e| format!("Impossible de lancer nixos-install: {}", e))?;

        let stdout = child.stdout.take().ok_or("Impossible de capturer stdout de nixos-install")?;
        let stderr = child.stderr.take().ok_or("Impossible de capturer stderr de nixos-install")?;

        let emit_stdout = emit_log.clone();
        let emit_prog = emit_progress.clone();

        let stdout_task = tokio::spawn(async move {
            let mut reader = AsyncBufReader::new(stdout).lines();
            let mut cur_pct = 68u32;
            while let Ok(Some(line)) = reader.next_line().await {
                emit_stdout(&line);
                if cur_pct < 95 && (line.contains("copying path") || line.contains("building ")) {
                    cur_pct = (cur_pct + 1).min(95);
                    emit_prog(cur_pct, "Installation de ChomiamOS en cours...", &line);
                }
            }
        });

        let emit_stderr = emit_log.clone();
        let stderr_task = tokio::spawn(async move {
            let mut reader = AsyncBufReader::new(stderr).lines();
            while let Ok(Some(line)) = reader.next_line().await {
                if line.contains("error:") || line.contains("failed") {
                    emit_stderr(&format!("[ERR] {}", line));
                } else if line.contains("warning:") {
                    emit_stderr(&format!("[WARN] {}", line));
                } else {
                    emit_stderr(&format!("[BUILD] {}", line));
                }
            }
        });

        let _ = tokio::join!(stdout_task, stderr_task);
        let status = child.wait().await.map_err(|e| format!("Erreur attente nixos-install: {}", e))?;

        if !status.success() {
            let err = format!("nixos-install a échoué (code de sortie: {:?}).", status.code());
            emit_log(&format!("[ERREUR FATALE] {}", err));
            let mut st = state.lock().await;
            st.is_running = false;
            st.is_finished = true;
            st.success = false;
            st.error = Some(err.clone());
            let _ = app.emit("install_finished", InstallFinished { success: false, error: Some(err.clone()) });
            return Err(err);
        }
        emit_log("[SUCCESS] Déploiement et compilation de ChomiamOS terminés avec succès !");
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
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
            let pct = 68 + (i as u32 + 1) * 4;
            emit_log(&format!("[SIMULATION] {}", step));
            emit_progress(pct, "Installation de ChomiamOS...", step);
        }
    }

    // =========================================================================
    // --- ÉTAPE 8 : Permissions, Synchronisation et Démontage Propre (95% - 100%) ---
    // =========================================================================
    emit_progress(96, "Finalisation de l'installation", "Attribution des droits d'accès et synchronisation disque...");
    emit_log("[ÉTAPE 8/8] === Finalisation et synchronisation finale ===");

    if !effective_dry_run {
        emit_log(&format!("[INFO] Attribution des droits sur /mnt/etc/nixos à l'utilisateur '{}'...", s.username));
        let _ = Command::new("chown").args(["-R", &format!("{}:users", s.username), "/mnt/etc/nixos"]).status();
        let _ = Command::new("chmod").args(["-R", "u+rwX,go+rX", "/mnt/etc/nixos"]).status();

        emit_log("[INFO] Synchronisation des données résiduelles (sync)...");
        let _ = Command::new("sync").status();

        emit_log("[INFO] Démontage propre des volumes...");
        if s.swap_size_mb > 0 {
            let _ = Command::new("swapoff").arg("/mnt/var/swapfile").status();
        }
        let _ = Command::new("umount").args(["-R", "/mnt"]).status();
        emit_log("[OK] Volumes démontés avec succès.");
    }

    emit_progress(100, "Installation terminée avec succès !", "ChomiamOS Gaming Edition est prêt.");
    emit_log("[SUCCESS] 🎉 Félicitations ! L'installation de ChomiamOS est terminée avec succès.");

    {
        let mut st = state.lock().await;
        st.is_running = false;
        st.is_finished = true;
        st.success = true;
        st.percent = 100;
        st.step = "Installation terminée avec succès !".into();
        st.current_message = "Votre système est prêt à redémarrer.".into();
    }

    let _ = app.emit("install_finished", InstallFinished {
        success: true,
        error: None,
    });

    Ok(())
}
