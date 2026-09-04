"""Pipeline invariants, exercised with a stub model so no .pth is required.

The scale contract here is what ``art-lint`` gates on downstream: an output that
is off by a pixel surfaces as an art defect rather than a service bug.
"""

import numpy as np
import pytest
import torch
import torch.nn.functional as F
from PIL import Image

from upscaler.upscale import LoadedModel, bleed_alpha, upscale_rgba

DEVICE = torch.device("cpu")
KEY = (255, 0, 255)  # stand-in for whatever colour ART palette index 0 holds


class NearestStub:
    """Local, deterministic stand-in for a model: nearest upsample."""

    def __init__(self, scale: int) -> None:
        self.scale = scale

    def __call__(self, tensor: torch.Tensor) -> torch.Tensor:
        return F.interpolate(tensor, scale_factor=self.scale, mode="nearest")


class BlurStub(NearestStub):
    """Stand-in with a 3x3 receptive field, so tiling is actually exercised.

    A pixel-local stub makes tiled and untiled agree no matter what the feather
    window does; a model that reads its neighbours does not.
    """

    def __call__(self, tensor: torch.Tensor) -> torch.Tensor:
        channels = tensor.shape[1]
        kernel = torch.ones(channels, 1, 3, 3, dtype=tensor.dtype) / 9.0
        blurred = F.conv2d(F.pad(tensor, (1, 1, 1, 1), mode="replicate"), kernel, groups=channels)
        return super().__call__(blurred)


class ConstantStub(NearestStub):
    """Stand-in whose output is a constant, so tile coverage can be checked exactly."""

    VALUE = 128

    def __call__(self, tensor: torch.Tensor) -> torch.Tensor:
        constant = torch.full_like(tensor, self.VALUE / 255.0)
        return super().__call__(constant)


def stub(scale: int, channels: int = 3, cls: type[NearestStub] = NearestStub) -> LoadedModel:
    return LoadedModel("stub", cls(scale), "Stub", scale, channels)


def sprite(width: int, height: int) -> Image.Image:
    """Green disc on a keyed field — the shape ART transparency actually takes."""
    array = np.zeros((height, width, 4), dtype=np.uint8)
    array[:, :, 0], array[:, :, 1], array[:, :, 2] = KEY
    yy, xx = np.mgrid[0:height, 0:width]
    disc = (yy - height / 2) ** 2 + (xx - width / 2) ** 2 < (min(width, height) / 3) ** 2
    array[disc] = (40, 200, 90, 255)
    return Image.fromarray(array, mode="RGBA")


def run(image: Image.Image, model: LoadedModel, scale: int, **kwargs) -> Image.Image:
    kwargs.setdefault("alpha_scale", "box")
    kwargs.setdefault("tile", 0)
    kwargs.setdefault("tile_overlap", 0)
    kwargs.setdefault("bleed_passes", 16)
    return upscale_rgba(image, model, scale, DEVICE, **kwargs)


@pytest.mark.parametrize("size", [(37, 24), (78, 40), (13, 7)])
@pytest.mark.parametrize(("native", "target"), [(4, 2), (2, 2), (4, 4), (4, 1)])
def test_exact_scale(size: tuple[int, int], native: int, target: int) -> None:
    width, height = size
    out = run(sprite(width, height), stub(native), target)
    assert out.size == (width * target, height * target)


def test_bleed_preserves_opaque_pixels() -> None:
    array = np.asarray(sprite(64, 64), dtype=np.uint8).copy()
    planes = torch.from_numpy(array).permute(2, 0, 1)[None].float() / 255.0
    rgb, alpha = planes[:, :3], planes[:, 3:]
    known = (alpha > 0).float()

    bled = bleed_alpha(rgb, known, 16)

    assert torch.equal(bled * known, rgb * known)
    assert not torch.equal(bled, rgb), "bleed did not touch the keyed region"


def test_no_key_colour_fringe() -> None:
    out = np.asarray(run(sprite(64, 64), stub(4), 2))
    opaque = out[:, :, 3] > 127
    distance = np.abs(out[:, :, :3].astype(int) - np.array(KEY)).sum(-1)
    assert (opaque & (distance < 90)).sum() == 0


@pytest.mark.parametrize(("tile", "overlap"), [(64, 16), (48, 8), (37, 11), (256, 32)])
def test_tiling_matches_untiled(tile: int, overlap: int) -> None:
    """Feathered tiles must not leave a seam under a model with a receptive field.

    Exact equality is not expected: near a tile boundary the stub blurs against
    replicate padding rather than the true neighbour, so the feathered blend
    differs slightly. A seam would show up far above this.
    """
    image = sprite(200, 140)
    untiled = np.asarray(run(image, stub(2, cls=BlurStub), 2, tile=0)).astype(int)
    tiled = np.asarray(run(image, stub(2, cls=BlurStub), 2, tile=tile, tile_overlap=overlap)).astype(int)
    assert np.abs(untiled - tiled).max() <= 8


@pytest.mark.parametrize(("tile", "overlap"), [(64, 16), (48, 8), (37, 11), (13, 5), (200, 0), (7, 6)])
def test_every_output_pixel_is_covered_by_a_tile(tile: int, overlap: int) -> None:
    """A pixel no tile covers divides by the 1e-8 floor and returns garbage.

    A constant-output stub isolates that from resampling error: the result must be
    exactly the constant everywhere, whatever the tile grid does, so any gap or
    mis-normalised feather weight shows up as an exact-equality failure rather
    than hiding under a tolerance.
    """
    image = Image.new("RGBA", (200, 140), (0, 0, 0, 255))
    out = np.asarray(run(image, stub(2, cls=ConstantStub), 2, tile=tile, tile_overlap=overlap))
    assert np.array_equal(out[:, :, :3], np.full((280, 400, 3), ConstantStub.VALUE, dtype=np.uint8))


@pytest.mark.parametrize(("native", "target"), [(4, 2), (4, 4), (2, 2), (4, 1)])
def test_box_alpha_stays_binary(native: int, target: int) -> None:
    """``box`` is documented as preserving the 1-bit silhouette on every scale path.

    The 4x-model/2x-target combination is the one recommended for 4x SGI, and it
    is where an area resample would quietly reintroduce soft alpha.
    """
    alpha = np.asarray(run(sprite(64, 64), stub(native), target, alpha_scale="box"))[:, :, 3]
    assert set(np.unique(alpha)).issubset({0, 255})


def test_deterministic() -> None:
    first = np.asarray(run(sprite(64, 64), stub(4), 2, tile=32, tile_overlap=8))
    second = np.asarray(run(sprite(64, 64), stub(4), 2, tile=32, tile_overlap=8))
    assert np.array_equal(first, second)


def test_single_channel_model() -> None:
    assert run(sprite(37, 24), stub(4, channels=1), 2).size == (74, 48)
