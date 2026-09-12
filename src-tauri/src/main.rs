// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod system;
mod swap;
mod config;
mod install;
mod updater;
mod network_mirror;

use system::{check_prerequisites, detect_gpu, list_disks, get_keyboard_layouts, get_desktop_environments, get_timezones, get_current_timezone, SystemPrerequisites, GpuInfo, DiskInfo, KeyboardLayoutInfo, KeyboardLocks, DesktopEnvInfo, TimezoneInfo};
use config::{InstallerSelections, generate_vars_nix};
use install::{execute_installation, InstallStateSnapshot, SharedInstallState};
use updater::{check_update, download_and_restart, UpdateInfo};
use std::sync::Arc;
use tokio::sync::Mutex;
use std::process::Command;

#[tauri::command]
fn get_gpu() -> GpuInfo {
    detect_gpu()
}

#[tauri::command]
fn get_prerequisites() -> SystemPrerequisites {
    check_prerequisites()
}

#[tauri::command]
fn get_disks() -> Vec<DiskInfo> {
    list_disks()
}

#[tauri::command]
fn get_layouts() -> Vec<KeyboardLayoutInfo> {
    get_keyboard_layouts()
}

#[tauri::command]
fn get_desktops() -> Vec<DesktopEnvInfo> {
    get_desktop_environments()
}

fn get_session_context() -> (String, u32, std::collections::HashMap<String, String>) {
    let mut uid: Option<u32> = std::env::var("SUDO_UID").ok().and_then(|s| s.parse().ok()).filter(|&u| u != 0);

    if uid.is_none() {
        if let Ok(runtime) = std::env::var("XDG_RUNTIME_DIR") {
            if let Some(tail) = runtime.strip_prefix("/run/user/") {
                if let Ok(u) = tail.parse::<u32>() {
                    if u != 0 {
                        uid = Some(u);
                    }
                }
            }
        }
    }

    if uid.is_none() {
        if let Ok(entries) = std::fs::read_dir("/run/user") {
            for entry in entries.flatten() {
                if let Ok(name) = entry.file_name().into_string() {
                    if let Ok(u) = name.parse::<u32>() {
                        if u != 0 && std::path::Path::new(&format!("/run/user/{}/bus", u)).exists() {
                            uid = Some(u);
                            break;
                        }
                    }
                }
            }
        }
    }

    let uid = uid.unwrap_or(1000);

    let username = if let Ok(output) = Command::new("id").args(["-nu", &uid.to_string()]).output() {
        let name = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !name.is_empty() { name } else { "nixos".to_string() }
    } else {
        "nixos".to_string()
    };

    let mut env = std::collections::HashMap::new();
    env.insert("XDG_RUNTIME_DIR".to_string(), format!("/run/user/{}", uid));
    env.insert("DBUS_SESSION_BUS_ADDRESS".to_string(), format!("unix:path=/run/user/{}/bus", uid));
    if let Ok(val) = std::env::var("DISPLAY") {
        env.insert("DISPLAY".to_string(), val);
    }
    if let Ok(val) = std::env::var("WAYLAND_DISPLAY") {
        env.insert("WAYLAND_DISPLAY".to_string(), val);
    }
    if let Ok(val) = std::env::var("XAUTHORITY") {
        env.insert("XAUTHORITY".to_string(), val);
    }

    (username, uid, env)
}

fn run_in_user_session(cmd: &[&str]) {
    let (user, _uid, env) = get_session_context();
    let is_root = Command::new("id").arg("-u").output().map(|o| String::from_utf8_lossy(&o.stdout).trim() == "0").unwrap_or(false);

    if is_root {
        let mut full = Command::new("runuser");
        full.arg("-u").arg(&user).arg("--").arg("env");
        for (k, v) in &env {
            full.arg(format!("{}={}", k, v));
        }
        full.args(cmd);
        let _ = full.status();
    } else {
        let mut c = Command::new(cmd[0]);
        for (k, v) in &env {
            c.env(k, v);
        }
        c.args(&cmd[1..]);
        let _ = c.status();
    }
}

#[tauri::command]
fn apply_keyboard_live(layout: String, variant: String) -> Result<(), String> {
    // 1. localectl global system keymap
    let mut localectl_cmd = Command::new("localectl");
    localectl_cmd.arg("set-x11-keymap").arg(&layout).arg("pc105");
    if !variant.is_empty() {
        localectl_cmd.arg(&variant);
    } else {
        localectl_cmd.arg("");
    }
    let _ = localectl_cmd.status();

    // 2. setxkbmap
    let mut xkb_args = vec!["setxkbmap", layout.as_str()];
    if !variant.is_empty() {
        xkb_args.push("-variant");
        xkb_args.push(variant.as_str());
    }
    run_in_user_session(&xkb_args);

    // 3. GNOME input-sources
    let gsettings_val = if variant.is_empty() {
        format!("[('xkb', '{}')]", layout)
    } else {
        format!("[('xkb', '{}+{}')]", layout, variant)
    };
    run_in_user_session(&["gsettings", "set", "org.gnome.desktop.input-sources", "sources", &gsettings_val]);
    run_in_user_session(&["gsettings", "set", "org.gnome.desktop.input-sources", "current", "0"]);

    // 4. Cinnamon input-sources
    run_in_user_session(&["gsettings", "set", "org.cinnamon.desktop.input-sources", "sources", &gsettings_val]);
    run_in_user_session(&["gsettings", "set", "org.cinnamon.desktop.input-sources", "current", "0"]);

    Ok(())
}

#[tauri::command]
fn get_timezones_list() -> Vec<TimezoneInfo> {
    get_timezones()
}

#[tauri::command]
fn get_detected_timezone() -> String {
    get_current_timezone()
}

#[tauri::command]
fn apply_timezone_live(timezone: String) -> Result<(), String> {
    let _ = Command::new("timedatectl")
        .args(["set-timezone", &timezone])
        .status();
    Ok(())
}

#[tauri::command]
fn generate_configuration_preview(selections: InstallerSelections) -> String {
    generate_vars_nix(&selections, Some("$6$rounds=50000$previewHash..."), "amd")
}

#[tauri::command]
async fn start_installation(
    app: tauri::AppHandle,
    state: tauri::State<'_, Arc<Mutex<SharedInstallState>>>,
    selections: InstallerSelections,
    dry_run: Option<bool>,
) -> Result<(), String> {
    let is_dry = dry_run.unwrap_or(false);
    let state_clone = state.inner().clone();
    tokio::spawn(async move {
        let _ = execute_installation(app, state_clone, selections, is_dry).await;
    });
    Ok(())
}

#[tauri::command]
async fn get_install_state(
    state: tauri::State<'_, Arc<Mutex<SharedInstallState>>>,
    since_log_idx: usize,
) -> Result<InstallStateSnapshot, String> {
    let st = state.lock().await;
    let new_logs = if since_log_idx < st.logs.len() {
        st.logs[since_log_idx..].to_vec()
    } else {
        Vec::new()
    };
    Ok(InstallStateSnapshot {
        is_running: st.is_running,
        is_finished: st.is_finished,
        success: st.success,
        percent: st.percent,
        step: st.step.clone(),
        current_message: st.current_message.clone(),
        error: st.error.clone(),
        new_logs,
        total_logs_count: st.logs.len(),
    })
}

#[tauri::command]
fn reboot_system() -> Result<(), String> {
    let _ = Command::new("systemctl").arg("reboot").status();
    let _ = Command::new("reboot").status();
    Ok(())
}

#[tauri::command]
fn poweroff_system() -> Result<(), String> {
    let _ = Command::new("systemctl").arg("poweroff").status();
    let _ = Command::new("poweroff").status();
    Ok(())
}


#[tauri::command]
async fn get_mirror_info() -> network_mirror::MirrorInfo {
    network_mirror::detect_best_mirror().await
}

#[tauri::command]
fn get_keyboard_locks() -> KeyboardLocks {
    system::detect_keyboard_locks()
}

#[tauri::command]
async fn check_installer_update(channel: Option<String>) -> UpdateInfo {
    let ch = channel.unwrap_or_else(|| "stable".into());
    tokio::task::spawn_blocking(move || {
        check_update(&ch)
    })
    .await
    .unwrap_or_else(|_| UpdateInfo::default())
}

#[tauri::command]
async fn apply_installer_update(app: tauri::AppHandle, download_url: String) -> Result<(), String> {
    download_and_restart(app, &download_url).await
}

#[tauri::command]
async fn save_installation_logs(content: String) -> Result<String, String> {
    let (user, _uid, env) = get_session_context();
    let is_root = Command::new("id")
        .arg("-u")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "0")
        .unwrap_or(false);

    let mut zenity_cmd = if is_root {
        let mut full = Command::new("runuser");
        full.arg("-u").arg(&user).arg("--").arg("env");
        for (k, v) in &env {
            full.arg(format!("{}={}", k, v));
        }
        full.args([
            "zenity",
            "--file-selection",
            "--save",
            "--confirm-overwrite",
            "--title=Enregistrer les logs d'installation",
            "--filename=chomiamos-installation.txt",
            "--file-filter=Fichiers texte (*.txt *.log) | *.txt *.log",
        ]);
        full
    } else {
        let mut c = Command::new("zenity");
        for (k, v) in &env {
            c.env(k, v);
        }
        c.args([
            "--file-selection",
            "--save",
            "--confirm-overwrite",
            "--title=Enregistrer les logs d'installation",
            "--filename=chomiamos-installation.txt",
            "--file-filter=Fichiers texte (*.txt *.log) | *.txt *.log",
        ]);
        c
    };

    let target_path = match zenity_cmd.output() {
        Ok(out) if out.status.success() => {
            let p = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if p.is_empty() {
                return Err("Annulé par l'utilisateur".to_string());
            }
            p
        }
        _ => {
            let home_dir = if is_root && user != "root" {
                format!("/home/{}", user)
            } else {
                std::env::var("HOME").unwrap_or_else(|_| "/home/nixos".to_string())
            };
            let desktop = std::path::Path::new(&home_dir).join("Desktop");
            let target = if desktop.exists() {
                desktop.join("chomiamos-installation.txt")
            } else {
                std::path::PathBuf::from("/tmp/chomiamos-installation.txt")
            };
            target.to_string_lossy().to_string()
        }
    };

    std::fs::write(&target_path, content.as_bytes())
        .map_err(|e| format!("Impossible d'enregistrer le fichier dans {} : {}", target_path, e))?;

    Ok(target_path)
}

#[tauri::command]
async fn get_desktop_versions() -> system::DesktopVersions {
    tokio::task::spawn_blocking(|| {
        system::detect_desktop_versions()
    })
    .await
    .unwrap_or_else(|_| system::DesktopVersions {
        gnome: "50.4".into(),
        kde: "6.6.6".into(),
        cosmic: "1.6.0".into(),
        cinnamon: "6.6.3".into(),
    })
}

fn main() {
    // Si l'installateur n'est pas root et que sudo sans mot de passe est actif (session Live),
    // s'élever automatiquement en root avec sudo -E pour avoir les droits d'accès directs aux disques
    if let Ok(output) = Command::new("id").arg("-u").output() {
        if String::from_utf8_lossy(&output.stdout).trim() != "0" {
            if let Ok(status) = Command::new("sudo").args(["-n", "true"]).status() {
                if status.success() {
                    if let Ok(exe) = std::env::current_exe() {
                        let raw_args: Vec<String> = std::env::args().skip(1).collect();
                        use std::os::unix::process::CommandExt;
                        let _ = Command::new("sudo")
                            .arg("-E")
                            .arg(exe)
                            .args(&raw_args)
                            .exec();
                    }
                }
            }
        }
    }

    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--version" || a == "-v" || a == "-V") {
        println!("chomiamos-installer {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    if args.iter().any(|a| a == "--help" || a == "-h") {
        println!("ChomiamOS Installer v{}", env!("CARGO_PKG_VERSION"));
        println!("Usage: chomiamos-installer [OPTIONS]");
        println!("\nOptions:");
        println!("  -h, --help       Afficher l'aide");
        println!("  -v, --version    Afficher la version");
        return;
    }

    if std::env::var("WEBKIT_DISABLE_DMABUF_RENDERER").is_err() {
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    }

    let install_state = Arc::new(Mutex::new(SharedInstallState::default()));

    tauri::Builder::default()
        .manage(install_state)
        .invoke_handler(tauri::generate_handler![
            get_prerequisites,
            get_gpu,
            get_disks,
            get_layouts,
            get_desktops,
            apply_keyboard_live,
            get_timezones_list,
            get_detected_timezone,
            apply_timezone_live,
            generate_configuration_preview,
            start_installation,
            get_install_state,
            reboot_system,
            poweroff_system,
            check_installer_update,
            get_mirror_info,
            get_keyboard_locks,
            apply_installer_update,
            save_installation_logs,
            get_desktop_versions,
        ])
        .run(tauri::generate_context!())
        .expect("Erreur lors de l'exécution de l'installateur ChomiamOS");
}
