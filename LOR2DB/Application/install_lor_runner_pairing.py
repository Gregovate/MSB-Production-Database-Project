"""Install a one-time Windows runner pairing secret into the Linux API env.

The Windows launcher transfers the generated secret to a mode-0600 pending
file through SSH.  This root-only installer atomically updates the protected
API environment, removes the pending file, and reports only a SHA-256
fingerprint.  It never prints or accepts the secret as a command-line value.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import ipaddress
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile
from urllib.parse import urlparse


INSTALLER_VERSION = "V1.0.0"
TOKEN_PATTERN = re.compile(r"[0-9a-fA-F]{64}")


def credential_fingerprint(token: str) -> str:
    """Match the safe fingerprint printed by the Windows runner."""
    return hashlib.sha256(f"Bearer {token}".encode("utf-8")).hexdigest()[:16]


def validate_runner_url(value: str) -> str:
    """Allow only an uncredentialed HTTP URL to a private IP and fixed port."""
    parsed = urlparse(value)
    if (
        parsed.scheme != "http"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
        or parsed.port != 8791
    ):
        raise ValueError("Runner URL must be http://<private-ip>:8791")
    try:
        address = ipaddress.ip_address(parsed.hostname)
    except ValueError as error:
        raise ValueError("Runner URL must use a private IP address") from error
    if not address.is_private:
        raise ValueError("Runner URL must use a private IP address")
    return value.rstrip("/")


def upsert_environment(source: str, replacements: dict[str, str]) -> str:
    """Replace named dotenv assignments once while preserving unrelated text."""
    emitted: set[str] = set()
    output: list[str] = []
    for line in source.splitlines():
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=", line)
        key = match.group(1) if match else None
        if key in replacements:
            if key not in emitted:
                output.append(f"{key}={replacements[key]}")
                emitted.add(key)
        else:
            output.append(line)
    missing = [key for key in replacements if key not in emitted]
    if missing:
        if output and output[-1]:
            output.append("")
        output.extend(f"{key}={replacements[key]}" for key in missing)
    return "\n".join(output) + "\n"


def install_pairing(
    pending_file: Path,
    environment_file: Path,
    runner_url: str,
    *,
    expected_pending_uid: int | None = None,
) -> tuple[Path, str]:
    """Consume a protected pending token and atomically update the API env."""
    runner_url = validate_runner_url(runner_url)
    for path, label in (
        (pending_file, "Pending token file"),
        (environment_file, "API environment file"),
    ):
        if path.is_symlink():
            raise RuntimeError(f"{label} must not be a symbolic link: {path}")
        if not path.is_file():
            raise RuntimeError(f"{label} was not found: {path}")

    pending_stat = pending_file.stat()
    pending_mode = stat.S_IMODE(pending_stat.st_mode)
    if pending_mode & 0o077:
        raise RuntimeError("Pending token file must not be accessible by group or others")
    if expected_pending_uid is not None and pending_stat.st_uid != expected_pending_uid:
        raise RuntimeError("Pending token file is not owned by the invoking operator")

    token = pending_file.read_text(encoding="utf-8").strip()
    if not TOKEN_PATTERN.fullmatch(token):
        raise RuntimeError("Pending token must contain exactly 64 hexadecimal characters")

    environment_stat = environment_file.stat()
    current = environment_file.read_text(encoding="utf-8")
    updated = upsert_environment(current, {
        "LOR_RUNNER_URL": runner_url,
        "LOR_RUNNER_TOKEN": token,
    })

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%fZ")
    backup = environment_file.with_name(
        f"{environment_file.name}.pre-runner-pairing-{stamp}.bak"
    )
    shutil.copy2(environment_file, backup)

    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=environment_file.parent,
            prefix=f".{environment_file.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary.write(updated)
            temporary.flush()
            os.fsync(temporary.fileno())
            temporary_name = temporary.name
        os.chmod(temporary_name, stat.S_IMODE(environment_stat.st_mode))
        os.chown(temporary_name, environment_stat.st_uid, environment_stat.st_gid)
        os.replace(temporary_name, environment_file)
        temporary_name = None
    finally:
        if temporary_name:
            Path(temporary_name).unlink(missing_ok=True)

    pending_file.unlink()
    return backup, credential_fingerprint(token)


def default_pending_file() -> Path:
    operator = os.environ.get("SUDO_USER") or os.environ.get("USER") or "msbadmin"
    return Path("/home") / operator / ".msb-lor-runner-token.pending"


def command_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Install the protected LOR Windows-runner pairing secret"
    )
    parser.add_argument("--pending-file", type=Path)
    parser.add_argument(
        "--environment-file",
        type=Path,
        default=Path("/etc/msb/lor-preflight-api.env"),
    )
    parser.add_argument(
        "--runner-url",
        default="http://192.168.5.55:8791",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = command_parser().parse_args(argv)
    if os.name != "nt" and os.geteuid() != 0:
        raise SystemExit("Run this installer with sudo; no changes were made")
    pending_file = arguments.pending_file or default_pending_file()
    expected_uid = None
    if os.environ.get("SUDO_UID"):
        expected_uid = int(os.environ["SUDO_UID"])
    backup, fingerprint = install_pairing(
        pending_file.absolute(),
        arguments.environment_file.absolute(),
        arguments.runner_url,
        expected_pending_uid=expected_uid,
    )
    print(f"[OK] LOR runner pairing installer {INSTALLER_VERSION} completed")
    print(f"[OK] Credential fingerprint: {fingerprint}")
    print(f"[OK] Previous environment backup: {backup}")
    print("[INFO] Pending plaintext token file removed")
    print("[INFO] Restart the API only after backend V0.5.1 is deployed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
