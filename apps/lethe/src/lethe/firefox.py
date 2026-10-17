"""Core, web-free logic for reading and pruning Firefox form history.

Firefox stores autofill form history unencrypted in ``formhistory.sqlite`` inside
the profile directory. Since FF57 the WebExtensions API cannot read this store,
so a local tool that reads/edits the SQLite file directly is the only option.

Safety model:
    * Reads always go through a temp copy opened read-only (Firefox holds an
      exclusive lock while running, and we never want to touch the live file).
    * Writes go to the live DB but are refused while Firefox is running, and a
      timestamped backup is taken first.
    * Deletes insert Sync tombstones into ``moz_deleted_formhistory`` so that
      Firefox Sync does not resurrect removed rows.
"""

import configparser
import csv
import io
import json
import re
import shutil
import sqlite3
import subprocess
import tempfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from pydantic import BaseModel

from lethe.settings import Category, Settings

# moz_formhistory / moz_deleted_formhistory timestamps are microseconds since epoch.
US_PER_SECOND = 1_000_000

# Preset value patterns for common junk.
NUMERIC_2FA_PATTERN = r"^\d{4,8}$"


class FirefoxRunningError(RuntimeError):
    """Raised when a write is attempted while Firefox is running."""


class FormEntry(BaseModel):
    """A single row of Firefox form history."""

    id: int
    fieldname: str
    value: str
    times_used: int | None = None
    first_used: datetime | None = None
    last_used: datetime | None = None
    guid: str | None = None
    sources: list[str] = []


def _us_to_datetime(value: int | None) -> datetime | None:
    """Convert a microsecond epoch timestamp to an aware UTC datetime."""
    if value is None:
        return None
    return datetime.fromtimestamp(value / US_PER_SECOND, tz=timezone.utc)


def _now_us() -> int:
    return int(datetime.now(tz=timezone.utc).timestamp() * US_PER_SECOND)


def resolve_profile(settings: Settings) -> Path:
    """Resolve the ``formhistory.sqlite`` path for the active Firefox profile.

    Precedence (matches how Firefox itself selects the profile):
        1. Explicit ``settings.db_path`` override.
        2. An ``[Install*]`` section's ``Default=`` — a path (relative to the
           Firefox root) to the profile actually in use.
        3. Legacy fallback: the ``[Profile*]`` section with ``Default=1``.

    Raises:
        FileNotFoundError: if ``profiles.ini`` or the resolved DB is missing.
    """
    if settings.db_path is not None:
        db = settings.db_path.expanduser()
        if not db.exists():
            raise FileNotFoundError(f"Configured db_path does not exist: {db}")
        return db

    root = settings.firefox_root.expanduser()
    ini_path = root / "profiles.ini"
    if not ini_path.exists():
        raise FileNotFoundError(f"profiles.ini not found: {ini_path}")

    parser = configparser.ConfigParser()
    parser.read(ini_path)

    profile_rel: str | None = None

    # 2. Prefer the Install section — it points at the profile in active use.
    for section in parser.sections():
        if section.startswith("Install") and parser.has_option(section, "Default"):
            profile_rel = parser.get(section, "Default")
            break

    # 3. Legacy fallback: [Profile*] with Default=1.
    if profile_rel is None:
        for section in parser.sections():
            if not section.startswith("Profile"):
                continue
            if parser.get(section, "Default", fallback="0") == "1":
                profile_rel = parser.get(section, "Path", fallback=None)
                break

    if profile_rel is None:
        raise FileNotFoundError(f"Could not determine active profile from {ini_path}")

    profile_path = Path(profile_rel)
    if not profile_path.is_absolute():
        profile_path = root / profile_path

    db = profile_path / "formhistory.sqlite"
    if not db.exists():
        raise FileNotFoundError(f"formhistory.sqlite not found: {db}")
    return db


def is_firefox_running() -> bool:
    """Return True if a Firefox process is running (exact process-name match)."""
    try:
        result = subprocess.run(
            ["pgrep", "-x", "firefox"],
            capture_output=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        # If we cannot tell, err on the safe side and assume it is running.
        return True
    return result.returncode == 0


def _copy_db(db_path: Path, dest_dir: Path) -> Path:
    """Copy the DB (plus any -wal/-shm sidecars) into ``dest_dir``."""
    dest = dest_dir / db_path.name
    shutil.copy2(db_path, dest)
    for suffix in ("-wal", "-shm"):
        sidecar = db_path.with_name(db_path.name + suffix)
        if sidecar.exists():
            shutil.copy2(sidecar, dest_dir / sidecar.name)
    return dest


_SELECT_ENTRIES = """
    SELECT
        f.id,
        f.fieldname,
        f.value,
        f.timesUsed,
        f.firstUsed,
        f.lastUsed,
        f.guid,
        group_concat(s.source, '|') AS sources
    FROM moz_formhistory f
    LEFT JOIN moz_history_to_sources hs ON hs.history_id = f.id
    LEFT JOIN moz_sources s ON s.id = hs.source_id
    GROUP BY f.id
    ORDER BY f.lastUsed DESC
"""


def read_entries(settings: Settings) -> list[FormEntry]:
    """Return all form-history entries via a read-only temp copy of the DB."""
    db_path = resolve_profile(settings)
    with tempfile.TemporaryDirectory(prefix="lethe-") as tmp:
        copy = _copy_db(db_path, Path(tmp))
        uri = f"file:{copy}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
        try:
            rows = conn.execute(_SELECT_ENTRIES).fetchall()
        finally:
            conn.close()

    entries: list[FormEntry] = []
    for row in rows:
        (id_, fieldname, value, times_used, first_used, last_used, guid, sources) = row
        entries.append(
            FormEntry(
                id=id_,
                fieldname=fieldname,
                value=value,
                times_used=times_used,
                first_used=_us_to_datetime(first_used),
                last_used=_us_to_datetime(last_used),
                guid=guid,
                sources=sources.split("|") if sources else [],
            )
        )
    return entries


def backup(settings: Settings) -> Path:
    """Copy the live DB to a timestamped file in the backup dir. Returns the path."""
    db_path = resolve_profile(settings)
    backup_dir = settings.backup_dir.expanduser()
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = backup_dir / f"formhistory_{stamp}.sqlite"
    shutil.copy2(db_path, dest)
    return dest


def delete(settings: Settings, ids: list[int], dry_run: bool = True) -> dict:
    """Delete form-history rows by id.

    Dry-run (default) returns a preview of the rows that would be removed. The
    apply path refuses while Firefox is running, backs up the DB, inserts Sync
    tombstones, then deletes the rows.

    Returns a dict with ``dry_run``, ``entries`` (preview) and, when applied,
    ``deleted`` (row count) and ``backup`` (path).
    """
    id_set = set(ids)
    preview = [e for e in read_entries(settings) if e.id in id_set]

    if dry_run:
        return {"dry_run": True, "entries": preview, "count": len(preview)}

    if is_firefox_running():
        raise FirefoxRunningError("Refusing to write while Firefox is running. Close Firefox and retry.")

    if not preview:
        return {"dry_run": False, "deleted": 0, "entries": [], "count": 0, "backup": None}

    backup_path = backup(settings)
    db_path = resolve_profile(settings)
    now_us = _now_us()

    conn = sqlite3.connect(db_path)
    try:
        conn.execute("PRAGMA foreign_keys=ON")
        # Insert Sync tombstones so removed rows are not resurrected by Sync.
        conn.executemany(
            "INSERT INTO moz_deleted_formhistory (guid, timeDeleted) VALUES (?, ?)",
            [(e.guid, now_us) for e in preview if e.guid],
        )
        placeholders = ",".join("?" for _ in preview)
        cursor = conn.execute(
            f"DELETE FROM moz_formhistory WHERE id IN ({placeholders})",
            [e.id for e in preview],
        )
        deleted = cursor.rowcount
        conn.commit()
    finally:
        conn.close()

    return {
        "dry_run": False,
        "deleted": deleted,
        "entries": preview,
        "count": len(preview),
        "backup": str(backup_path),
    }


def purge_pattern(
    settings: Settings,
    field_regex: str | None = None,
    value_regex: str | None = None,
    preset: str | None = None,
    dry_run: bool = True,
) -> dict:
    """Delete entries matching regex filters or a named preset.

    Presets:
        ``numeric`` — numeric-only values (2FA codes), ``^\\d{4,8}$``.

    ``field_regex`` and ``value_regex`` are matched (``re.search``) against the
    fieldname and value respectively. A missing filter matches everything.
    """
    if preset == "numeric":
        value_regex = NUMERIC_2FA_PATTERN
    elif preset is not None:
        raise ValueError(f"Unknown preset: {preset}")

    if not field_regex and not value_regex:
        raise ValueError("purge_pattern requires at least one of field_regex, value_regex, or preset")

    matched = match_entries(read_entries(settings), field_regex, value_regex)
    return delete(settings, [e.id for e in matched], dry_run=dry_run)


def match_entries(
    entries: list[FormEntry],
    field_regex: str | None,
    value_regex: str | None,
) -> list[FormEntry]:
    """Return entries matching every provided regex (AND); unset patterns are ignored."""
    field_re = re.compile(field_regex) if field_regex else None
    value_re = re.compile(value_regex) if value_regex else None
    out: list[FormEntry] = []
    for e in entries:
        if field_re is not None and not field_re.search(e.fieldname):
            continue
        if value_re is not None and not value_re.search(e.value):
            continue
        out.append(e)
    return out


def _normalize_text(value: str) -> str:
    """Normalize a value for allowlist comparison (trim + casefold)."""
    return value.strip().casefold()


def _normalize_phone(value: str) -> str:
    """Normalize a phone value to its US-canonical digits.

    Strips all non-digits and drops a leading ``1`` country code from 11-digit
    numbers, so ``+1 929 395 3469``, ``(929) 395-3469`` and ``9293953469`` all
    canonicalize to ``9293953469``. Values with no digits normalize to ``""``.
    """
    digits = re.sub(r"\D", "", value)
    if len(digits) == 11 and digits.startswith("1"):
        digits = digits[1:]
    return digits


def _normalizer(category: Category):
    """Return the value-canonicalization function for a category."""
    return _normalize_phone if category.normalize == "phone" else _normalize_text


def load_allowlist(settings: Settings, category: Category) -> set[str]:
    """Load a category's allowlist as a set of normalized values.

    Values are canonicalized with the category's normalizer. Blank lines and
    ``#`` comments are ignored. Returns an empty set when no allowlist is
    configured or the file is missing.
    """
    if not category.allowlist:
        return set()
    path = settings.allowlist_dir.expanduser() / category.allowlist
    if not path.exists():
        return set()
    normalize = _normalizer(category)
    values: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        canonical = normalize(stripped)
        if canonical:
            values.add(canonical)
    return values


class CategoryReport(BaseModel):
    """Summary of a category and what an allowlist-purge would remove."""

    name: str
    total: int
    allowlist_size: int
    keep: int
    purge_count: int
    purge_entries: list[FormEntry]


def report_category(
    settings: Settings,
    name: str,
    entries: list[FormEntry] | None = None,
) -> CategoryReport:
    """Build a report for a category: matched entries split by the allowlist.

    ``entries`` may be passed to avoid re-copying the DB when reporting on many
    categories at once.
    """
    category = settings.category(name)
    if category is None:
        raise ValueError(f"Unknown category: {name}")
    if entries is None:
        entries = read_entries(settings)

    matched = match_entries(entries, category.field_regex, category.value_regex)
    allow = load_allowlist(settings, category)
    normalize = _normalizer(category)
    purge = [e for e in matched if normalize(e.value) not in allow]
    return CategoryReport(
        name=name,
        total=len(matched),
        allowlist_size=len(allow),
        keep=len(matched) - len(purge),
        purge_count=len(purge),
        purge_entries=purge,
    )


def report_all_categories(settings: Settings) -> list[CategoryReport]:
    """Report every configured category from a single DB read."""
    entries = read_entries(settings)
    return [report_category(settings, c.name, entries=entries) for c in settings.categories]


def purge_category(settings: Settings, name: str, dry_run: bool = True) -> dict:
    """Delete every entry in a category whose value is not in its allowlist.

    Refuses (ValueError) when the allowlist is empty or missing — deleting an
    entire category by accident is exactly the footgun the allowlist prevents.
    Use ``purge_pattern`` for an intentional whole-category wipe.
    """
    category = settings.category(name)
    if category is None:
        raise ValueError(f"Unknown category: {name}")
    if not category.allowlist:
        raise ValueError(f"Category '{name}' has no allowlist configured; refusing allowlist-purge.")
    allow = load_allowlist(settings, category)
    if not allow:
        raise ValueError(
            f"Allowlist for '{name}' is empty or missing ({settings.allowlist_dir / category.allowlist}); "
            "refusing to purge the entire category."
        )

    matched = match_entries(read_entries(settings), category.field_regex, category.value_regex)
    normalize = _normalizer(category)
    ids = [e.id for e in matched if normalize(e.value) not in allow]
    result = delete(settings, ids, dry_run=dry_run)
    result["category"] = name
    return result


def fieldname_summary(entries: list[FormEntry]) -> list[tuple[str, int]]:
    """Return (fieldname, count) pairs, most frequent first."""
    return Counter(e.fieldname for e in entries).most_common()


def export(settings: Settings, fmt: str = "csv") -> str:
    """Serialize all entries as CSV or JSON and return the text."""
    entries = read_entries(settings)
    if fmt == "json":
        return json.dumps([e.model_dump(mode="json") for e in entries], indent=2)
    if fmt == "csv":
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["id", "fieldname", "value", "times_used", "first_used", "last_used", "guid", "sources"])
        for e in entries:
            writer.writerow(
                [
                    e.id,
                    e.fieldname,
                    e.value,
                    e.times_used,
                    e.first_used.isoformat() if e.first_used else "",
                    e.last_used.isoformat() if e.last_used else "",
                    e.guid or "",
                    ";".join(e.sources),
                ]
            )
        return buf.getvalue()
    raise ValueError(f"Unknown export format: {fmt}")
