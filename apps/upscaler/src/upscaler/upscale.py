"""Model registry and the deterministic upscale pipeline.

``torch`` resolves to the ROCm build on Linux and the PyPI CPU build elsewhere;
see the ``pytorch-rocm`` index pinned in ``pyproject.toml``.
"""

import logging
import threading
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from spandrel import ImageModelDescriptor, ModelLoader

logger = logging.getLogger(__name__)

MODEL_SUFFIXES = (".pth", ".safetensors", ".pt", ".ckpt")


@dataclass(frozen=True)
class LoadedModel:
    name: str
    descriptor: ImageModelDescriptor
    architecture: str
    native_scale: int
    input_channels: int


class ModelRegistry:
    """Discovers model files under ``models_dir`` and caches loaded descriptors.

    Upscale models are small (tens of MB), so every model touched stays resident;
    the lock serialises loads because a single GPU serves all requests anyway.
    """

    def __init__(self, models_dir: Path, device: torch.device) -> None:
        self._models_dir = models_dir
        self._device = device
        self._cache: dict[str, LoadedModel] = {}
        self._lock = threading.Lock()

    @property
    def models_dir(self) -> Path:
        return self._models_dir

    def available(self) -> list[str]:
        if not self._models_dir.is_dir():
            return []
        names = (p.name for p in self._models_dir.iterdir() if p.suffix.lower() in MODEL_SUFFIXES)
        return sorted(names)

    def describe(self, name: str) -> LoadedModel:
        """Read a model's architecture and scale without occupying VRAM.

        Listing the directory must not fan out into loading every model onto the
        GPU, so an uncached model is inspected on CPU and discarded.
        """
        if name in self._cache:
            return self._cache[name]

        descriptor = ModelLoader(device=torch.device("cpu")).load_from_file(self.resolve(name))
        if not isinstance(descriptor, ImageModelDescriptor):
            raise ValueError(f"{name!r} is not an image-to-image model")
        return LoadedModel(
            name=name,
            descriptor=descriptor,
            architecture=descriptor.architecture.name,
            native_scale=int(descriptor.scale),
            input_channels=int(descriptor.input_channels),
        )

    def resolve(self, name: str) -> Path:
        # Reject traversal and subdirectories: models are addressed by bare filename.
        if name != Path(name).name:
            raise ValueError(f"invalid model name: {name!r}")
        path = self._models_dir / name
        if not path.is_file():
            raise FileNotFoundError(f"no such model: {name!r}")
        return path

    def load(self, name: str) -> LoadedModel:
        with self._lock:
            if name in self._cache:
                return self._cache[name]

            path = self.resolve(name)
            descriptor = ModelLoader(device=self._device).load_from_file(path)
            if not isinstance(descriptor, ImageModelDescriptor):
                raise ValueError(f"{name!r} is not an image-to-image model")

            descriptor.eval()
            loaded = LoadedModel(
                name=name,
                descriptor=descriptor,
                architecture=descriptor.architecture.name,
                native_scale=int(descriptor.scale),
                input_channels=int(descriptor.input_channels),
            )
            logger.info("loaded %s (%s, %dx)", name, loaded.architecture, loaded.native_scale)
            self._cache[name] = loaded
            return loaded


def resolve_device(preference: str) -> torch.device:
    if preference == "cpu":
        return torch.device("cpu")
    if torch.cuda.is_available():
        return torch.device("cuda")
    if preference == "cuda":
        raise RuntimeError("UPSCALER_DEVICE=cuda but torch reports no GPU")
    logger.warning("no GPU visible to torch, falling back to CPU")
    return torch.device("cpu")


def bleed_alpha(rgb: torch.Tensor, known: torch.Tensor, passes: int) -> torch.Tensor:
    """Extend edge colour outward into the transparent region.

    ``.ART`` stores transparency as palette index 0, so the keyed pixels carry an
    arbitrary colour. Left in place it interpolates into the silhouette and fringes
    every sprite, and no downstream alpha threshold recovers it.

    Each pass fills only the frontier — transparent pixels with at least one known
    neighbour — and then marks them known. Averaging over the whole unknown region
    instead would diffuse colour inward rather than extend the edge.

    Args:
        rgb: ``(1, 3, H, W)`` float tensor in [0, 1].
        known: ``(1, 1, H, W)`` float mask, 1 where opaque.
        passes: Maximum frontier iterations.

    Returns:
        ``rgb`` with the keyed region overwritten; opaque pixels are untouched.
    """
    kernel = torch.ones(1, 1, 3, 3, device=rgb.device, dtype=rgb.dtype)
    filled = rgb * known
    mask = known.clone()

    for _ in range(passes):
        if mask.min() >= 1.0:
            break
        neighbours = F.conv2d(mask, kernel, padding=1)
        frontier = ((neighbours > 0) & (mask == 0)).to(rgb.dtype)
        if frontier.sum() == 0:
            break
        totals = F.conv2d(filled, kernel.expand(3, 1, 3, 3), padding=1, groups=3)
        averaged = totals / neighbours.clamp(min=1.0)
        filled = torch.where(frontier.bool(), averaged, filled)
        mask = mask + frontier

    return filled


def _infer(model: ImageModelDescriptor, tensor: torch.Tensor, tile: int, overlap: int) -> torch.Tensor:
    """Run ``model`` over ``tensor``, tiling with a feathered overlap when needed."""
    _, _, height, width = tensor.shape
    scale = int(model.scale)

    if tile <= 0 or (height <= tile and width <= tile):
        return model(tensor)

    stride = max(tile - overlap, 1)
    out = torch.zeros(1, tensor.shape[1], height * scale, width * scale, device=tensor.device, dtype=tensor.dtype)
    weights = torch.zeros_like(out[:, :1])

    ys = sorted({*range(0, max(height - tile, 0) + 1, stride), max(height - tile, 0)})
    xs = sorted({*range(0, max(width - tile, 0) + 1, stride), max(width - tile, 0)})

    for y in ys:
        for x in xs:
            y1, x1 = min(y + tile, height), min(x + tile, width)
            patch = model(tensor[:, :, y:y1, x:x1])
            feather = _feather(patch.shape[-2], patch.shape[-1], overlap * scale, patch.device, patch.dtype)
            out[:, :, y * scale : y1 * scale, x * scale : x1 * scale] += patch * feather
            weights[:, :, y * scale : y1 * scale, x * scale : x1 * scale] += feather

    return out / weights.clamp(min=1e-8)


def _feather(height: int, width: int, ramp: int, device: torch.device, dtype: torch.dtype) -> torch.Tensor:
    """Linear ramp-in/ramp-out window so overlapping tiles blend without a seam."""
    if ramp <= 0:
        return torch.ones(1, 1, height, width, device=device, dtype=dtype)

    def axis(length: int) -> torch.Tensor:
        w = torch.ones(length, device=device, dtype=dtype)
        n = min(ramp, length // 2)
        if n > 0:
            ramp_values = torch.linspace(1.0 / (n + 1), 1.0, n, device=device, dtype=dtype)
            w[:n] = ramp_values
            w[-n:] = ramp_values.flip(0)
        return w

    return (axis(height)[:, None] * axis(width)[None, :])[None, None]


def _resize(tensor: torch.Tensor, height: int, width: int) -> torch.Tensor:
    if tensor.shape[-2:] == (height, width):
        return tensor
    if tensor.shape[-2] >= height and tensor.shape[-1] >= width:
        return F.interpolate(tensor, size=(height, width), mode="area")
    return F.interpolate(tensor, size=(height, width), mode="bicubic", align_corners=False)


def upscale_rgba(
    image: Image.Image,
    model: LoadedModel,
    scale: int,
    device: torch.device,
    *,
    alpha_scale: str,
    tile: int,
    tile_overlap: int,
    bleed_passes: int,
) -> Image.Image:
    """Upscale ``image`` to exactly ``scale`` times its source dimensions.

    Returns 8-bit RGBA. The 1-bit threshold and palette quantisation belong to the
    caller: both depend on how index 0 is assigned in the target ``.ART`` palette.
    """
    source = image.convert("RGBA")
    width, height = source.size
    target_h, target_w = height * scale, width * scale

    array = torch.from_numpy(np.asarray(source, dtype=np.uint8).copy())
    planes = array.permute(2, 0, 1).unsqueeze(0).to(device=device, dtype=torch.float32) / 255.0
    rgb, alpha = planes[:, :3], planes[:, 3:]

    with torch.inference_mode():
        rgb = bleed_alpha(rgb, (alpha > 0).to(rgb.dtype), bleed_passes)

        if model.input_channels == 1:
            rgb_out = _infer(model.descriptor, rgb.mean(dim=1, keepdim=True), tile, tile_overlap).expand(-1, 3, -1, -1)
        else:
            rgb_out = _infer(model.descriptor, rgb, tile, tile_overlap)

        if alpha_scale == "model":
            # Hard 1-bit masks can ring under a model trained on photographic content.
            alpha_out = _infer(model.descriptor, alpha.expand(-1, model.input_channels, -1, -1), tile, tile_overlap)
            alpha_out = _resize(alpha_out.mean(dim=1, keepdim=True), target_h, target_w)
        else:
            # Straight to target with nearest: area resampling on the 4x-model/2x-target
            # path would return soft values and cost the caller a clean 1-bit threshold.
            alpha_out = F.interpolate(alpha, size=(target_h, target_w), mode="nearest-exact")

        rgb_out = _resize(rgb_out, target_h, target_w).clamp(0.0, 1.0)
        alpha_out = alpha_out.clamp(0.0, 1.0)

        result = torch.cat([rgb_out, alpha_out], dim=1)

    if result.shape[-2:] != (target_h, target_w):
        raise RuntimeError(f"scale contract violated: got {tuple(result.shape[-2:])}, want {(target_h, target_w)}")

    out = result.mul(255.0).round().clamp(0, 255).to(torch.uint8).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(out, mode="RGBA")
