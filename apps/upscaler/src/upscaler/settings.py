from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings, overridable via ``UPSCALER_*`` environment variables.

    Attributes:
        models_dir: Directory scanned for ``.pth`` / ``.safetensors`` upscale models.
        device: Torch device. ``auto`` picks the GPU when torch reports one.
        tile: Tile edge length in source pixels; 0 disables tiling.
        tile_overlap: Overlap between adjacent tiles, blended away on reassembly.
        bleed_passes: Iterations of edge-colour extension into the transparent
            region before inference. See ``upscale.bleed_alpha``.
        alpha_scale: Default alpha upscaling path. ``box`` is area interpolation,
            ``model`` runs the mask through the upscale model.
        max_pixels: Rejection threshold on source ``w * h``, a guard against a
            single request pinning the GPU.
        host / port: uvicorn bind address.
        log_level: Logging level.
    """

    model_config = SettingsConfigDict(env_prefix="UPSCALER_", extra="ignore")

    models_dir: Path = Path("/models")
    device: Literal["auto", "cuda", "cpu"] = "auto"

    tile: int = 512
    tile_overlap: int = 32
    bleed_passes: int = 16
    alpha_scale: Literal["box", "model"] = "box"
    max_pixels: int = 64_000_000

    host: str = "0.0.0.0"
    port: int = 8700
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
