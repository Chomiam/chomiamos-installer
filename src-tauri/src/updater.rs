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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateProgress {
    pub percent: u32,
    pub message: String,
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

pub async fn download_and_restart<R: tauri::Runtime>(
    app: tauri::AppHandle<R>,
    download_url: &str,
) -> Result<(), String> {
    use tauri::Emitter;

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 5,
        message: "Connexion aux serveurs GitHub Releases...".into(),
    });

    let temp_dest = Path::new("/tmp/chomiamos-installer-updated");
    if temp_dest.exists() {
        let _ = std::fs::remove_file(temp_dest);
    }

    let python_script = format!(
r#"
import urllib.request, sys, os

url = "{url}"
target = "{target}"

req = urllib.request.Request(url, headers={{"User-Agent": "ChomiamOS-Installer-Updater"}})
with urllib.request.urlopen(req, timeout=120) as resp:
    total = int(resp.headers.get("Content-Length", 0))
    downloaded = 0
    chunk_size = 128 * 1024
    with open(target, "wb") as f:
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            f.write(chunk)
            downloaded += len(chunk)
            if total > 0:
                pct = int((downloaded / total) * 88) + 5
                print(f"PROGRESS:{{pct}}", flush=True)
print("PROGRESS:95", flush=True)
"#,
        url = download_url,
        target = temp_dest.to_str().unwrap()
    );

    let mut child = tokio::process::Command::new("python3")
        .args(["-c", &python_script])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("Impossible de démarrer le téléchargement: {}", e))?;

    if let Some(stdout) = child.stdout.take() {
        use tokio::io::{AsyncBufReadExt, BufReader};
        let mut reader = BufReader::new(stdout).lines();
        let mut last_pct = 5;
        while let Ok(Some(line)) = reader.next_line().await {
            if let Some(pct_str) = line.strip_prefix("PROGRESS:") {
                if let Ok(pct) = pct_str.trim().parse::<u32>() {
                    if pct > last_pct {
                        last_pct = pct;
                        let msg = if pct < 90 {
                            format!("Téléchargement de la mise à jour ({}%)...", pct)
                        } else if pct < 95 {
                            "Vérification du binaire téléchargé...".to_string()
                        } else {
                            "Finalisation des permissions d'exécution...".to_string()
                        };
                        let _ = app.emit("update_progress", UpdateProgress {
                            percent: pct,
                            message: msg,
                        });
                    }
                }
            }
        }
    }

    let status = child.wait().await.map_err(|e| format!("Erreur téléchargement: {}", e))?;
    if !status.success() {
        // Fallback avec curl
        let _ = app.emit("update_progress", UpdateProgress {
            percent: 50,
            message: "Téléchargement direct de secours via curl...".into(),
        });
        let cstatus = tokio::process::Command::new("curl")
            .args(["-L", "--max-time", "180", "-o", temp_dest.to_str().unwrap(), download_url])
            .status()
            .await
            .map_err(|e| format!("Curl de secours échoué: {}", e))?;
        if !cstatus.success() {
            return Err("Échec du téléchargement de la mise à jour".into());
        }
    }

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 98,
        message: "Attribution des droits d'exécution (chmod +x)...".into(),
    });

    let mut perms = std::fs::metadata(temp_dest)
        .map_err(|e| e.to_string())?
        .permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(temp_dest, perms).map_err(|e| e.to_string())?;

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 100,
        message: "Mise à jour prête ! Redémarrage de l'installateur...".into(),
    });

    tokio::time::sleep(tokio::time::Duration::from_millis(900)).await;

    let args: Vec<String> = std::env::args().skip(1).collect();
    let err = std::process::Command::new(temp_dest).args(&args).exec();
    Err(format!("Échec du redémarrage sur la nouvelle version: {}", err))
}
