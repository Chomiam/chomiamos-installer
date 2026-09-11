use std::process::Command;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::process::CommandExt;
use std::path::Path;
use serde::{Deserialize, Serialize};

const CURRENT_VERSION: &str = env!("CARGO_PKG_VERSION");
const REPO: &str = "Chomiam/chomiamos-installer";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateInfo {
    pub has_update: bool,
    pub current_version: String,
    pub latest_version: String,
    pub title: String,
    pub notes: String,
    pub download_url: String,
}

fn parse_version(v: &str) -> Vec<u32> {
    v.trim_start_matches('v')
        .trim_start_matches('V')
        .split('.')
        .filter_map(|p| p.parse::<u32>().ok())
        .collect()
}

pub fn check_update() -> UpdateInfo {
    let url = format!("https://api.github.com/repos/{}/releases/latest", REPO);
    let output = Command::new("curl")
        .args([
            "-s",
            "--max-time", "5",
            "-H", "User-Agent: ChomiamOS-Installer-Updater",
            "-H", "Accept: application/vnd.github.v3+json",
            &url,
        ])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&out.stdout) {
                if let Some(tag) = json.get("tag_name").and_then(|t| t.as_str()) {
                    let latest_ver_nums = parse_version(tag);
                    let current_ver_nums = parse_version(CURRENT_VERSION);

                    if latest_ver_nums > current_ver_nums {
                        let title = json.get("name").and_then(|n| n.as_str()).unwrap_or(tag).to_string();
                        let notes = json.get("body").and_then(|b| b.as_str()).unwrap_or("").to_string();

                        let mut download_url = String::new();
                        if let Some(assets) = json.get("assets").and_then(|a| a.as_array()) {
                            for asset in assets {
                                if let Some(name) = asset.get("name").and_then(|n| n.as_str()) {
                                    if name.contains("chomiamos-installer") && !name.ends_with(".tar.gz") {
                                        if let Some(durl) = asset.get("browser_download_url").and_then(|u| u.as_str()) {
                                            download_url = durl.to_string();
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        if download_url.is_empty() {
                            download_url = format!(
                                "https://github.com/{}/releases/download/{}/chomiamos-installer-x86_64",
                                REPO, tag
                            );
                        }

                        return UpdateInfo {
                            has_update: true,
                            current_version: CURRENT_VERSION.to_string(),
                            latest_version: tag.trim_start_matches('v').to_string(),
                            title,
                            notes,
                            download_url,
                        };
                    }
                }
            }
        }
    }

    UpdateInfo {
        has_update: false,
        current_version: CURRENT_VERSION.to_string(),
        latest_version: CURRENT_VERSION.to_string(),
        title: "".into(),
        notes: "".into(),
        download_url: "".into(),
    }
}

pub fn download_and_restart(download_url: &str) -> Result<(), String> {
    let temp_dest = Path::new("/tmp/chomiamos-installer-updated");
    let status = Command::new("curl")
        .args([
            "-L",
            "--max-time", "120",
            "-o", temp_dest.to_str().unwrap(),
            download_url,
        ])
        .status()
        .map_err(|e| format!("Échec d'exécution de curl: {}", e))?;

    if !status.success() {
        return Err("Échec du téléchargement du nouveau binaire".into());
    }

    let mut perms = std::fs::metadata(temp_dest)
        .map_err(|e| e.to_string())?
        .permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(temp_dest, perms).map_err(|e| e.to_string())?;

    let args: Vec<String> = std::env::args().skip(1).collect();
    let err = Command::new(temp_dest).args(&args).exec();
    Err(format!("Échec du redémarrage sur la nouvelle version: {}", err))
}
