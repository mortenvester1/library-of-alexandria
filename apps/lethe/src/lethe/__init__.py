import logging
from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("lethe")
except PackageNotFoundError:
    __version__ = "0.1.0"

logger = logging.getLogger(__name__)


def set_log_level(log_level: str):
    logger.setLevel(log_level.upper())
