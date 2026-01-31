import logging
import os
import socket
from functools import lru_cache
from typing import Set

from pydantic import BaseModel, Field, field_validator
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
    YamlConfigSettingsSource,
)

logger = logging.getLogger(__name__)


def get_host_ip() -> str:
    """Get the host machine's IP address on the local network.

    Returns:
        str: The IP address as a string, or '127.0.0.1' if unable to determine
    """
    try:
        # Create a socket connection to determine the local IP
        # We connect to an external address (doesn't actually send data)
        # This helps us find the interface that would be used for network communication
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            ip_address = s.getsockname()[0]
            return ip_address
    except Exception as e:
        logger.warning(f"Could not determine host IP address: {e}. Using 127.0.0.1")
        return "127.0.0.1"


class LocalhostApp(BaseModel):
    """Configuration model for a single localhost application.

    Attributes:
        name: Display name of the application
        port: Port number where the application is running
        description: Optional description of the application

    Security:
        - Port must be in valid range (1-65535)
        - Warnings logged for reserved/privileged ports
    """

    name: str = Field(..., min_length=1, description="Application name")
    port: int = Field(..., ge=1, le=65535, description="Port number (1-65535)")
    route: str = Field(default="", description="Optional route")
    use_host_ip: bool = Field(default=False, description="Use host IP address instead of hostname")
    description: str | None = Field(default=None, description="Optional application description")

    @field_validator("name")
    @classmethod
    def validate_name_security(cls, name: str) -> str:
        """Validate application name for security.

        Args:
            name: Application name to validate

        Returns:
            Validated name

        Raises:
            ValueError: If name contains potentially dangerous characters
        """
        # Check for path traversal attempts
        if ".." in name or "/" in name or "\\" in name:
            raise ValueError(
                f"Application name '{name}' contains invalid characters. "
                "Names cannot contain path separators or '..' sequences."
            )

        # Check for control characters
        if any(ord(char) < 32 for char in name):
            raise ValueError(
                f"Application name '{name}' contains control characters. Only printable characters are allowed."
            )

        return name.strip()


class Settings(BaseSettings):
    """Application settings and configuration.

    Attributes:
        log_level: Logging level
        apps: List of localhost applications (loaded from YAML)
        blocked_ports: Set of ports that are blocked for security reasons
        allowed_origins: List of allowed CORS origins
    """

    model_config = SettingsConfigDict(
        yaml_file=os.environ.get("ENTRANCE_CONFIG_FILE", "config.yaml"),
        yaml_file_encoding="utf-8",
        env_prefix="ENTRANCE_",
        extra="ignore",
    )

    # Application settings
    hostname: str = "localhost"
    log_level: str = "INFO"
    blocked_ports: Set[int] = {
        # Well-known system ports (0-1023) - require root/admin privileges
        # FTP
        20,
        21,
        # SSH
        22,
        # Telnet
        23,
        # SMTP
        25,
        # DNS
        53,
        # HTTP
        80,
        # Kerberos
        88,
        # POP3
        110,
        # NNTP
        119,
        # NTP
        123,
        # NetBIOS
        137,
        138,
        139,
        # IMAP
        143,
        # SNMP
        161,
        162,
        # LDAP
        389,
        # HTTPS
        443,
        # SMB
        445,
        # SMTPS
        465,
        # Syslog
        514,
        # LDAPS
        636,
        # IMAPS
        993,
        # POP3S
        995,
        # Commonly exploited database ports
        1433,  # MS SQL Server
        1521,  # Oracle
        3306,  # MySQL
        5432,  # PostgreSQL
        27017,  # MongoDB
        # Redis
        6379,
        # Elasticsearch
        9200,
        9300,
    }

    # CORS settings
    allowed_origins: list[str] = ["*"]

    apps: list[LocalhostApp] = Field(default_factory=list, description="List of localhost applications")

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
            env_settings,
            YamlConfigSettingsSource(settings_cls),
        )

    @field_validator("apps")
    @classmethod
    def validate_app_ports(cls, apps: list[LocalhostApp], info) -> list[LocalhostApp]:
        """Validate that app ports are not blocked.

        Args:
            apps: List of localhost applications
            info: Validation info containing other field values

        Returns:
            Validated list of apps

        Raises:
            ValueError: If any app uses a blocked port or has invalid configuration
        """
        # Get blocked_ports from the validation context
        # Note: blocked_ports will be validated before apps due to field order
        blocked_ports = info.data.get("blocked_ports", cls.model_fields["blocked_ports"].default)

        for app in apps:
            if app.port in blocked_ports:
                raise ValueError(
                    f"Port {app.port} for app '{app.name}' is blocked for security reasons. "
                    f"Please use a different port (recommended: 8000-9000)."
                )

        return apps


@lru_cache
def get_settings():
    return Settings()
