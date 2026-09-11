"""
Système de gestion des versions et mise à jour automatique pour ChomiamOS Installer.
"""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable, Optional

logger = logging.getLogger(__name__)

GITHUB_REPO = "Chomiam/chomiamos-installer"
UPDATE_DIR = Path("/tmp/omnis-update")


def parse_version(version_str: str) -> tuple[int, ...]:
    """
    Découpe une chaîne de version (ex: \"v1.0.2\", \"0.6.2\") en tuple d'entiers
    pour comparaison numérique fiable.
    """
    cleaned = version_str.strip().lstrip("vV")
    numbers = re.findall(r"\d+", cleaned)
    if not numbers:
        return (0,)
    return tuple(int(n) for n in numbers)


def check_for_github_update(
    current_version: str,
    repo: str = GITHUB_REPO,
    timeout: float = 4.0,
) -> Optional[dict]:
    """
    Interroge l'API GitHub pour vérifier si une version plus récente est disponible.
    Retourne un dictionnaire contenant les métadonnées si une mise à jour est trouvée,
    ou None sinon (ou si hors-ligne / erreur).
    """
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {
        "User-Agent": "ChomiamOS-Installer-Updater",
        "Accept": "application/vnd.github.v3+json",
    }
    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            # Aucune release officielle publiée, essayons les tags
            return _check_github_tags(current_version, repo, timeout)
        logger.debug("Erreur HTTP lors de la vérification de mise à jour: %s", e)
        return None
    except Exception as e:
        logger.debug("Vérification de mise à jour ignorée (hors ligne ou inaccessible): %s", e)
        return None

    remote_tag = data.get("tag_name", "")
    if not remote_tag:
        return None

    cur_ver = parse_version(current_version)
    rem_ver = parse_version(remote_tag)

    if rem_ver > cur_ver:
        # Recherche d'un asset .tar.gz ou utilisation de tarball_url
        download_url = data.get("tarball_url", "")
        for asset in data.get("assets", []):
            asset_name = asset.get("name", "").lower()
            if asset_name.endswith(".tar.gz") or asset_name.endswith(".tgz"):
                download_url = asset.get("browser_download_url", download_url)
                break

        return {
            "version": remote_tag.lstrip("vV"),
            "raw_tag": remote_tag,
            "title": data.get("name") or f"Version {remote_tag}",
            "notes": data.get("body") or "Mise à jour disponible.",
            "download_url": download_url,
            "published_at": data.get("published_at", ""),
        }

    return None


def _check_github_tags(current_version: str, repo: str, timeout: float) -> Optional[dict]:
    """Fallback si aucune release officielle n'a été créée (vérifie les tags)."""
    url = f"https://api.github.com/repos/{repo}/tags"
    headers = {
        "User-Agent": "ChomiamOS-Installer-Updater",
        "Accept": "application/vnd.github.v3+json",
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None
            tags = json.loads(resp.read().decode("utf-8"))
            if not tags or not isinstance(tags, list):
                return None
            latest_tag = tags[0]
            tag_name = latest_tag.get("name", "")
            if parse_version(tag_name) > parse_version(current_version):
                return {
                    "version": tag_name.lstrip("vV"),
                    "raw_tag": tag_name,
                    "title": f"Mise à jour {tag_name}",
                    "notes": "Nouvelle version disponible sur GitHub.",
                    "download_url": latest_tag.get("tarball_url", ""),
                    "published_at": "",
                }
    except Exception as e:
        logger.debug("Échec vérification tags: %s", e)
    return None


def download_and_extract_update(
    download_url: str,
    progress_callback: Callable[[int, str], None],
    target_dir: Path = UPDATE_DIR,
) -> Path:
    """
    Télécharge l'archive de mise à jour, l'extrait dans target_dir et normalise l'arborescence.
    """
    if not download_url:
        raise ValueError("URL de téléchargement introuvable.")

    target_dir.mkdir(parents=True, exist_ok=True)
    archive_path = target_dir / "update_package.tar.gz"

    progress_callback(5, "Connexion au serveur de mise à jour...")

    req = urllib.request.Request(
        download_url,
        headers={
            "User-Agent": "ChomiamOS-Installer-Updater",
            "Accept": "application/octet-stream, application/vnd.github.v3+json, */*",
        },
    )

    with urllib.request.urlopen(req, timeout=30.0) as resp:
        content_length_str = resp.headers.get("Content-Length", "0")
        try:
            total_size = int(content_length_str)
        except ValueError:
            total_size = 0

        downloaded = 0
        chunk_size = 64 * 1024

        with open(archive_path, "wb") as f_out:
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                f_out.write(chunk)
                downloaded += len(chunk)

                if total_size > 0:
                    pct = min(80, int((downloaded / total_size) * 75) + 5)
                    progress_callback(pct, f"Téléchargement : {int((downloaded / total_size) * 100)}%")
                else:
                    progress_callback(40, f"Téléchargement : {downloaded // 1024} Ko...")

    progress_callback(82, "Extraction et vérification de la mise à jour...")

    extract_tmp = target_dir / "extracted"
    if extract_tmp.exists():
        shutil.rmtree(extract_tmp, ignore_errors=True)
    extract_tmp.mkdir(parents=True, exist_ok=True)

    with tarfile.open(archive_path, "r:*") as tar:
        tar.extractall(path=extract_tmp)

    # Si l'archive contient un unique dossier racine (ex: Chomiam-chomiamos-installer-7a3b123)
    entries = list(extract_tmp.iterdir())
    if len(entries) == 1 and entries[0].is_dir():
        root_dir = entries[0]
    else:
        root_dir = extract_tmp

    # Nettoyage des anciennes cibles dans target_dir (src, config, etc.)
    for item in ("src", "config", "data"):
        dest = target_dir / item
        src = root_dir / item
        if src.exists():
            if dest.exists():
                if dest.is_dir():
                    shutil.rmtree(dest, ignore_errors=True)
                else:
                    dest.unlink()
            shutil.copytree(src, dest)

    progress_callback(95, "Préparation du redémarrage...")

    # Nettoyage de l'archive temporaire et du dossier d'extraction brut
    if archive_path.exists():
        archive_path.unlink()
    shutil.rmtree(extract_tmp, ignore_errors=True)

    progress_callback(100, "Mise à jour terminée. Redémarrage...")
    return target_dir


def restart_installer(update_dir: Path = UPDATE_DIR) -> None:
    """
    Redémarre l'application en réexécutant le processus avec PYTHONPATH pointant
    vers la mise à jour extraite.
    """
    logger.info("Redémarrage de ChomiamOS Installer avec la nouvelle version depuis %s", update_dir)

    env = os.environ.copy()
    src_dir = str(update_dir / "src")
    existing_pythonpath = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = f"{src_dir}:{existing_pythonpath}" if existing_pythonpath else src_dir
    env["OMNIS_UPDATED_DIR"] = str(update_dir)

    executable = sys.argv[0]
    args = list(sys.argv)

    # Réexécution atomique
    os.execvpe(executable, args, env)
