"""
Finished Job - Installation completion, summary generation, and cleanup.

Handles the final phase of installation, including:
- Summary generation from all previous jobs
- Clean unmounting of filesystems
- Log saving
- Reboot/shutdown preparation
"""

from __future__ import annotations

import logging
import os
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from omnis.jobs.base import BaseJob, JobContext, JobResult

logger = logging.getLogger(__name__)

# A freshly written target can stay busy for a moment (journal flush, udisks
# probing). Retry a normal umount rather than falling back to a lazy one.
UNMOUNT_ATTEMPTS = 4
UNMOUNT_RETRY_DELAY = 1.0


class FinishedJob(BaseJob):
    """
    Installation completion job.

    Responsibilities:
    - Generate installation summary from previous job results
    - Clean unmounting of target filesystems
    - Save installation logs to target system
    - Prepare for reboot/shutdown/continue
    """

    name = "finished"
    description = "Installation completion and cleanup"

    def __init__(self, config: dict[str, Any] | None = None) -> None:
        """Initialize the finished job."""
        super().__init__(config)
        self._summary: dict[str, Any] = {}
        self._succeeded = False

    def _generate_summary(self, context: JobContext) -> dict[str, Any]:
        """
        Generate installation summary from context selections.

        Args:
            context: Execution context with all job selections

        Returns:
            Dictionary containing installation summary
        """
        selections = context.selections
        summary: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(),
            "target_root": context.target_root,
            "system": {},
            "partitions": {},
            "user": {},
            "locale": {},
            "status": "completed",
        }

        # System information
        system_info: dict[str, Any] = {}
        if "hostname" in selections:
            system_info["hostname"] = selections["hostname"]
        summary["system"] = system_info

        # Partition information
        partition_info: dict[str, Any] = {}
        if "disk" in selections:
            partition_info["disk"] = selections["disk"]
            partition_info["filesystem"] = selections.get("filesystem", "ext4")
            partition_info["mode"] = selections.get("mode", "auto")

            swap_size = selections.get("swap_size", 0)
            if swap_size > 0:
                partition_info["swap_size_gb"] = swap_size
        summary["partitions"] = partition_info

        # User information (without sensitive data)
        user_info: dict[str, Any] = {}
        if "username" in selections:
            user_info["username"] = selections["username"]
            user_info["fullname"] = selections.get("fullname", "")
            user_info["autologin"] = selections.get("autologin", False)
        summary["user"] = user_info

        # Locale information
        locale_info: dict[str, Any] = {}
        if "locale" in selections:
            locale_info["locale"] = selections["locale"]
        if "timezone" in selections:
            locale_info["timezone"] = selections["timezone"]
        if "keymap" in selections:
            locale_info["keymap"] = selections["keymap"]
        summary["locale"] = locale_info

        return summary

    def _save_logs(self, context: JobContext) -> JobResult:
        """
        Save installation logs to target system.

        Args:
            context: Execution context

        Returns:
            JobResult indicating success or failure
        """
        save_logs = context.selections.get("save_logs", True)
        if not save_logs:
            logger.info("Log saving disabled, skipping")
            return JobResult.ok("Log saving skipped")

        target_root = Path(context.target_root)
        log_dir = target_root / "var" / "log" / "omnis-installer"

        try:
            # Create log directory
            log_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"Created log directory: {log_dir}")

            # Save summary as JSON
            import json

            summary_file = log_dir / "install-summary.json"
            summary_file.write_text(
                json.dumps(self._summary, indent=2, ensure_ascii=False), encoding="utf-8"
            )
            logger.info(f"Saved installation summary to {summary_file}")

            # Copy the installer log into the target if present.
            for log_source in [Path("/var/log/omnis-install.log"), Path("/tmp/omnis.log")]:
                if not log_source.exists():
                    continue
                log_dest = log_dir / f"omnis-{datetime.now():%Y%m%d-%H%M%S}.log"
                shutil.copy2(log_source, log_dest)
                logger.info(f"Copied log file: {log_source} -> {log_dest}")
                break

            return JobResult.ok(f"Logs saved to {log_dir}")

        except OSError as e:
            logger.warning(f"Failed to save logs: {e}")
            # Non-critical: continue even if log saving fails
            return JobResult.ok(f"Log saving failed (non-critical): {e}")

    def _get_active_mounts_under(self, target_root: Path) -> list[Path]:
        """
        Discover all active mount points under target_root, sorted deepest first.
        """
        target_str = str(target_root.resolve()).rstrip("/")
        found: set[Path] = set()

        try:
            with open("/proc/mounts", "r", encoding="utf-8") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        mp = parts[1]
                        try:
                            mp_decoded = mp.encode("utf-8").decode("unicode_escape")
                        except Exception:
                            mp_decoded = mp
                        if mp_decoded.startswith(f"{target_str}/"):
                            p = Path(mp_decoded)
                            if p.exists() and os.path.ismount(p):
                                found.add(p)
        except Exception as e:
            logger.warning(f"Failed to read /proc/mounts: {e}")

        # Explicitly check standard submount locations
        for extra in [
            target_root / "boot" / "efi",
            target_root / "boot",
            target_root / "efi",
            target_root / "home",
            target_root / "var",
            target_root / "nix",
            target_root / "dev",
            target_root / "proc",
            target_root / "sys",
        ]:
            if extra.exists() and os.path.ismount(extra):
                found.add(extra)

        # Sort descending by path length so deepest submounts are unmounted first
        return sorted(list(found), key=lambda p: len(str(p)), reverse=True)

    def _safe_unmount(self, mount_point: Path, attempts: int = UNMOUNT_ATTEMPTS) -> bool:
        """
        Unmount a filesystem, retrying with sync, process termination, and fallback.
        """
        if not os.path.ismount(mount_point):
            logger.debug(f"Mount point {mount_point} not mounted, skipping")
            return True

        # Flush dirty buffers first
        subprocess.run(["sync"], check=False)

        last_error = ""
        for attempt in range(1, attempts + 1):
            try:
                subprocess.run(
                    ["umount", str(mount_point)],
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                logger.info(f"Unmounted {mount_point}")
                return True
            except subprocess.CalledProcessError as e:
                last_error = (e.stderr or "").strip() or f"exit code {e.returncode}"
            except subprocess.TimeoutExpired:
                last_error = "umount timed out"
            except FileNotFoundError:
                logger.error("umount command not found")
                return False

            logger.warning(
                f"Failed to unmount {mount_point} (attempt {attempt}/{attempts}): {last_error}"
            )
            if attempt < attempts:
                try:
                    subprocess.run(["fuser", "-km", str(mount_point)], check=False, capture_output=True)
                except Exception:
                    pass
                time.sleep(UNMOUNT_RETRY_DELAY)

        # Fallback: lazy unmount (umount -l)
        logger.warning(f"Attempting lazy unmount for {mount_point}...")
        try:
            subprocess.run(["sync"], check=False)
            res = subprocess.run(
                ["umount", "-l", str(mount_point)],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            if res.returncode == 0:
                logger.info(f"Lazy unmounted {mount_point}")
                return True
            else:
                last_error = (res.stderr or "").strip() or f"exit code {res.returncode}"
        except Exception as e:
            last_error = str(e)

        logger.error(
            f"Giving up on unmounting {mount_point} after {attempts} attempts: {last_error}"
        )
        return False

    def _cleanup_mounts(self, context: JobContext) -> JobResult:
        """
        Clean up all mounted filesystems.

        Unmounts in correct order:
        1. All child submounts (deepest children first, e.g. /boot before root)
        2. /mnt/target (root)
        3. swapoff for active swap partitions
        """
        target_root = Path(context.target_root)
        errors = []

        subprocess.run(["sync"], check=False)

        # 1. Unmount all child mount points under target_root (deepest first)
        child_mounts = self._get_active_mounts_under(target_root)
        for child in child_mounts:
            if os.path.ismount(child):
                if not self._safe_unmount(child):
                    errors.append(f"Failed to unmount submount: {child}")

        # 2. Unmount root partition
        if os.path.ismount(target_root) and not self._safe_unmount(target_root):
            errors.append(f"Failed to unmount root partition: {target_root}")

        # 3. Deactivate swap if it was used
        swap_partition = context.selections.get("swap_partition")
        if swap_partition:
            try:
                subprocess.run(
                    ["swapoff", swap_partition],
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                logger.info(f"Deactivated swap: {swap_partition}")
            except subprocess.CalledProcessError as e:
                logger.warning(f"Failed to deactivate swap: {e.stderr}")
                errors.append(f"Failed to deactivate swap: {swap_partition}")
            except FileNotFoundError:
                logger.warning("swapoff command not found")
            except subprocess.TimeoutExpired:
                logger.error("swapoff timeout")
                errors.append("Swap deactivation timeout")

        # Also check for swap in layout data from partition job
        if "swap" in context.selections:
            swap_path = context.selections["swap"]
            if swap_path and swap_path != swap_partition:
                try:
                    subprocess.run(
                        ["swapoff", swap_path],
                        check=False,
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )
                except Exception:
                    pass

        # Also deactivate swap from /proc/swaps if target disk has swap
        try:
            target_disk = str(context.selections.get("disk", ""))
            with open("/proc/swaps", "r") as f:
                for line in f.readlines()[1:]:
                    swap_dev = line.split()[0]
                    if target_disk and swap_dev.startswith(target_disk):
                        subprocess.run(["swapoff", swap_dev], check=False)
                        logger.info(f"Deactivated swap from /proc/swaps: {swap_dev}")
        except Exception:
            pass

        subprocess.run(["sync"], check=False)

        if errors:
            logger.warning(f"Cleanup finished with warnings: {'; '.join(errors)}")
            # Do NOT fail an already successful installation: data was synced and reboot will clean up
            return JobResult.ok(
                message=f"Cleanup completed with warnings: {'; '.join(errors)}",
                data={"warnings": errors},
            )

        return JobResult.ok("All filesystems unmounted successfully")

    def _prepare_action(self, context: JobContext) -> JobResult:
        """
        Prepare for post-installation action (reboot/shutdown/continue).

        Args:
            context: Execution context

        Returns:
            JobResult with action preparation status
        """
        action = context.selections.get("action", "continue")

        if action == "reboot":
            logger.info("System ready for reboot")
            return JobResult.ok(
                "Ready to reboot",
                data={
                    "action": "reboot",
                    "command": "systemctl reboot",
                },
            )

        elif action == "shutdown":
            logger.info("System ready for shutdown")
            return JobResult.ok(
                "Ready to shutdown",
                data={
                    "action": "shutdown",
                    "command": "systemctl poweroff",
                },
            )

        elif action == "continue":
            logger.info("Installation complete, system ready for inspection")
            return JobResult.ok(
                "Installation complete",
                data={
                    "action": "continue",
                    "message": "You can now inspect the installation or manually reboot.",
                },
            )

        else:
            logger.warning(f"Unknown action: {action}, defaulting to 'continue'")
            return JobResult.ok(
                "Installation complete (unknown action)",
                data={"action": "continue"},
            )

    def validate(self, context: JobContext) -> JobResult:
        """
        Validate that finished job can proceed.

        Args:
            context: Execution context

        Returns:
            JobResult indicating validation status
        """
        # Validate action if specified
        action = context.selections.get("action", "continue")
        valid_actions = ["reboot", "shutdown", "continue"]

        if action not in valid_actions:
            return JobResult.fail(
                f"Invalid action: {action}. Must be one of: {', '.join(valid_actions)}",
                error_code=49,
            )

        # Validate save_logs if specified
        save_logs = context.selections.get("save_logs", True)
        if not isinstance(save_logs, bool):
            return JobResult.fail(
                "Invalid save_logs value: must be boolean",
                error_code=49,
            )

        return JobResult.ok("Finished job configuration valid")

    def run(self, context: JobContext) -> JobResult:
        """
        Execute the finished job.

        Steps:
        1. Generate installation summary
        2. Save logs to target system
        3. Clean up mounted filesystems
        4. Prepare for next action (reboot/shutdown/continue)

        Args:
            context: Execution context

        Returns:
            JobResult indicating success or failure
        """
        context.report_progress(0, "Finishing installation...")

        # Validate first
        validation = self.validate(context)
        if not validation.success:
            return validation

        # Step 1: Generate summary
        context.report_progress(10, "Generating installation summary...")
        self._summary = self._generate_summary(context)
        logger.info("Installation summary generated")

        # Step 2: Save logs
        context.report_progress(30, "Saving installation logs...")
        log_result = self._save_logs(context)
        if not log_result.success:
            logger.warning(f"Log saving failed: {log_result.message}")
            # Continue anyway (non-critical)

        # Step 3: Cleanup mounts
        context.report_progress(60, "Cleaning up filesystems...")
        cleanup_result = self._cleanup_mounts(context)
        if not cleanup_result.success:
            logger.warning(f"Cleanup warning: {cleanup_result.message}")

        # Step 4: Prepare action
        context.report_progress(90, "Preparing for completion...")
        action_result = self._prepare_action(context)

        self._succeeded = True
        context.report_progress(100, "Installation complete!")

        # Build final result data
        result_data = {
            "summary": self._summary,
            "action": action_result.data.get("action", "continue"),
            "reboot_ready": action_result.data.get("action") in ["reboot", "shutdown"],
        }

        if "command" in action_result.data:
            result_data["command"] = action_result.data["command"]

        return JobResult.ok(
            "Installation completed successfully",
            data=result_data,
        )

    def cleanup(self, context: JobContext) -> None:
        """
        Cleanup after job execution failure.
        """
        if self._succeeded:
            return
        logger.info("Running emergency cleanup...")
        cleanup_result = self._cleanup_mounts(context)

        if not cleanup_result.success:
            logger.warning(f"Emergency cleanup warning: {cleanup_result.message}")
        else:
            logger.info("Emergency cleanup completed successfully")

    def estimate_duration(self) -> int:
        """
        Estimate execution time in seconds.

        Returns:
            Estimated duration (finished job is quick)
        """
        return 10
