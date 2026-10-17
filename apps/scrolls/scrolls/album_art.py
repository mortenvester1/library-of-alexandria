#!/usr/bin/env python3
"""
add_missing_album_art.py

Walk a music library, find audio files without embedded album art,
fetch covers via `sacad`, and embed them using `mutagen`.

Supports MP3, M4A, M4P, and FLAC. DRM-protected M4P files are detected
and skipped (they can't be modified without breaking playback).

Requirements (install once):
    pip3 install mutagen
    cargo install sacad        # or grab a release binary from sacad's GitHub

Usage:
    python3 add_missing_album_art.py ~/Music/MyLibrary
    python3 add_missing_album_art.py ~/Music --dry-run
    python3 add_missing_album_art.py ~/Music --formats mp3,m4a
    python3 add_missing_album_art.py ~/Music --keep-cover-files --size 1000
"""

import argparse
import os
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

from mutagen import File as MutagenFile
from mutagen.flac import FLAC, Picture
from mutagen.id3 import APIC, ID3, ID3NoHeaderError
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4, MP4Cover

DEFAULT_FORMATS = ["mp3", "m4a", "m4p", "flac"]


# ---------- format detection ----------


def get_image_mime(path: Path) -> str:
    """Detect image MIME type from the first few bytes."""
    with open(path, "rb") as f:
        header = f.read(8)
    if header.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if header.startswith(b"\x89PNG"):
        return "image/png"
    return "image/jpeg"  # default assumption


def is_drm_protected(path: Path, audio) -> bool:
    """Detect DRM on M4P / iTunes-protected files."""
    if path.suffix.lower() == ".m4p":
        return True  # extension alone is a strong signal
    try:
        codec = (audio.info.codec or "").lower()
        if "drm" in codec or codec == "drms":
            return True
    except AttributeError:
        pass
    try:
        desc = (audio.info.codec_description or "").lower()
        if "protected" in desc:
            return True
    except AttributeError:
        pass
    return False


# ---------- art presence + tag lookup ----------


def has_art(path: Path) -> bool:
    """Return True if the file already has embedded album art."""
    suffix = path.suffix.lower()
    try:
        if suffix == ".mp3":
            try:
                tags = ID3(path)
            except ID3NoHeaderError:
                return False
            return any(k.startswith("APIC") for k in tags.keys())
        if suffix in (".m4a", ".m4p", ".mp4"):
            audio = MP4(path)
            return bool(audio.tags and audio.tags.get("covr"))
        if suffix == ".flac":
            return len(FLAC(path).pictures) > 0
    except Exception as e:
        print(f"  [warn] could not read art status of {path.name}: {e}")
        return False
    return False


def get_artist_album(path: Path):
    """Return (artist, album) via mutagen's unified easy interface."""
    try:
        audio = MutagenFile(path, easy=True)
        if audio is None:
            return None, None
        artist = audio.get("artist", [None])[0] or audio.get("albumartist", [None])[0]
        album = audio.get("album", [None])[0]
        return artist, album
    except Exception:
        return None, None


# ---------- sacad ----------


def fetch_cover(artist: str, album: str, size: int, out_path: Path) -> bool:
    """Run sacad to download a cover. Returns True on success."""
    if out_path.exists():
        out_path.unlink()
    try:
        subprocess.run(
            ["sacad", artist, album, str(size), str(out_path)],
            capture_output=True,
            text=True,
            timeout=180,
        )
    except FileNotFoundError:
        sys.exit("error: `sacad` not found in PATH. Install it first.")
    except subprocess.TimeoutExpired:
        print("  [warn] sacad timed out")
        return False
    return out_path.exists() and out_path.stat().st_size > 0


# ---------- embedding (per format) ----------


def embed_mp3(path: Path, cover_path: Path, mime: str) -> bool:
    audio = MP3(path, ID3=ID3)
    if audio.tags is None:
        audio.add_tags()
    audio.tags.delall("APIC")  # drop any stale art frames
    with open(cover_path, "rb") as f:
        data = f.read()
    audio.tags.add(APIC(encoding=3, mime=mime, type=3, desc="Cover", data=data))
    audio.save(v2_version=3)  # v2.3 is the most compatible
    return True


def embed_mp4(path: Path, cover_path: Path, mime: str) -> bool:
    audio = MP4(path)
    if audio.tags is None:
        audio.add_tags()
    with open(cover_path, "rb") as f:
        data = f.read()
    fmt = MP4Cover.FORMAT_JPEG if mime == "image/jpeg" else MP4Cover.FORMAT_PNG
    audio["covr"] = [MP4Cover(data, imageformat=fmt)]
    audio.save()
    return True


def embed_flac(path: Path, cover_path: Path, mime: str) -> bool:
    audio = FLAC(path)
    pic = Picture()
    pic.type = 3  # front cover
    pic.mime = mime
    pic.desc = "Cover"
    with open(cover_path, "rb") as f:
        pic.data = f.read()
    audio.clear_pictures()
    audio.add_picture(pic)
    audio.save()
    return True


def embed_cover(
    path: Path, cover_path: Path, mime: str, preserve_mtime: bool = True
) -> bool:
    """Embed cover into an audio file, dispatching by extension."""
    suffix = path.suffix.lower()
    stat = path.stat() if preserve_mtime else None
    try:
        if suffix == ".mp3":
            ok = embed_mp3(path, cover_path, mime)
        elif suffix in (".m4a", ".mp4"):
            ok = embed_mp4(path, cover_path, mime)
        elif suffix == ".m4p":
            print(f"    [skip] {path.name} is DRM-protected (M4P)")
            return False
        elif suffix == ".flac":
            ok = embed_flac(path, cover_path, mime)
        else:
            print(f"    [skip] unsupported format: {suffix}")
            return False
    except Exception as e:
        print(f"    [warn] embed failed for {path.name}: {e}")
        return False

    if ok and stat is not None:
        try:
            os.utime(path, (stat.st_atime, stat.st_mtime))
        except OSError:
            pass
    return ok


# ---------- main ----------


def main():
    parser = argparse.ArgumentParser(
        description="Add missing album art to audio files using sacad + mutagen."
    )
    parser.add_argument("roots", nargs="+", help="Paths to music library roots")
    parser.add_argument(
        "--size",
        type=int,
        default=1000,
        help="Target cover resolution in px (default: 1000)",
    )
    parser.add_argument(
        "--formats",
        default=",".join(DEFAULT_FORMATS),
        help=f"Comma-separated extensions to scan (default: {','.join(DEFAULT_FORMATS)})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be done; do not fetch or embed",
    )
    parser.add_argument(
        "--keep-cover-files",
        action="store_true",
        help="Also save cover.jpg in each album folder",
    )
    parser.add_argument(
        "--overwrite-cover-files",
        action="store_true",
        help="With --keep-cover-files, overwrite an existing cover.jpg",
    )
    parser.add_argument(
        "--no-preserve-mtime",
        action="store_true",
        help="Do not restore mtime after editing files",
    )
    parser.add_argument(
        "--list-missing",
        action="store_true",
        help="Print artist - album pairs missing art and exit; no fetching or embedding",
    )
    args = parser.parse_args()

    roots = []
    for r in args.roots:
        p = Path(r).expanduser().resolve()
        if not p.is_dir():
            sys.exit(f"Not a directory: {p}")
        roots.append(p)

    extensions = {"." + e.lower().lstrip(".") for e in args.formats.split(",") if e}
    if not args.list_missing:
        print(f"Scanning extensions: {sorted(extensions)}")

    # Group audio files by their containing folder (one album = one folder).
    folders: dict[Path, list[Path]] = defaultdict(list)
    folder_root: dict[Path, Path] = {}
    skipped_extensions: dict[str, int] = defaultdict(int)
    for root in roots:
        for path in root.rglob("*"):
            if path.is_file():
                if path.suffix.lower() in extensions:
                    folders[path.parent].append(path)
                    folder_root[path.parent] = root
                else:
                    skipped_extensions[path.suffix.lower() or "(no extension)"] += 1

    total = sum(len(v) for v in folders.values())
    if not args.list_missing:
        print(f"Found {total} audio files in {len(folders)} folders\n")

    summary = {
        "checked": 0,
        "already_have_art": 0,
        "drm_skipped": 0,
        "fetched": 0,
        "embedded": 0,
        "no_tags": 0,
        "no_art_found": 0,
    }

    for folder in sorted(folders.keys()):
        files = folders[folder]
        summary["checked"] += len(files)

        missing = []
        for f in files:
            # Pre-check DRM on MP4 family so we can report and skip cleanly.
            if f.suffix.lower() in (".m4a", ".m4p", ".mp4"):
                try:
                    if is_drm_protected(f, MP4(f)):
                        summary["drm_skipped"] += 1
                        continue
                except Exception:
                    pass
            if not has_art(f):
                missing.append(f)
            else:
                summary["already_have_art"] += 1

        if not missing:
            continue

        froot = folder_root[folder]
        rel = folder.relative_to(froot) if folder != froot else folder.name

        # Pull artist/album from the first tagged file in the folder.
        artist, album = None, None
        for f in missing:
            artist, album = get_artist_album(f)
            if artist and album:
                break

        if not artist or not album:
            if not args.list_missing:
                print(f"[{rel}] {len(missing)} file(s) missing art")
                print("  [skip] could not read artist/album tags from any file")
            summary["no_tags"] += len(missing)
            continue

        if args.list_missing:
            print(f"{artist} - {album}")
            continue

        print(f"[{rel}] {len(missing)} file(s) missing art")
        print(f"  -> searching: {artist} - {album}")

        if args.dry_run:
            print("  [dry-run] would fetch and embed")
            continue

        # Where to save the cover.
        cleanup_after = False
        if args.keep_cover_files:
            cover_path = folder / "cover.jpg"
            if cover_path.exists() and not args.overwrite_cover_files:
                print(f"  [info] {cover_path.name} already exists, reusing it")
                fetched = True
            else:
                fetched = fetch_cover(artist, album, args.size, cover_path)
        else:
            tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
            cover_path = Path(tmp.name)
            tmp.close()
            cleanup_after = True
            fetched = fetch_cover(artist, album, args.size, cover_path)

        try:
            if not fetched:
                print("  x no cover found")
                summary["no_art_found"] += 1
                continue

            summary["fetched"] += 1
            kb = cover_path.stat().st_size // 1024
            mime = get_image_mime(cover_path)
            print(f"  + fetched cover ({kb} KB, {mime})")

            embedded_here = 0
            for f in missing:
                if embed_cover(
                    f, cover_path, mime, preserve_mtime=not args.no_preserve_mtime
                ):
                    embedded_here += 1
            summary["embedded"] += embedded_here
            print(f"  + embedded in {embedded_here}/{len(missing)} files")
        finally:
            if cleanup_after and cover_path.exists():
                cover_path.unlink()

    if args.list_missing:
        return

    print("\n--- Summary ---")
    print(f"Files checked:       {summary['checked']}")
    print(f"Already had art:     {summary['already_have_art']}")
    print(f"DRM-protected skip:  {summary['drm_skipped']}")
    print(f"Covers fetched:      {summary['fetched']}")
    print(f"Files embedded:      {summary['embedded']}")
    print(f"Skipped (no tags):   {summary['no_tags']}")
    print(f"No cover found:      {summary['no_art_found']}")
    if skipped_extensions:
        print("\n--- Files not in scanned formats ---")
        for ext, count in sorted(skipped_extensions.items()):
            print(f"  {ext:<20} {count}")


if __name__ == "__main__":
    main()
