"""
ChomiamOS install job for Omnis Installer.

Replicates and modernises the ChomiamOS installer sequence:
1. Hash user passwords with SHA-512 crypt.
2. Run `nixos-generate-config --root <target> --dir /tmp/nixos-hw`.
3. Deploy ChomiamOS modular framework into `<target>/etc/nixos`.
4. Inject `hardware-configuration.nix` into `<target>/etc/nixos/hosts/desktop/`.
5. Configure bootloader (EFI vs BIOS) in `<target>/etc/nixos/hosts/desktop/mount.nix`.
6. Generate custom `<target>/etc/nixos/vars.nix` from user selections (identity, desktop, GPU, gaming).
7. Copy NetworkManager Wi-Fi profiles to target.
8. Execute `nixos-install --flake <target>/etc/nixos#default --root <target>` with streamed progress.
"""

from __future__ import annotations

import json
import logging
import os
import re
import resource
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from omnis.jobs.base import BaseJob, JobContext, JobResult

logger = logging.getLogger(__name__)

# Fallback stateVersion when nixos-version cannot be queried.
DEFAULT_STATE_VERSION = "26.05"

# Error codes
ERR_NO_TARGET = 60
ERR_TARGET_MISSING = 61
ERR_FLAKE_SOURCE_MISSING = 62
ERR_NOT_CONFIRMED = 63
ERR_GENERATE_CONFIG = 64
ERR_WRITE_CONFIG = 65
ERR_COPY_FLAKE = 66
ERR_INSTALL = 67
ERR_COMMAND_FAILED = 68
ERR_TOOL_NOT_FOUND = 69
ERR_HASH_FAILED = 70


def _throttled(cmd: list[str]) -> list[str]:
    """Prefix heavy commands with nice+ionice (lower CPU/IO priority)."""
    prefix: list[str] = []
    if shutil.which("nice"):
        prefix += ["nice", "-n", "15"]
    if shutil.which("ionice"):
        prefix += ["ionice", "-c", "2", "-n", "7"]
    return [*prefix, *cmd]


def _throttle_cores() -> int:
    """Target parallelism ~ 80% of CPU cores (leaves room for responsive desktop)."""
    return max(1, int((os.cpu_count() or 1) * 0.8))


def _raise_stack_limit() -> None:
    """Raise stack limit before executing nix evaluation."""
    try:
        _soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
        resource.setrlimit(resource.RLIMIT_STACK, (hard, hard))
    except (ValueError, OSError):
        pass


def _substitution_flags() -> list[str]:
    return ["--option", "max-substitution-jobs", str(max(1, _throttle_cores() - 1))]


class _NixProgress:
    """Monitors nix builds and copies to feed the progress bar."""

    _STORE_PATH_RE = re.compile(r"/nix/store/[a-z0-9]+-(.+?)(?:\.drv|'|$)")
    _BUILDING_RE = re.compile(r"building '([^']+\.drv)'")
    _COPYING_RE = re.compile(r"copying path '([^']+)' (?:to|from) ")
    _WILL_BUILD_RE = re.compile(r"these (\d+) derivations? will be built")
    _WILL_FETCH_RE = re.compile(r"these (\d+) paths? will be fetched")

    def __init__(self, plain_total: int = 0) -> None:
        self._fraction = 0.0
        self._current_pkg = ""
        self._plain_total = plain_total
        self._plain_build_expected = 0
        self._plain_fetch_expected = 0
        self._plain_built = 0
        self._plain_copied = 0

    def feed_plain(self, line: str) -> float | None:
        will_build = self._WILL_BUILD_RE.search(line)
        if will_build:
            self._plain_build_expected = int(will_build.group(1))
            self._plain_total = self._plain_build_expected + self._plain_fetch_expected
            return None
        will_fetch = self._WILL_FETCH_RE.search(line)
        if will_fetch:
            self._plain_fetch_expected = int(will_fetch.group(1))
            self._plain_total = self._plain_build_expected + self._plain_fetch_expected
            return None
        building = self._BUILDING_RE.search(line)
        if building:
            self._plain_built += 1
            self._set_plain_package(building.group(1))
            return self._plain_fraction()
        copying = self._COPYING_RE.search(line)
        if copying:
            self._plain_copied += 1
            self._set_plain_package(copying.group(1))
            return self._plain_fraction()
        return None

    def _set_plain_package(self, store_path: str) -> None:
        match = self._STORE_PATH_RE.search(store_path)
        if match:
            self._current_pkg = match.group(1)

    def _plain_fraction(self) -> float:
        moved = self._plain_built + self._plain_copied
        if self._plain_total > 0:
            ratio = min(1.0, moved / self._plain_total)
        else:
            ratio = 1.0 - 1.0 / (1.0 + moved / 40.0)
        self._fraction = max(self._fraction, ratio)
        return self._fraction

    def has_total(self) -> bool:
        return self._plain_total > 0

    def current_package(self) -> str:
        return self._current_pkg

    def message(self) -> str:
        copied = (
            f"{self._plain_copied}/{self._plain_total} copiés"
            if self._plain_total
            else f"{self._plain_copied} copiés"
        )
        seg = f"{self._plain_built} construits, {copied}"
        if self._current_pkg:
            seg += f" ({self._current_pkg})"
        return f"Installation de ChomiamOS: {seg}"


@dataclass(frozen=True)
class PasswordHashes:
    user: str = ""
    root: str = ""


class NixosJob(BaseJob):
    name = "nixos"
    description = "Génération de la configuration et déploiement de ChomiamOS"

    required_tools = (
        "nixos-generate-config",
        "nixos-install",
        ("mkpasswd", "openssl"),
    )

    def _flake_attr(self) -> str:
        return str(self._config.get("flake_attr", "default"))

    @staticmethod
    def _detect_state_version() -> str:
        try:
            out = subprocess.run(
                ["nixos-version"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError, OSError):
            return DEFAULT_STATE_VERSION
        parts = out.split(".")
        if len(parts) >= 2:
            return f"{parts[0]}.{parts[1]}"[:5]
        return DEFAULT_STATE_VERSION

    @staticmethod
    def _detect_gpu() -> str:
        try:
            res = subprocess.run(["lspci"], capture_output=True, text=True, check=False)
            out = (res.stdout or "").lower()
            if "nvidia" in out or "geforce" in out:
                return "nvidia"
            elif "amd" in out or "radeon" in out or "advanced micro devices" in out:
                return "amd"
            elif "intel" in out or "iris" in out or "arc" in out:
                return "intel"
        except Exception:
            pass
        return "amd"

    def _build_vars_nix(self, context: JobContext, hashes: PasswordHashes) -> str:
        s = context.selections
        hostname = str(s.get("hostname") or "chomiamos")
        timezone = str(s.get("timezone") or "Europe/Paris")
        locale = str(s.get("locale") or s.get("language") or "fr_FR.UTF-8").replace(".utf8", ".UTF-8").replace(".UTF8", ".UTF-8")
        username = str(s.get("username") or "chomiam")
        fullname = str(s.get("fullname") or "ChomiamOS User")
        de = str(s.get("desktop_environment") or "gnome").strip().lower()
        desktop_env = "cosmic" if de == "cosmic" else "gnome"
        gpu = self._detect_gpu()
        state_ver = self._detect_state_version()
        browser = str(s.get("browser") or "chrome").strip().lower()
        discord_client = str(s.get("discord_client") or s.get("discordClient") or "discord").strip().lower()

        # Gaming selections
        gaming_enable = "true" if s.get("gaming_enable", s.get("gamingEnable", True)) else "false"
        steam = "true" if s.get("steam", True) else "false"
        lutris = "true" if s.get("lutris", True) else "false"
        heroic = "true" if s.get("heroic", True) else "false"
        faugus = "true" if s.get("faugus", True) else "false"
        decky_loader = "true" if s.get("decky_loader", s.get("deckyLoader", True)) else "false"
        geforce_now = "true" if s.get("geforce_now", s.get("geforceNow", True)) else "false"
        steering_wheels = "true" if s.get("steering_wheels", s.get("steeringWheels", True)) else "false"

        # Creative & Pro tools selections
        davinci = str(s.get("davinci_resolve") or s.get("davinciResolve") or "none").strip().lower()
        blender = "true" if s.get("blender", True) else "false"
        godot = "true" if s.get("godot", True) else "false"
        virtualisation = "true" if s.get("virtualisation", True) else "false"
        ai_suite = "true" if s.get("ai_suite", s.get("aiSuite", False)) else "false"

        hashed_pwd = f'"{hashes.user}"' if hashes.user else "null"

        return f"""{{
  # =========================================================================
  # ⚙️ VARIABLES DU SYSTÈME CHOMIAMOS GAMING EDITION (GÉNÉRÉ PAR OMNIS)
  # =========================================================================

  # Nom d'hôte de la machine (Hostname)
  hostName = "{hostname}";

  # Localisation & Fuseau horaire
  timeZone = "{timezone}";
  defaultLocale = "{locale}";

  # Version de l'état système NixOS / Home Manager
  stateVersion = "{state_ver}";

  # Profil utilisateur principal
  user = {{
    username = "{username}";
    fullName = "{fullname}";
    homeDirectory = "/home/{username}";
    shell = "fish";
    initialHashedPassword = {hashed_pwd};
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
    ];
  }};

  virtualisation = {{
    enable = {virtualisation};
  }};

  browser = "{browser}";
  discordClient = "{discord_client}";
  firewall = false;

  desktopEnv = "{desktop_env}";
  gpuDriver = "{gpu}";

  gaming = {{
    enable = {gaming_enable};
    launchers = {{
      steam = {steam};
      lutris = {lutris};
      heroic = {heroic};
      faugus = {faugus};
    }};
    deckyLoader = {decky_loader};
    geforceNow = {geforce_now};
    mountGamesDisk = false;
  }};

  steeringWheelSupport = {steering_wheels};

  davinciResolve = "{davinci}";
  blender = {blender};
  godot = {godot};

  aiSuite = {{
    enable = {ai_suite};
    rocmOverrideGfx = "12.0.1";
    keepAlive = "0s";
    openWebUiPort = 8080;
    searxPort = 8888;
  }};
}}
"""

    def _hash_password(self, password: str) -> str:
        candidates: list[list[str]] = []
        if shutil.which("mkpasswd"):
            candidates.append(["mkpasswd", "-m", "sha-512", "--stdin"])
        if shutil.which("openssl"):
            candidates.append(["openssl", "passwd", "-6", "-stdin"])

        if not candidates:
            raise RuntimeError("Aucun outil de hachage trouvé (mkpasswd ou openssl requis)")

        for cmd in candidates:
            try:
                proc = subprocess.run(
                    cmd,
                    input=password,
                    capture_output=True,
                    text=True,
                    check=True,
                )
                h = proc.stdout.strip()
                if h.startswith("$6$"):
                    return h
            except Exception as e:
                logger.warning("%s failed: %s", cmd[0], e)

        raise RuntimeError("Échec du calcul du hash de mot de passe")

    def _compute_password_hashes(self, context: JobContext) -> PasswordHashes:
        s = context.selections
        user_password = str(s.get("password", "") or "")
        root_password = str(s.get("root_password", "") or "")
        root_same = bool(s.get("root_same_as_user", True))

        user_hash = self._hash_password(user_password) if user_password else ""
        if root_same or not root_password:
            root_hash = user_hash if root_same else ""
        else:
            root_hash = self._hash_password(root_password)

        return PasswordHashes(user=user_hash, root=root_hash)

    def validate(self, context: JobContext) -> JobResult:
        context.report_progress(0, "Validation de la configuration d'installation...")
        target_root = context.target_root
        if not target_root:
            return JobResult.fail("Point de montage cible requis", error_code=ERR_NO_TARGET)

        dry_run = bool(context.selections.get("dry_run", True))
        if not dry_run and not Path(target_root).is_dir():
            return JobResult.fail(
                f"Disque cible non monté: {target_root}",
                error_code=ERR_TARGET_MISSING,
            )

        context.report_progress(5, "Validation réussie")
        return JobResult.ok(
            "Configuration valide",
            data={"target_root": target_root, "flake_attr": self._flake_attr()},
        )

    def run(self, context: JobContext) -> JobResult:
        context.report_progress(0, "Démarrage de l'installation de ChomiamOS...")

        validation = self.validate(context)
        if not validation.success:
            return validation

        s = context.selections
        dry_run = bool(s.get("dry_run", True))
        confirmed = bool(s.get("confirmed", False))

        if not dry_run and not confirmed:
            return JobResult.fail(
                "SÉCURITÉ: Une confirmation explicite est requise pour installer.",
                error_code=ERR_NOT_CONFIRMED,
            )

        target_root = context.target_root
        hashes = PasswordHashes()
        try:
            if dry_run:
                logger.info("DRY-RUN MODE: simulation de l'installation ChomiamOS")
            else:
                logger.warning("INSTALLATION RÉELLE DE CHOMIAMOS sur %s", target_root)

            context.report_progress(8, "Préparation des identifiants et clés de sécurité...")
            try:
                hashes = self._compute_password_hashes(context)
            except RuntimeError as exc:
                logger.error("Échec de hachage: %s", exc)
                return JobResult.fail(f"Erreur de hachage de mot de passe: {exc}", error_code=ERR_HASH_FAILED)

            context.report_progress(12, "Génération des variables personnalisées (vars.nix)...")
            vars_cfg = self._build_vars_nix(context, hashes)

            context.report_progress(20, "Détection matérielle du système (nixos-generate-config)...")
            result = self._generate_config(target_root, dry_run)
            if not result.success:
                return result

            context.report_progress(35, "Déploiement du framework modulaire ChomiamOS...")
            result = self._write_config_and_flake(target_root, vars_cfg, context, dry_run)
            if not result.success:
                return result

            context.report_progress(50, "Copie des configurations réseau (Wi-Fi / Ethernet)...")
            self._copy_network_config(target_root, dry_run)

            context.report_progress(55, "Sécurisation des répertoires de build Nix...")
            secure_tmpdir = self._harden_target(target_root, dry_run)

            context.report_progress(60, "Déploiement du système NixOS (nixos-install)...")
            result = self._nixos_install(target_root, dry_run, context, secure_tmpdir)
            if not result.success:
                return result

            context.report_progress(100, "Installation de ChomiamOS terminée avec succès !")
            return JobResult.ok(
                f"ChomiamOS installé avec succès sur {target_root}",
                data={
                    "target_root": target_root,
                    "flake_attr": self._flake_attr(),
                    "dry_run": dry_run,
                },
            )
        finally:
            hashes = PasswordHashes()
            del hashes

    def _generate_config(self, target_root: str, dry_run: bool) -> JobResult:
        if dry_run:
            logger.info("[DRY-RUN] nixos-generate-config --root %s --dir /tmp/nixos-hw", target_root)
            return JobResult.ok("[DRY-RUN] Generating hardware config")
        os.makedirs("/tmp/nixos-hw", exist_ok=True)
        return self._run_command(
            ["nixos-generate-config", "--root", target_root, "--dir", "/tmp/nixos-hw"],
            description="Génération de hardware-configuration.nix",
            dry_run=dry_run,
            error_code=ERR_GENERATE_CONFIG,
        )

    def _write_config_and_flake(self, target_root: str, vars_cfg: str, context: JobContext, dry_run: bool) -> JobResult:
        etc_nixos = Path(target_root) / "etc" / "nixos"
        if dry_run:
            logger.info("[DRY-RUN] Déploiement de la configuration ChomiamOS vers %s", etc_nixos)
            return JobResult.ok("[DRY-RUN] Déploiement ChomiamOS")

        try:
            etc_nixos.mkdir(parents=True, exist_ok=True)

            # 1. Copie locale du framework si disponible sur le Live, sinon clone GitHub
            if not (etc_nixos / "flake.nix").is_file():
                copied = False
                for src in ("/etc/nixos", "/iso/nixos", "/iso-cfg"):
                    p = Path(src)
                    if (p / "flake.nix").is_file() and (p / "hosts" / "desktop").is_dir():
                        logger.info("Copie locale du framework depuis %s...", src)
                        self._run_command(["cp", "-a", f"{src}/.", str(etc_nixos)], description=f"Copie framework depuis {src}", dry_run=False)
                        copied = True
                        break

                if not copied:
                    logger.info("Téléchargement du framework officiel ChomiamOS depuis GitHub...")
                    self._run_command(
                        ["git", "clone", "https://github.com/Chomiam/nix_config_gaming.git", str(etc_nixos)],
                        description="Clone ChomiamOS git",
                        dry_run=False,
                    )

            # 2. Copie de hardware-configuration.nix vers hosts/desktop/
            hw_src = Path("/tmp/nixos-hw/hardware-configuration.nix")
            hw_dest = etc_nixos / "hosts" / "desktop" / "hardware-configuration.nix"
            if hw_src.is_file():
                hw_dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(hw_src, hw_dest)
                logger.info("hardware-configuration.nix copié vers %s", hw_dest)

            # 3. Écriture de mount.nix (Mode UEFI vs BIOS hérité)
            mount_path = etc_nixos / "hosts" / "desktop" / "mount.nix"
            disk = str(context.selections.get("disk") or "/dev/sda")
            is_efi = Path("/sys/firmware/efi").is_dir()
            if is_efi:
                mount_content = """{ config, ... }:
{
  # Déclarez ici vos disques additionnels (ex: /mnt/Games)
}
"""
            else:
                mount_content = f"""{{ config, lib, ... }}:
{{
  # Machine en mode BIOS hérité (non-UEFI)
  boot.loader.grub.efiSupport = lib.mkForce false;
  boot.loader.grub.device = lib.mkForce "{disk}";
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}}
"""
            mount_path.write_text(mount_content, encoding="utf-8")

            # 4. Écriture du fichier vars.nix
            vars_path = etc_nixos / "vars.nix"
            vars_path.write_text(vars_cfg, encoding="utf-8")
            logger.info("Fichier vars.nix écrit avec succès sur %s", vars_path)

            # 5. Indexation Git (indispensable pour les Flakes Nix)
            if not (etc_nixos / ".git").is_dir():
                subprocess.run(["git", "-C", str(etc_nixos), "init"], check=False)
            subprocess.run(["git", "-C", str(etc_nixos), "add", "-A"], check=False)

            return JobResult.ok("Configuration et framework ChomiamOS déployés avec succès")
        except Exception as e:
            logger.error("Erreur lors de l'écriture de la configuration: %s", e)
            return JobResult.fail(f"Erreur d'écriture de la configuration: {e}", error_code=ERR_WRITE_CONFIG)

    def _copy_network_config(self, target_root: str, dry_run: bool) -> None:
        src = Path("/etc/NetworkManager/system-connections")
        if not src.is_dir():
            return
        dest = Path(target_root) / "etc" / "NetworkManager" / "system-connections"
        if dry_run:
            logger.info("[DRY-RUN] Copie des profils NetworkManager vers %s", dest)
            return
        try:
            dest.mkdir(parents=True, exist_ok=True)
            os.chmod(dest, 0o700)
            for conn in sorted(src.glob("*.nmconnection")):
                target = dest / conn.name
                target.write_bytes(conn.read_bytes())
                os.chmod(target, 0o600)
                os.chown(target, 0, 0)
                logger.info("Profil NetworkManager copié: %s", conn.name)
        except Exception as exc:
            logger.warning("Copie NetworkManager ignorée: %s", exc)

    def _harden_target(self, target_root: str, dry_run: bool) -> str:
        secure_tmpdir = os.path.join(target_root, "var/tmp/nix-installer")
        if dry_run:
            return secure_tmpdir
        entries = [
            (target_root, 0o755),
            (secure_tmpdir, 0o700),
            (os.path.join(target_root, "nix"), 0o755),
            (os.path.join(target_root, "nix/var"), 0o755),
            (os.path.join(target_root, "nix/var/nix"), 0o755),
            (os.path.join(target_root, "nix/var/nix/builds"), 0o755),
            (os.path.join(target_root, "nix/var/nix/db"), 0o755),
            (os.path.join(target_root, "nix/var/nix/profiles"), 0o755),
        ]
        for path, mode in entries:
            try:
                os.makedirs(path, exist_ok=True)
                os.chmod(path, mode)
                os.chown(path, 0, 0)
            except OSError:
                pass
        return secure_tmpdir

    def _nixos_install(
        self,
        target_root: str,
        dry_run: bool,
        context: JobContext | None = None,
        tmpdir: str | None = None,
    ) -> JobResult:
        flake_ref = f"{target_root}/etc/nixos#{self._flake_attr()}"
        cmd = [
            "nixos-install",
            "--no-root-passwd",
            "--option",
            "sandbox",
            "false",
            "--option",
            "build-users-group",
            "",
            "--flake",
            flake_ref,
            "--root",
            target_root,
        ]
        return self._run_install_streamed(
            _throttled([*cmd, *_substitution_flags()]),
            "Exécution de nixos-install",
            dry_run,
            context,
            tmpdir,
            pct_start=60,
            pct_end=100,
            allow_indeterminate=True,
        )

    def _run_install_streamed(
        self,
        cmd: list[str],
        description: str,
        dry_run: bool,
        context: JobContext | None,
        tmpdir: str | None = None,
        pct_start: int = 60,
        pct_end: int = 98,
        allow_indeterminate: bool = False,
    ) -> JobResult:
        if dry_run:
            logger.info("[DRY-RUN] %s: %s", description, " ".join(cmd))
            return JobResult.ok(f"[DRY-RUN] {description}")

        env = dict(os.environ)
        if tmpdir:
            env["TMPDIR"] = tmpdir

        logger.info("Exécution: %s", description)
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                env=env,
                preexec_fn=_raise_stack_limit,
            )
        except FileNotFoundError:
            return JobResult.fail(f"Outil requis introuvable: {cmd[0]}", error_code=ERR_TOOL_NOT_FOUND)

        span = max(0, pct_end - pct_start)
        progress = _NixProgress()
        pulsing = allow_indeterminate and not progress.has_total()
        if pulsing and context is not None:
            context.report_indeterminate(True)
            context.report_progress(pct_start, progress.message())

        assert proc.stdout is not None
        for raw in proc.stdout:
            line = raw.rstrip("\n")
            fraction = progress.feed_plain(line)
            if fraction is not None and context is not None:
                if pulsing and progress.has_total():
                    pulsing = False
                    context.report_indeterminate(False)
                if pulsing:
                    context.report_progress(pct_start, progress.message())
                else:
                    pct = pct_start + round(span * fraction)
                    context.report_progress(min(pct_end, pct), progress.message())
            elif fraction is None:
                logger.debug("nixos-install: %s", line)

        code = proc.wait()
        if pulsing and context is not None:
            context.report_indeterminate(False)
        if code != 0:
            logger.error("ÉCHEC: %s (code %s)", description, code)
            return JobResult.fail(f"{description} a échoué (code {code})", error_code=ERR_INSTALL)

        if context is not None:
            context.report_progress(pct_end, progress.message())
        return JobResult.ok(description)

    def _run_command(
        self,
        cmd: list[str],
        description: str,
        dry_run: bool,
        error_code: int = ERR_COMMAND_FAILED,
    ) -> JobResult:
        if dry_run:
            logger.info("[DRY-RUN] %s: %s", description, " ".join(cmd))
            return JobResult.ok(f"[DRY-RUN] {description}")

        logger.info("Exécution: %s", description)
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            if result.stdout:
                logger.debug("stdout: %s", result.stdout)
            return JobResult.ok(description)
        except subprocess.CalledProcessError as e:
            logger.error("ÉCHEC: %s: %s", description, e.stderr)
            return JobResult.fail(f"{description} a échoué: {e.stderr}", error_code=error_code)
        except FileNotFoundError:
            return JobResult.fail(f"Outil introuvable: {cmd[0]}", error_code=ERR_TOOL_NOT_FOUND)

    def cleanup(self, context: JobContext) -> None:
        if bool(context.selections.get("dry_run", True)):
            return
        target_root = context.target_root
        if not target_root:
            return
        try:
            subprocess.run(["umount", "-R", target_root], check=False, capture_output=True, text=True)
            logger.info("Démontage récursif de %s réussi", target_root)
        except Exception as e:
            logger.debug("Erreur de démontage %s: %s", target_root, e)

    def estimate_duration(self) -> int:
        return 900
