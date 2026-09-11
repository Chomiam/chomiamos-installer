use std::fs::OpenOptions;
use std::os::unix::fs::OpenOptionsExt;
use std::os::unix::io::AsRawFd;
use std::path::Path;
use std::process::Command;
use nix::fcntl::posix_fallocate;

/// Creates a swapfile of `size_mb` Megabytes at `path` instantaneously using posix_fallocate.
/// Then formats it with `mkswap` and applies proper 0600 permissions.
pub fn create_instant_swapfile(path: &Path, size_mb: u64) -> Result<(), String> {
    if size_mb == 0 {
        return Ok(()); // Swap disabled
    }

    let size_bytes = size_mb * 1024 * 1024;

    // Create or open file with 0600 permissions
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(path)
        .map_err(|e| format!("Impossible de créer le swapfile {}: {}", path.display(), e))?;

    let fd = file.as_raw_fd();

    // Instant zero-cost space allocation via OS kernel
    posix_fallocate(fd, 0, size_bytes as i64)
        .map_err(|e| format!("Échec de posix_fallocate (swap instantané) sur {}: {}", path.display(), e))?;

    drop(file);

    // Format with mkswap
    let status = Command::new("mkswap")
        .arg(path)
        .status()
        .map_err(|e| format!("Échec de l'exécution de mkswap: {}", e))?;

    if !status.success() {
        return Err(format!("mkswap a échoué avec le code {:?}", status.code()));
    }

    Ok(())
}

/// Calculate recommended swap size based on total RAM
#[allow(dead_code)]
pub fn recommend_swap_size_mb(total_ram_gb: f64) -> u64 {
    if total_ram_gb <= 4.0 {
        4096 // 4 GB
    } else if total_ram_gb <= 8.0 {
        8192 // 8 GB
    } else if total_ram_gb <= 16.0 {
        8192 // 8 GB
    } else {
        4096 // 4 GB for 32GB+ (emergency suspend only)
    }
}
