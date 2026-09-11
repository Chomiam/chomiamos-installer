// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod system;
mod swap;
mod config;
mod install;

use system::{check_prerequisites, list_disks, get_keyboard_layouts, get_desktop_environments, SystemPrerequisites, DiskInfo, KeyboardLayoutInfo, DesktopEnvInfo};
use config::{InstallerSelections, generate_vars_nix};
use install::{execute_installation, InstallStateSnapshot, SharedInstallState};
use std::sync::Arc;
use tokio::sync::Mutex;
use std::process::Command;

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

#[tauri::command]
fn apply_keyboard_live(layout: String, variant: String) -> Result<(), String> {
    let mut cmd = Command::new("setxkbmap");
    cmd.arg(&layout);
    if !variant.is_empty() {
        cmd.arg(&variant);
    }
    let _ = cmd.status();

    let mut gsettings_val = format!("[('xkb', '{}')]", layout);
    if !variant.is_empty() {
        gsettings_val = format!("[('xkb', '{}+{}')]", layout, variant);
    }
    let _ = Command::new("gsettings")
        .args(["set", "org.gnome.desktop.input-sources", "sources", &gsettings_val])
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

fn main() {
    let install_state = Arc::new(Mutex::new(SharedInstallState::default()));

    tauri::Builder::default()
        .manage(install_state)
        .invoke_handler(tauri::generate_handler![
            get_prerequisites,
            get_disks,
            get_layouts,
            get_desktops,
            apply_keyboard_live,
            generate_configuration_preview,
            start_installation,
            get_install_state,
            reboot_system,
            poweroff_system,
        ])
        .run(tauri::generate_context!())
        .expect("Erreur lors de l'exécution de l'installateur ChomiamOS");
}
