"""Shared constants/helpers for the read-only FieldWiring renderer."""
from __future__ import annotations

import datetime as dt
import os
import re
from typing import Any
from zoneinfo import ZoneInfo

from field_context_resolver import (
    DEFAULT_WINDOWS_DRIVE_ROOT,
    MARKER_NAME,
    SKIP_SCOPE_SEARCH,
)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}
DEFAULT_DRIVE_ROOT = DEFAULT_WINDOWS_DRIVE_ROOT
DEFAULT_TIMEZONE = "America/Chicago"


class WiringError(RuntimeError):
    pass


def natural_key(value: str | None) -> list[Any]:
    parts = re.split(r"(\d+)", value or "")
    return [int(part) if part.isdigit() else part.casefold() for part in parts]


def controller_sort(value: str | None) -> tuple[int, Any]:
    text = (value or "").strip()
    if re.fullmatch(r"[0-9A-Fa-f]+", text):
        return 0, int(text, 16)
    if text.isdigit():
        return 0, int(text)
    return 1, text.casefold()


def context_type(preview_name: str | None) -> str:
    name = (preview_name or "").casefold()
    if "master musical" in name:
        return "Musical"
    if "show animation" in name:
        return "Animation"
    if "show background" in name or name.startswith("show stage"):
        return "Background / Static"
    return "Other"


def local_now() -> dt.datetime:
    timezone_name = os.environ.get("FIELDWIRING_TIMEZONE", DEFAULT_TIMEZONE).strip() or DEFAULT_TIMEZONE
    try:
        timezone = ZoneInfo(timezone_name)
    except Exception as exc:
        raise WiringError(f"Invalid FIELDWIRING_TIMEZONE: {timezone_name}") from exc
    return dt.datetime.now(timezone)


def end_of_local_day(now: dt.datetime) -> dt.datetime:
    return now.replace(hour=23, minute=59, second=59, microsecond=0)
