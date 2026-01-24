import logging
import logging.config
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

import colorlog

try:
    __version__ = version("entrance")
except PackageNotFoundError:
    __version__ = "0.1.0"

logger = logging.getLogger(__name__)


def set_log_level(log_level: str):
    logger.setLevel(log_level.upper())
