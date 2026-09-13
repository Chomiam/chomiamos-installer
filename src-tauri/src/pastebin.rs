use tokio::process::Command;

pub const PASTEBIN_API_KEY: &str = "qx4wb3zQn3sdjePyzNBeixUJqVe-Di_X";
pub const PASTEBIN_POST_URL: &str = "https://pastebin.com/api/api_post.php";

/// Nettoie et anonymise le contenu du rapport avant transmission publique ou semi-publique
pub fn sanitize_report_content(raw: &str) -> String {
    let mut sanitized = String::new();
    for line in raw.lines() {
        let trimmed = line.trim();
        // Masquer les hachages de mots de passe de type Unix crypt/SHA-512 ($6$...)
        if trimmed.contains("$6$") {
            sanitized.push_str("    [MOT DE PASSE OU HASH CHIFFRÉ MASQUÉ PAR SÉCURITÉ]\n");
            continue;
        }
        // Masquer les champs de mots de passe en clair
        if trimmed.starts_with("initialHashedPassword") 
            || trimmed.starts_with("TARGET_PW=") 
            || trimmed.contains("password:")
            || trimmed.contains("password =")
        {
            sanitized.push_str("    [MOT DE PASSE OU IDENTIFIANT MASQUÉ PAR SÉCURITÉ]\n");
            continue;
        }
        sanitized.push_str(line);
        sanitized.push('\n');
    }
    sanitized
}

/// Téléverse de manière asynchrone le rapport d'incident vers Pastebin via l'API officielle
pub async fn upload_to_pastebin(title: &str, content: &str) -> Result<String, String> {
    let sanitized = sanitize_report_content(content);
    let clean_title = if title.trim().is_empty() {
        "chomiamos-installation-error.log"
    } else {
        title.trim()
    };

    let output = Command::new("curl")
        .args([
            "-s",
            "--max-time", "15",
            "-X", "POST",
            "-d", &format!("api_dev_key={}", PASTEBIN_API_KEY),
            "-d", "api_option=paste",
            "-d", "api_paste_private=1",          // 1 = unlisted (non-référencé publiquement)
            "-d", "api_paste_expire_date=1M",     // expiration à 1 mois
            "-d", "api_paste_format=text",
            "--data-urlencode", &format!("api_paste_name={}", clean_title),
            "--data-urlencode", &format!("api_paste_code={}", sanitized),
            PASTEBIN_POST_URL,
        ])
        .output()
        .await
        .map_err(|e| format!("Impossible d'exécuter curl pour contacter Pastebin: {}", e))?;

    let resp = String::from_utf8_lossy(&output.stdout).trim().to_string();

    if resp.starts_with("https://pastebin.com/") {
        Ok(resp)
    } else if resp.starts_with("Bad API request") {
        Err(format!("Erreur retournée par Pastebin : {}", resp))
    } else if !output.status.success() {
        let err_err = String::from_utf8_lossy(&output.stderr).trim().to_string();
        Err(format!(
            "Échec de connexion réseau (curl code {:?}): {}",
            output.status.code(),
            if err_err.is_empty() { "Vérifiez votre connexion Internet." } else { &err_err }
        ))
    } else {
        Err(format!("Réponse imprévue du service Pastebin : {}", resp))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitize_report_content() {
        let input = "System Info: OK\ninitialHashedPassword = \"$6$rounds=50000$salt$abc123hashed\";\nTARGET_PW='supersecretpassword'\nRAM: 16GB\n";
        let out = sanitize_report_content(input);
        assert!(!out.contains("supersecretpassword"));
        assert!(!out.contains("abc123hashed"));
        assert!(out.contains("System Info: OK"));
        assert!(out.contains("RAM: 16GB"));
        assert!(out.contains("MASQUÉ PAR SÉCURITÉ"));
    }
}
