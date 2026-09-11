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
                            // 1. Chercher d'abord le binaire officiel direct chomiamos-installer-x86_64
                            for asset in assets {
                                if let Some(name) = asset.get("name").and_then(|n| n.as_str()) {
                                    if name == "chomiamos-installer-x86_64" {
                                        if let Some(durl) = asset.get("browser_download_url").and_then(|u| u.as_str()) {
                                            download_url = durl.to_string();
                                            break;
                                        }
                                    }
                                }
                            }
                            // 2. Si non trouvé par nom exact, filtrer rigoureusement les fichiers non-exécutables (.sha256, .tar.gz, etc.)
                            if download_url.is_empty() {
                                for asset in assets {
                                    if let Some(name) = asset.get("name").and_then(|n| n.as_str()) {
                                        if name.contains("chomiamos-installer")
                                            && !name.ends_with(".sha256")
                                            && !name.ends_with(".tar.gz")
                                            && !name.ends_with(".zip")
                                            && !name.ends_with(".txt")
                                        {
                                            if let Some(durl) = asset.get("browser_download_url").and_then(|u| u.as_str()) {
                                                download_url = durl.to_string();
                                                break;
                                            }
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

    // Téléchargement via curl avec suivi de progression
    // curl est toujours disponible sur NixOS (contrairement à python3)
    let _ = app.emit("update_progress", UpdateProgress {
        percent: 10,
        message: "Téléchargement de la mise à jour en cours...".into(),
    });

    let mut child = tokio::process::Command::new("curl")
        .args([
            "-L",                       // Suivre les redirections GitHub
            "--fail",                    // Échouer proprement sur les erreurs HTTP
            "--max-time", "180",         // Timeout de 3 minutes
            "-#",                        // Barre de progression sur stderr
            "-o", temp_dest.to_str().unwrap(),
            "-H", "User-Agent: ChomiamOS-Installer-Updater",
            download_url,
        ])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("Impossible de lancer curl pour le téléchargement: {}", e))?;

    // Lire stderr de curl pour la progression (le -# envoie une barre de progression)
    if let Some(stderr) = child.stderr.take() {
        use tokio::io::{AsyncReadExt};
        let app_clone = app.clone();
        tokio::spawn(async move {
            let mut reader = stderr;
            let mut buf = [0u8; 256];
            let mut last_pct = 10u32;
            loop {
                match reader.read(&mut buf).await {
                    Ok(0) => break,
                    Ok(n) => {
                        let text = String::from_utf8_lossy(&buf[..n]);
                        // curl -# affiche des lignes avec ###... et des %
                        // On cherche des pourcentages dans la sortie
                        for part in text.split_whitespace() {
                            let cleaned = part.trim_end_matches('%');
                            if let Ok(pct_f) = cleaned.parse::<f64>() {
                                let pct = ((pct_f * 0.83) as u32 + 10).min(93);
                                if pct > last_pct {
                                    last_pct = pct;
                                    let _ = app_clone.emit("update_progress", UpdateProgress {
                                        percent: pct,
                                        message: format!("Téléchargement de la mise à jour ({}%)...", pct),
                                    });
                                }
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });
    }

    let status = child.wait().await.map_err(|e| format!("Erreur lors du téléchargement: {}", e))?;
    if !status.success() {
        return Err(format!(
            "Le téléchargement a échoué (curl code {:?}). Vérifiez votre connexion Internet et réessayez.",
            status.code()
        ));
    }

    // Vérifier que le fichier a bien été téléchargé et fait au moins 1 Mo (binaire ELF complet)
    let meta = std::fs::metadata(temp_dest)
        .map_err(|e| format!("Le fichier téléchargé est introuvable: {}", e))?;
    if meta.len() < 1_000_000 {
        let _ = std::fs::remove_file(temp_dest);
        return Err(format!(
            "Le fichier téléchargé est trop petit ({} octets) ou corrompu. Un binaire valide fait ~20 Mo. La mise à jour a été annulée.",
            meta.len()
        ));
    }

    // Vérifier le header ELF pour garantir qu'il s'agit bien d'un exécutable Linux natif valide
    if let Ok(mut f) = std::fs::File::open(temp_dest) {
        use std::io::Read;
        let mut magic = [0u8; 4];
        if f.read_exact(&mut magic).is_ok() && &magic != &[0x7f, b'E', b'L', b'F'] {
            let _ = std::fs::remove_file(temp_dest);
            return Err("Le fichier téléchargé n'est pas un binaire Linux ELF valide.".into());
        }
    }

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 95,
        message: "Vérification du binaire téléchargé...".into(),
    });

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 98,
        message: "Attribution des droits d'exécution (chmod +x)...".into(),
    });

    let mut perms = meta.permissions();
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
