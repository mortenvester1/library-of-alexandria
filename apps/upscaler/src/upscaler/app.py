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


def _upscale_one(
    source: Image.Image, loaded, scale: int, settings: Settings, alpha_scale, tile, tile_overlap, bleed_passes
) -> tuple[bytes, int, int]:
    """One image in, `(PNG bytes, width, height)` out.

    The body shared by `/upscale` and `/upscale_batch`, so the two cannot
    drift. The caller holds `_gpu_lock`; the batch endpoint holds it once for
    the whole batch, which is the point of it existing.
    """
    pixels = source.width * source.height
    if pixels > settings.max_pixels:
        raise HTTPException(status_code=413, detail=f"{pixels} pixels exceeds max_pixels={settings.max_pixels}")

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
    return buffer.getvalue(), result.width, result.height


@app.post("/upscale_batch")
def upscale_batch(
    images: Annotated[list[UploadFile], File()],
    model: Annotated[str, Form()],
    scale: Annotated[int, Form(ge=1, le=8)] = 2,
    alpha_scale: Annotated[Literal["box", "model"] | None, Form()] = None,
    tile: Annotated[int | None, Form(ge=0)] = None,
    tile_overlap: Annotated[int | None, Form(ge=0)] = None,
    bleed_passes: Annotated[int | None, Form(ge=0)] = None,
) -> Response:
    """Upscale many images in one request, in order.

    Same result as calling `/upscale` once per image -- this exists purely to
    amortise the per-request cost, which measurement showed dominates for the
    small frames an `.ART` asset is made of: a 78x40 frame costs ~24 ms of
    which only ~3 ms is its own inference, the rest being HTTP, multipart
    parsing and lock acquisition. An asset can hold 80 frames.

    Concurrency does **not** substitute for this: `_gpu_lock` serialises every
    caller by design, and measured throughput is flat past two workers.

    The reply is a length-framed stream rather than multipart or a zip, because
    both ends are ours and PNG is already compressed: `<uint32 count>` then
    `<uint32 length><png bytes>` per image, big-endian. Order matches the
    request.
    """
    settings: Settings = app.state.settings
    registry: ModelRegistry = app.state.registry

    if not images:
        raise HTTPException(status_code=400, detail="no images")
    if len(images) > settings_batch_limit(settings):
        raise HTTPException(
            status_code=413,
            detail=f"{len(images)} images exceeds the batch limit of {settings_batch_limit(settings)}",
        )

    sources = []
    for index, upload in enumerate(images):
        try:
            source = Image.open(io.BytesIO(upload.file.read()))
            source.load()
        except (UnidentifiedImageError, OSError) as exc:
            raise HTTPException(status_code=400, detail=f"image {index}: unreadable: {exc}") from exc
        sources.append(source)

    try:
        loaded = registry.load(model)
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    # One lock acquisition for the whole batch, which is the point.
    payloads = []
    with _gpu_lock:
        for source in sources:
            payload, _, _ = _upscale_one(source, loaded, scale, settings, alpha_scale, tile, tile_overlap, bleed_passes)
            payloads.append(payload)

    out = io.BytesIO()
    out.write(len(payloads).to_bytes(4, "big"))
    for payload in payloads:
        out.write(len(payload).to_bytes(4, "big"))
        out.write(payload)
    return Response(
        content=out.getvalue(),
        media_type="application/octet-stream",
        headers={
            "X-Upscaler-Model": loaded.name,
            "X-Upscaler-Native-Scale": str(loaded.native_scale),
            "X-Upscaler-Count": str(len(payloads)),
        },
    )


def settings_batch_limit(settings: Settings) -> int:
    """A bound so one request cannot pin the GPU indefinitely. Assets top out
    around 80 frames; 256 leaves headroom without being unbounded."""
    return getattr(settings, "max_batch", 256)


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

    try:
        loaded = registry.load(model)
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    # Shared with `/upscale_batch` so the two cannot drift.
    with _gpu_lock:
        payload, out_w, out_h = _upscale_one(
            source, loaded, scale, settings, alpha_scale, tile, tile_overlap, bleed_passes
        )

    return Response(
        content=payload,
        media_type="image/png",
        headers={
            "X-Upscaler-Model": loaded.name,
            "X-Upscaler-Native-Scale": str(loaded.native_scale),
            "X-Upscaler-Output-Size": f"{out_w}x{out_h}",
        },
    )
