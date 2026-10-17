import csv
import io
import json
import logging
import os
import re
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Form, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.templating import Jinja2Templates

import lethe
from lethe import firefox
from lethe.settings import Settings, get_settings

settings = get_settings()
lethe.set_log_level(settings.log_level)
logger = logging.getLogger(__name__)

templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Surface config resolution at startup so a missing config isn't silent."""
    s = get_settings()
    config_path = Path(os.environ.get("LETHE_CONFIG_FILE", "categories.yaml")).resolve()
    logger.info(f"Config: {config_path} (exists={config_path.exists()})")
    if s.categories:
        logger.info(f"Loaded {len(s.categories)} categor(y/ies); allowlists in {s.allowlist_dir.resolve()}")
    else:
        logger.warning(
            f"No categories loaded — allowlist cleanup disabled. Expected config at {config_path}. "
            "Run from the app directory or set LETHE_CONFIG_FILE."
        )
    yield


app = FastAPI(
    title=lethe.__name__,
    version=lethe.__version__,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


def _parse_ids(raw: str | None) -> list[int]:
    """Parse a comma/whitespace-separated id list from a form field."""
    if not raw:
        return []
    ids: list[int] = []
    for token in raw.replace(",", " ").split():
        try:
            ids.append(int(token))
        except ValueError:
            continue
    return ids


@app.get("/")
async def root(request: Request, settings: Annotated[Settings, Depends(get_settings)]):
    """Render the form-history table with client-side filtering and pruning controls."""
    running = firefox.is_firefox_running()
    error = None
    entries = []
    category_reports = []
    fieldnames = []
    try:
        entries = firefox.read_entries(settings)
        category_reports = [firefox.report_category(settings, c.name, entries=entries) for c in settings.categories]
        fieldnames = firefox.fieldname_summary(entries)
    except FileNotFoundError as exc:
        error = str(exc)
        logger.warning(f"Could not read form history: {exc}")

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "entries": entries,
            "firefox_running": running,
            "error": error,
            "count": len(entries),
            "category_reports": category_reports,
            "fieldnames": fieldnames,
        },
    )


@app.post("/delete")
async def delete(
    settings: Annotated[Settings, Depends(get_settings)],
    ids: Annotated[str, Form()] = "",
    dry_run: Annotated[bool, Form()] = True,
):
    """Delete selected ids. Dry-run by default returns a preview."""
    try:
        result = firefox.delete(settings, _parse_ids(ids), dry_run=dry_run)
    except firefox.FirefoxRunningError as exc:
        return JSONResponse(status_code=409, content={"error": str(exc)})
    return _jsonable(result)


@app.post("/purge")
async def purge(
    settings: Annotated[Settings, Depends(get_settings)],
    field_regex: Annotated[str, Form()] = "",
    value_regex: Annotated[str, Form()] = "",
    preset: Annotated[str, Form()] = "",
    dry_run: Annotated[bool, Form()] = True,
):
    """Purge entries by regex/preset. Dry-run by default returns a preview."""
    try:
        result = firefox.purge_pattern(
            settings,
            field_regex=field_regex or None,
            value_regex=value_regex or None,
            preset=preset or None,
            dry_run=dry_run,
        )
    except firefox.FirefoxRunningError as exc:
        return JSONResponse(status_code=409, content={"error": str(exc)})
    except (ValueError, re.error) as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    return _jsonable(result)


@app.post("/purge_category")
async def purge_category(
    settings: Annotated[Settings, Depends(get_settings)],
    name: Annotated[str, Form()],
    dry_run: Annotated[bool, Form()] = True,
):
    """Purge a category's entries not in its allowlist. Dry-run by default."""
    try:
        result = firefox.purge_category(settings, name, dry_run=dry_run)
    except firefox.FirefoxRunningError as exc:
        return JSONResponse(status_code=409, content={"error": str(exc)})
    except (ValueError, re.error) as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    return _jsonable(result)


@app.get("/report/{name}")
async def report(settings: Annotated[Settings, Depends(get_settings)], name: str, fmt: str = "csv"):
    """Download a category's purge candidates (values not in the allowlist)."""
    try:
        rep = firefox.report_category(settings, name)
    except (ValueError, re.error) as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    entries = rep.purge_entries
    if fmt == "json":
        content = json.dumps([e.model_dump(mode="json") for e in entries], indent=2)
        media = "application/json"
    else:
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["id", "fieldname", "value", "times_used", "last_used"])
        for e in entries:
            writer.writerow([e.id, e.fieldname, e.value, e.times_used, e.last_used.isoformat() if e.last_used else ""])
        content = buf.getvalue()
        media = "text/csv"
    return PlainTextResponse(
        content,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{name}_purge_candidates.{fmt}"'},
    )


@app.get("/export")
async def export(settings: Annotated[Settings, Depends(get_settings)], fmt: str = "csv"):
    """Download all entries as CSV or JSON."""
    content = firefox.export(settings, fmt=fmt)
    media = "application/json" if fmt == "json" else "text/csv"
    return PlainTextResponse(
        content,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="formhistory.{fmt}"'},
    )


@app.get("/health")
async def health(settings: Annotated[Settings, Depends(get_settings)]):
    return {"status": "healthy", "firefox_running": firefox.is_firefox_running()}


def _jsonable(result: dict) -> dict:
    """Convert FormEntry models in a result dict to plain JSON-serializable data."""
    out = dict(result)
    if "entries" in out:
        out["entries"] = [e.model_dump(mode="json") for e in out["entries"]]
    return out


def main():
    """Console-script entry point."""
    import uvicorn

    s = get_settings()
    uvicorn.run("lethe.app:app", host=s.host, port=s.port)


if __name__ == "__main__":
    main()
