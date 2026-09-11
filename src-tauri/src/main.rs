// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod system;
mod swap;
mod config;
mod install;

use system::{check_prerequisites, list_disks, get_keyboard_layouts, SystemPrerequisites, DiskInfo, KeyboardLayoutInfo};
use config::{InstallerSelections, generate_vars_nix};
use swap::create_instant_swapfile;
use install::{execute_installation, InstallFinished};
use tauri::Emitter;
use std::process::Command;
use std::path::Path;

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
async fn test_instant_swap(size_mb: u64) -> Result<f64, String> {
    let start = std::time::Instant::now();
    let temp_swap = Path::new("/tmp/test_instant_swap.img");
    
    create_instant_swapfile(temp_swap, size_mb)?;
    let elapsed_ms = start.elapsed().as_secs_f64() * 1000.0;
    
    let _ = std::fs::remove_file(temp_swap);
    Ok(elapsed_ms)
}

#[tauri::command]
fn generate_configuration_preview(selections: InstallerSelections) -> String {
    generate_vars_nix(&selections, Some("$6$rounds=50000$previewHash..."), "amd")
}

#[tauri::command]
async fn start_installation(
    app: tauri::AppHandle,
    selections: InstallerSelections,
    dry_run: Option<bool>,
) -> Result<(), String> {
    let is_dry = dry_run.unwrap_or(false);
    tokio::spawn(async move {
        if let Err(e) = execute_installation(app.clone(), selections, is_dry).await {
            let _ = app.emit("install_finished", InstallFinished {
                success: false,
                error: Some(e),
            });
        }
    });
    Ok(())
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
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_prerequisites,
            get_disks,
            get_layouts,
            apply_keyboard_live,
            test_instant_swap,
            generate_configuration_preview,
            start_installation,
            reboot_system,
            poweroff_system,
        ])
        .run(tauri::generate_context!())
        .expect("Erreur lors de l'exécution de l'installateur ChomiamOS");
}
