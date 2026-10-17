"""Tests for lethe.firefox against a throwaway fixture DB with the real schema."""

import sqlite3
from datetime import datetime, timezone

import pytest

from lethe import firefox
from lethe.settings import Settings

# Real schema (verified against a live formhistory.sqlite).
SCHEMA = """
CREATE TABLE moz_formhistory (
    id INTEGER PRIMARY KEY, fieldname TEXT NOT NULL, value TEXT NOT NULL,
    timesUsed INTEGER, firstUsed INTEGER, lastUsed INTEGER, guid TEXT
);
CREATE TABLE moz_deleted_formhistory (
    id INTEGER PRIMARY KEY, timeDeleted INTEGER, guid TEXT
);
CREATE TABLE moz_sources (id INTEGER PRIMARY KEY, source TEXT NOT NULL);
CREATE TABLE moz_history_to_sources (
    history_id INTEGER, source_id INTEGER,
    PRIMARY KEY (history_id, source_id),
    FOREIGN KEY (history_id) REFERENCES moz_formhistory(id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES moz_sources(id) ON DELETE CASCADE
) WITHOUT ROWID;
"""

US = 1_000_000
BASE = int(datetime(2026, 1, 1, tzinfo=timezone.utc).timestamp()) * US

# (id, fieldname, value, timesUsed, guid)
ROWS = [
    (1, "email", "chief@alexandria.org", 10, "guid-email"),
    (2, "email", "friend-oneoff@example.com", 1, "guid-friend"),
    (3, "otpCode", "123456", 1, "guid-otp1"),
    (4, "dom-otp-code-input", "9042", 1, "guid-otp2"),
    (5, "username", "librarian", 5, None),  # NULL guid -> no tombstone
    (6, "searchbar-history", "scrolls of thoth", 3, "guid-search"),
]


@pytest.fixture
def db_path(tmp_path):
    """Build a fixture formhistory.sqlite and return its path."""
    path = tmp_path / "formhistory.sqlite"
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    for id_, fieldname, value, times, guid in ROWS:
        conn.execute(
            "INSERT INTO moz_formhistory (id, fieldname, value, timesUsed, firstUsed, lastUsed, guid) "
            "VALUES (?,?,?,?,?,?,?)",
            (id_, fieldname, value, times, BASE, BASE + id_ * US, guid),
        )
    # Attach one source to row 1 to exercise the LEFT JOIN.
    conn.execute("INSERT INTO moz_sources (id, source) VALUES (1, 'Google')")
    conn.execute("INSERT INTO moz_history_to_sources (history_id, source_id) VALUES (1, 1)")
    conn.commit()
    conn.close()
    return path


EMAIL_REGEX = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"


@pytest.fixture
def settings(db_path, tmp_path):
    from lethe.settings import Category

    return Settings(
        db_path=db_path,
        backup_dir=tmp_path / "backups",
        allowlist_dir=tmp_path / "allow",
        categories=[
            Category(name="email", value_regex=EMAIL_REGEX, allowlist="emails.txt"),
            Category(name="username", field_regex="^username$", allowlist="usernames.txt"),
        ],
    )


def _write_allowlist(settings, filename, lines):
    d = settings.allowlist_dir
    d.mkdir(parents=True, exist_ok=True)
    (d / filename).write_text("\n".join(lines), encoding="utf-8")


@pytest.fixture(autouse=True)
def firefox_closed(monkeypatch):
    """Default: pretend Firefox is closed so writes are allowed."""
    monkeypatch.setattr(firefox, "is_firefox_running", lambda: False)


def test_read_entries(settings):
    entries = firefox.read_entries(settings)
    assert len(entries) == len(ROWS)
    by_id = {e.id: e for e in entries}
    assert by_id[1].value == "chief@alexandria.org"
    assert by_id[1].sources == ["Google"]
    assert by_id[5].sources == []
    assert by_id[5].guid is None
    # microsecond timestamps decoded to aware datetimes
    assert by_id[1].last_used == datetime(2026, 1, 1, 0, 0, 1, tzinfo=timezone.utc)


def test_read_entries_null_timestamps(settings, db_path):
    conn = sqlite3.connect(db_path)
    conn.execute(
        "INSERT INTO moz_formhistory (id, fieldname, value, timesUsed, firstUsed, lastUsed, guid) "
        "VALUES (99, 'x', 'y', NULL, NULL, NULL, 'g99')"
    )
    conn.commit()
    conn.close()
    entries = {e.id: e for e in firefox.read_entries(settings)}
    assert entries[99].last_used is None
    assert entries[99].times_used is None


def test_delete_dry_run_does_not_delete(settings):
    result = firefox.delete(settings, [3, 4], dry_run=True)
    assert result["dry_run"] is True
    assert result["count"] == 2
    assert {e.id for e in result["entries"]} == {3, 4}
    # DB untouched
    assert len(firefox.read_entries(settings)) == len(ROWS)


def test_delete_apply_removes_rows_and_writes_tombstones(settings, db_path):
    result = firefox.delete(settings, [3, 4, 5], dry_run=False)
    assert result["dry_run"] is False
    assert result["deleted"] == 3
    assert result["backup"] is not None

    remaining = {e.id for e in firefox.read_entries(settings)}
    assert remaining == {1, 2, 6}

    conn = sqlite3.connect(db_path)
    tombstones = {r[0] for r in conn.execute("SELECT guid FROM moz_deleted_formhistory")}
    td = conn.execute("SELECT timeDeleted FROM moz_deleted_formhistory LIMIT 1").fetchone()[0]
    conn.close()
    # Rows 3 and 4 have guids; row 5 (NULL guid) gets no tombstone.
    assert tombstones == {"guid-otp1", "guid-otp2"}
    # timeDeleted stored in microseconds (16 digits).
    assert len(str(td)) == 16


def test_delete_apply_refused_when_firefox_running(settings, monkeypatch):
    monkeypatch.setattr(firefox, "is_firefox_running", lambda: True)
    with pytest.raises(firefox.FirefoxRunningError):
        firefox.delete(settings, [3], dry_run=False)
    # Nothing deleted.
    assert len(firefox.read_entries(settings)) == len(ROWS)


def test_purge_numeric_preset(settings):
    preview = firefox.purge_pattern(settings, preset="numeric", dry_run=True)
    assert {e.id for e in preview["entries"]} == {3, 4}  # 123456, 9042
    applied = firefox.purge_pattern(settings, preset="numeric", dry_run=False)
    assert applied["deleted"] == 2
    assert {e.id for e in firefox.read_entries(settings)} == {1, 2, 5, 6}


def test_purge_by_fieldname_regex(settings):
    preview = firefox.purge_pattern(settings, field_regex="^email$", dry_run=True)
    assert {e.id for e in preview["entries"]} == {1, 2}


def test_purge_requires_a_filter(settings):
    with pytest.raises(ValueError):
        firefox.purge_pattern(settings, dry_run=True)


def test_export_csv_and_json(settings):
    csv_out = firefox.export(settings, "csv")
    assert "chief@alexandria.org" in csv_out
    assert csv_out.splitlines()[0].startswith("id,fieldname,value")

    import json

    data = json.loads(firefox.export(settings, "json"))
    assert len(data) == len(ROWS)
    assert any(row["value"] == "123456" for row in data)


def test_report_category_splits_by_allowlist(settings):
    # Keep the chief's real email; the one-off friend email is a purge candidate.
    _write_allowlist(settings, "emails.txt", ["Chief@Alexandria.org"])  # case-insensitive match
    rep = firefox.report_category(settings, "email")
    assert rep.total == 2  # rows 1 and 2 are emails
    assert rep.allowlist_size == 1
    assert rep.keep == 1
    assert rep.purge_count == 1
    assert {e.id for e in rep.purge_entries} == {2}


def test_purge_category_deletes_non_allowlisted(settings):
    _write_allowlist(settings, "emails.txt", ["chief@alexandria.org"])
    result = firefox.purge_category(settings, "email", dry_run=False)
    assert result["deleted"] == 1
    assert result["category"] == "email"
    remaining = {e.id for e in firefox.read_entries(settings)}
    assert 2 not in remaining and 1 in remaining


def test_purge_category_refuses_empty_allowlist(settings):
    _write_allowlist(settings, "emails.txt", ["# nothing here"])
    with pytest.raises(ValueError, match="empty or missing"):
        firefox.purge_category(settings, "email", dry_run=True)
    # DB untouched.
    assert len(firefox.read_entries(settings)) == len(ROWS)


def test_purge_category_refuses_missing_allowlist_file(settings):
    with pytest.raises(ValueError, match="empty or missing"):
        firefox.purge_category(settings, "email", dry_run=False)


def test_report_category_by_fieldname(settings):
    _write_allowlist(settings, "usernames.txt", ["librarian"])
    rep = firefox.report_category(settings, "username")
    assert rep.total == 1  # row 5 fieldname == username
    assert rep.purge_count == 0  # librarian is allowlisted


def test_unknown_category_raises(settings):
    with pytest.raises(ValueError, match="Unknown category"):
        firefox.report_category(settings, "nope")


def test_fieldname_summary(settings):
    summary = firefox.fieldname_summary(firefox.read_entries(settings))
    counts = dict(summary)
    assert counts["email"] == 2  # rows 1 and 2
    assert counts["otpCode"] == 1
    # sorted most-frequent first
    assert summary[0][1] >= summary[-1][1]


def test_normalize_phone_variants():
    for v in ["+1 929 395 3469", "9293953469", "(929) 395-3469", "929-395-3469", "1-929-395-3469"]:
        assert firefox._normalize_phone(v) == "9293953469"
    assert firefox._normalize_phone("no digits here") == ""


def test_phone_allowlist_matches_across_formats(tmp_path):
    from lethe.settings import Category

    path = tmp_path / "formhistory.sqlite"
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    phones = [
        (1, "tel", "+1 929 395 3469", "g1"),  # keep — allowlisted, different format
        (2, "phone", "9293953469", "g2"),  # keep — same number, bare
        (3, "mobile", "212-555-0100", "g3"),  # purge — not allowlisted
    ]
    for id_, f, v, g in phones:
        conn.execute(
            "INSERT INTO moz_formhistory (id,fieldname,value,timesUsed,firstUsed,lastUsed,guid) VALUES (?,?,?,1,?,?,?)",
            (id_, f, v, BASE, BASE, g),
        )
    conn.commit()
    conn.close()

    allow_dir = tmp_path / "allow"
    allow_dir.mkdir()
    (allow_dir / "phones.txt").write_text("9293953469\n")  # one entry, bare format

    s = Settings(
        db_path=path,
        backup_dir=tmp_path / "b",
        allowlist_dir=allow_dir,
        categories=[
            Category(
                name="phone",
                value_regex=r"^\+?[\d\s().-]{7,}$",
                field_regex="(?i)(phone|tel|mobile|cell)",
                allowlist="phones.txt",
                normalize="phone",
            )
        ],
    )
    rep = firefox.report_category(s, "phone")
    assert rep.total == 3
    assert rep.allowlist_size == 1
    assert rep.keep == 2  # both formats of the allowlisted number survive
    assert {e.id for e in rep.purge_entries} == {3}


def test_resolve_profile_prefers_install_section(tmp_path):
    root = tmp_path / "Firefox"
    profile = root / "Profiles" / "abc.default-release"
    legacy = root / "Profiles" / "old.default"
    profile.mkdir(parents=True)
    legacy.mkdir(parents=True)
    (profile / "formhistory.sqlite").write_text("")
    (legacy / "formhistory.sqlite").write_text("")
    (root / "profiles.ini").write_text(
        "[Profile1]\nName=default\nIsRelative=1\nPath=Profiles/old.default\nDefault=1\n\n"
        "[Profile0]\nName=default-release\nIsRelative=1\nPath=Profiles/abc.default-release\n\n"
        "[Install123]\nDefault=Profiles/abc.default-release\nLocked=1\n"
    )
    resolved = firefox.resolve_profile(Settings(firefox_root=root, db_path=None))
    assert resolved == profile / "formhistory.sqlite"
