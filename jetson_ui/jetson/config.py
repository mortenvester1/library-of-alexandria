import os

from functools import lru_cache
from typing import override

from pydantic import BaseModel
from pydantic_settings import (
    BaseSettings,
    SettingsConfigDict,
    PydanticBaseSettingsSource,
    YamlConfigSettingsSource,
)


class AppConfig(BaseModel):
    name: str
    port: int
    url_postfix: str | None = ""


class Settings(BaseSettings):
    app_name: str
    host_name: str
    apps: list[AppConfig]

    # model_config + classmethod to defined Which file to read
    model_config = SettingsConfigDict(     # pyright:ignore[reportUnannotatedClassAttribute]
        yaml_file=os.environ.get("JETSON_UI_CONFIG", ".env.yaml"),
    )

    @override
    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (YamlConfigSettingsSource(settings_cls),)


@lru_cache
def get_settings() -> Settings:
    return Settings() # pyright: ignore[reportCallIssue]
