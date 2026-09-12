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
    pub is_downgrade: bool,
    pub channel: String,
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

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct ParsedVersion {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    pub prerelease: Option<String>,
}

pub fn parse_semver(v: &str) -> ParsedVersion {
    let clean = v.trim().trim_start_matches('v').trim_start_matches('V');
    let parts: Vec<&str> = clean.splitn(2, '-').collect();
    let nums_str = parts[0];
    let prerelease = parts.get(1).map(|s| s.to_lowercase());

    let nums: Vec<u32> = nums_str
        .split('.')
        .filter_map(|p| p.parse::<u32>().ok())
        .collect();

    ParsedVersion {
        major: nums.get(0).copied().unwrap_or(0),
        minor: nums.get(1).copied().unwrap_or(0),
        patch: nums.get(2).copied().unwrap_or(0),
        prerelease,
    }
}

pub fn compare_versions(v1: &str, v2: &str) -> std::cmp::Ordering {
    let p1 = parse_semver(v1);
    let p2 = parse_semver(v2);

    match (p1.major, p1.minor, p1.patch).cmp(&(p2.major, p2.minor, p2.patch)) {
        std::cmp::Ordering::Equal => {
            match (&p1.prerelease, &p2.prerelease) {
                (None, None) => std::cmp::Ordering::Equal,
                // In SemVer, a release version (None) is higher than a pre-release version with the same major.minor.patch
                (Some(_), None) => std::cmp::Ordering::Less,
                (None, Some(_)) => std::cmp::Ordering::Greater,
                (Some(s1), Some(s2)) => s1.cmp(s2),
            }
        }
        ord => ord,
    }
}

pub fn check_update(channel: &str) -> UpdateInfo {
    let target_channel = if channel.eq_ignore_ascii_case("testing") {
        "testing"
    } else {
        "stable"
    };

    let url = format!("https://api.github.com/repos/{}/releases?per_page=30", REPO);
    let output = Command::new("curl")
        .args([
            "-s",
            "--max-time", "6",
            "-H", "User-Agent: ChomiamOS-Installer-Updater",
            "-H", "Accept: application/vnd.github.v3+json",
            &url,
        ])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            if let Ok(releases) = serde_json::from_slice::<Vec<serde_json::Value>>(&out.stdout) {
                let mut candidate_release: Option<&serde_json::Value> = None;

                if target_channel == "stable" {
                    // Trouver la release stable la plus récente (prerelease == false et sans testing/rc dans le tag)
                    for r in &releases {
                        let is_prerelease = r.get("prerelease").and_then(|p| p.as_bool()).unwrap_or(false);
                        let tag = r.get("tag_name").and_then(|t| t.as_str()).unwrap_or("").to_lowercase();

                        if !is_prerelease && !tag.contains("testing") && !tag.contains("rc") && !tag.contains("beta") && !tag.contains("alpha") {
                            candidate_release = Some(r);
                            break;
                        }
                    }
                } else {
                    // Canal Testing : chercher la pré-version la plus récente ou la release la plus récente globale
                    for r in &releases {
                        let is_prerelease = r.get("prerelease").and_then(|p| p.as_bool()).unwrap_or(false);
                        let tag = r.get("tag_name").and_then(|t| t.as_str()).unwrap_or("").to_lowercase();

                        if is_prerelease || tag.contains("testing") || tag.contains("rc") {
                            candidate_release = Some(r);
                            break;
                        }
                    }

                    // Si aucune release spécifique de testing n'est encore publiée, se replier sur la toute première release de la liste
                    if candidate_release.is_none() {
                        candidate_release = releases.first();
                    }
                }

                if let Some(r) = candidate_release {
                    if let Some(tag) = r.get("tag_name").and_then(|t| t.as_str()) {
                        let clean_tag = tag.trim_start_matches('v').trim_start_matches('V');
                        let clean_curr = CURRENT_VERSION.trim_start_matches('v').trim_start_matches('V');

                        let ord = compare_versions(clean_curr, clean_tag);
                        let title = r.get("name").and_then(|n| n.as_str()).unwrap_or(tag).to_string();
                        let notes = r.get("body").and_then(|b| b.as_str()).unwrap_or("").to_string();

                        let mut download_url = String::new();
                        if let Some(assets) = r.get("assets").and_then(|a| a.as_array()) {
                            // 1. Chercher le binaire officiel chomiamos-installer-x86_64
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
                            // 2. Si non trouvé par nom exact, filtrer les fichiers non-exécutables
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

                        match ord {
                            std::cmp::Ordering::Less => {
                                // Mise à jour disponible (version cible plus récente que l'actuelle)
                                return UpdateInfo {
                                    has_update: true,
                                    is_downgrade: false,
                                    channel: target_channel.to_string(),
                                    current_version: CURRENT_VERSION.to_string(),
                                    latest_version: clean_tag.to_string(),
                                    title,
                                    notes,
                                    download_url,
                                };
                            }
                            std::cmp::Ordering::Greater => {
                                // Rétrogradation possible (version actuelle en avance sur la version cible du canal choisi)
                                return UpdateInfo {
                                    has_update: true,
                                    is_downgrade: true,
                                    channel: target_channel.to_string(),
                                    current_version: CURRENT_VERSION.to_string(),
                                    latest_version: clean_tag.to_string(),
                                    title,
                                    notes,
                                    download_url,
                                };
                            }
                            std::cmp::Ordering::Equal => {
                                // Exactement à jour
                                return UpdateInfo {
                                    has_update: false,
                                    is_downgrade: false,
                                    channel: target_channel.to_string(),
                                    current_version: CURRENT_VERSION.to_string(),
                                    latest_version: clean_tag.to_string(),
                                    title,
                                    notes,
                                    download_url,
                                };
                            }
                        }
                    }
                }
            }
        }
    }

    UpdateInfo {
        has_update: false,
        is_downgrade: false,
        channel: target_channel.to_string(),
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
    let _ = app.emit("update_progress", UpdateProgress {
        percent: 10,
        message: "Téléchargement en cours...".into(),
    });

    let mut child = tokio::process::Command::new("curl")
        .args([
            "-L",
            "--fail",
            "--max-time", "180",
            "-#",
            "-o", temp_dest.to_str().unwrap(),
            "-H", "User-Agent: ChomiamOS-Installer-Updater",
            download_url,
        ])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("Impossible de lancer curl pour le téléchargement: {}", e))?;

    if let Some(stderr) = child.stderr.take() {
        use tokio::io::AsyncReadExt;
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
                        for part in text.split_whitespace() {
                            let cleaned = part.trim_end_matches('%');
                            if let Ok(pct_f) = cleaned.parse::<f64>() {
                                let pct = ((pct_f * 0.83) as u32 + 10).min(93);
                                if pct > last_pct {
                                    last_pct = pct;
                                    let _ = app_clone.emit("update_progress", UpdateProgress {
                                        percent: pct,
                                        message: format!("Téléchargement en cours ({}%)...", pct),
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

    // Vérifier que le fichier a bien été téléchargé et fait au moins 1 Mo
    let meta = std::fs::metadata(temp_dest)
        .map_err(|e| format!("Le fichier téléchargé est introuvable: {}", e))?;
    if meta.len() < 1_000_000 {
        let _ = std::fs::remove_file(temp_dest);
        return Err(format!(
            "Le fichier téléchargé est trop petit ({} octets) ou corrompu. Un binaire valide fait ~20 Mo. L'opération a été annulée.",
            meta.len()
        ));
    }

    // Vérifier le header ELF
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
        message: "Vérification de l'intégrité du binaire...".into(),
    });

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 98,
        message: "Attribution des permissions d'exécution...".into(),
    });

    let mut perms = meta.permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(temp_dest, perms).map_err(|e| e.to_string())?;

    let _ = app.emit("update_progress", UpdateProgress {
        percent: 100,
        message: "Opération terminée ! Redémarrage de l'installateur...".into(),
    });

    tokio::time::sleep(tokio::time::Duration::from_millis(900)).await;

    let args: Vec<String> = std::env::args().skip(1).collect();
    let err = std::process::Command::new(temp_dest).args(&args).exec();
    Err(format!("Échec du redémarrage: {}", err))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parsing_and_comparison() {
        assert_eq!(compare_versions("1.2.15", "1.2.15"), std::cmp::Ordering::Equal);
        assert_eq!(compare_versions("1.2.16", "1.2.15"), std::cmp::Ordering::Greater);
        assert_eq!(compare_versions("1.2.14", "1.2.15"), std::cmp::Ordering::Less);

        // Pre-release comparison
        assert_eq!(compare_versions("1.2.16-testing", "1.2.15"), std::cmp::Ordering::Greater);
        assert_eq!(compare_versions("1.2.16-testing", "1.2.16"), std::cmp::Ordering::Less);
        assert_eq!(compare_versions("1.2.16-testing", "1.2.16-testing"), std::cmp::Ordering::Equal);
    }
}
