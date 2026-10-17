import os
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
    YamlConfigSettingsSource,
)

# Default Firefox profile root on macOS.
DEFAULT_FIREFOX_ROOT = Path.home() / "Library" / "Application Support" / "Firefox"


class Category(BaseModel):
    """A named classifier over the flat ``fieldname``/``value`` store.

    An entry belongs to the category when it matches every pattern that is set
    (AND semantics); an unset pattern is ignored. ``value_regex`` is the strong
    signal (e.g. email shape); ``field_regex`` is best-effort (names/addresses
    can only be guessed from the fieldname).

    Attributes:
        name: Category identifier, e.g. ``email``.
        field_regex: Optional regex matched against the fieldname.
        value_regex: Optional regex matched against the value.
        allowlist: Filename (under ``allowlist_dir``) of values to KEEP. An
            allowlist-purge deletes every category entry whose value is not in
            this file.
        normalize: How values are canonicalized before allowlist comparison.
            ``text`` (default) trims + casefolds. ``phone`` compares on digits
            only (US country-code aware), so ``+1 929 395 3469`` and
            ``9293953469`` match the same allowlist entry.
    """

    name: str = Field(..., min_length=1)
    field_regex: str | None = None
    value_regex: str | None = None
    allowlist: str | None = None
    normalize: Literal["text", "phone"] = "text"


class Settings(BaseSettings):
    """Application settings.

    Non-``categories`` values may be overridden via ``LETHE_*`` environment
    variables; ``categories`` are loaded from the YAML config file.

    Attributes:
        firefox_root: Firefox data directory holding ``profiles.ini``.
        db_path: Explicit override for the ``formhistory.sqlite`` path. When
            unset, it is resolved from ``profiles.ini``.
        backup_dir: Directory for timestamped DB backups taken before writes.
            Defaults outside the repo — backups contain plaintext secrets.
        allowlist_dir: Directory holding per-category allowlist text files.
        categories: Category classifiers loaded from the YAML config.
        host / port: uvicorn bind address.
        log_level: Logging level.
    """

    model_config = SettingsConfigDict(
        yaml_file=os.environ.get("LETHE_CONFIG_FILE", "categories.yaml"),
        yaml_file_encoding="utf-8",
        env_prefix="LETHE_",
        extra="ignore",
    )

    firefox_root: Path = DEFAULT_FIREFOX_ROOT
    db_path: Path | None = None
    backup_dir: Path = Path.home() / ".lethe" / "backups"
    allowlist_dir: Path = Path("allow")

    categories: list[Category] = Field(default_factory=list)

    host: str = "127.0.0.1"
    port: int = 8600
    log_level: str = "INFO"

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (
            init_settings,
            env_settings,
            YamlConfigSettingsSource(settings_cls),
        )

    def category(self, name: str) -> Category | None:
        """Return the configured category by name, or None."""
        return next((c for c in self.categories if c.name == name), None)


@lru_cache
def get_settings() -> Settings:
    return Settings()
