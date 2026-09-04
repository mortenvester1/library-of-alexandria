import io
import logging
import threading
from contextlib import asynccontextmanager
from typing import Annotated, Literal

import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError

from upscaler.settings import Settings, get_settings
from upscaler.upscale import ModelRegistry, resolve_device, upscale_rgba

logger = logging.getLogger(__name__)

# One GPU serves every request; serialise so concurrent callers queue rather than OOM.
_gpu_lock = threading.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    device = resolve_device(settings.device)
    app.state.settings = settings
    app.state.device = device
    app.state.registry = ModelRegistry(settings.models_dir, device)
    logger.info("device=%s models_dir=%s", device, settings.models_dir)
    yield


app = FastAPI(title="upscaler", version="0.1.0", lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict[str, object]:
    return {
        "status": "ok",
        "device": str(app.state.device),
        "torch": torch.__version__,
        "hip": torch.version.hip,
        "models": len(app.state.registry.available()),
    }


@app.get("/models")
def models() -> dict[str, object]:
    registry: ModelRegistry = app.state.registry
    entries = []
    for name in registry.available():
        try:
            loaded = registry.describe(name)
        except Exception as exc:  # A single unloadable file must not hide the rest.
            entries.append({"name": name, "error": str(exc)})
            continue
        entries.append(
            {
                "name": name,
                "architecture": loaded.architecture,
                "native_scale": loaded.native_scale,
                "input_channels": loaded.input_channels,
            }
        )
    return {"models_dir": str(registry.models_dir), "models": entries}


@app.post("/upscale")
def upscale(
    image: Annotated[UploadFile, File()],
    model: Annotated[str, Form()],
    scale: Annotated[int, Form(ge=1, le=8)] = 2,
    alpha_scale: Annotated[Literal["box", "model"] | None, Form()] = None,
    tile: Annotated[int | None, Form(ge=0)] = None,
    tile_overlap: Annotated[int | None, Form(ge=0)] = None,
    bleed_passes: Annotated[int | None, Form(ge=0)] = None,
) -> Response:
    """Upscale one image to exactly ``scale`` times its source dimensions.

    Returns lossless 8-bit RGBA PNG. Quantisation is the caller's job.
    """
    settings: Settings = app.state.settings
    registry: ModelRegistry = app.state.registry

    try:
        source = Image.open(io.BytesIO(image.file.read()))
        source.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise HTTPException(status_code=400, detail=f"unreadable image: {exc}") from exc

    pixels = source.width * source.height
    if pixels > settings.max_pixels:
        raise HTTPException(status_code=413, detail=f"{pixels} pixels exceeds max_pixels={settings.max_pixels}")

    try:
        loaded = registry.load(model)
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    with _gpu_lock:
        try:
            result = upscale_rgba(
                source,
                loaded,
                scale,
                app.state.device,
                alpha_scale=alpha_scale or settings.alpha_scale,
                tile=settings.tile if tile is None else tile,
                tile_overlap=settings.tile_overlap if tile_overlap is None else tile_overlap,
                bleed_passes=settings.bleed_passes if bleed_passes is None else bleed_passes,
            )
        except torch.cuda.OutOfMemoryError as exc:
            raise HTTPException(status_code=507, detail=f"out of VRAM, lower tile: {exc}") from exc

    buffer = io.BytesIO()
    result.save(buffer, format="PNG", optimize=False, compress_level=6)
    return Response(
        content=buffer.getvalue(),
        media_type="image/png",
        headers={
            "X-Upscaler-Model": loaded.name,
            "X-Upscaler-Native-Scale": str(loaded.native_scale),
            "X-Upscaler-Output-Size": f"{result.width}x{result.height}",
        },
    )
