import logging
from pathlib import Path

import yaml
from pydantic import BaseModel, Field, field_validator

from entrance.settings import settings

# Set up logging
logger = logging.getLogger(__name__)


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
    description: str | None = Field(None, description="Optional application description")

    @field_validator("port")
    @classmethod
    def validate_port_security(cls, port: int) -> int:
        """Validate port number and block dangerous ports.

        Args:
            port: Port number to validate

        Returns:
            Validated port number

        Raises:
            ValueError: If port is blocked for security reasons
        """
        # Check for blocked ports
        if settings.is_port_blocked(port):
            raise ValueError(
                f"Port {port} is blocked for security reasons. Please use a different port (recommended: 8000-9000)."
            )

        return port

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


class AppConfig(BaseModel):
    """Application configuration containing all localhost apps.

    Attributes:
        apps: List of localhost applications
    """

    apps: list[LocalhostApp] = Field(default_factory=list, description="List of localhost applications")

    @classmethod
    def load(cls, config_path: str | Path = "config.yaml") -> "AppConfig":
        """Load and parse the configuration file.

        Args:
            config_path: Path to the YAML configuration file

        Returns:
            AppConfig instance with validated application configurations

        Raises:
            FileNotFoundError: If config file doesn't exist
            ValueError: If config file is empty or invalid
            ValidationError: If config data doesn't match schema

        Security Note:
            Uses yaml.safe_load() to prevent arbitrary code execution.
            All data is validated through Pydantic models before use.
        """
        config_path = Path(config_path)

        if not config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

        logger.info(f"Loading configuration from {config_path}")

        # Use safe_load to prevent code execution
        with open(config_path, "r") as f:
            raw_config = yaml.safe_load(f)

        if not raw_config:
            raise ValueError("Empty YAML file")

        if not isinstance(raw_config, list):
            raise ValueError("Configuration must be a list of applications")

        # Validate and parse each app configuration
        # Pydantic will run all validators including security checks
        apps = [LocalhostApp(**app) for app in raw_config]

        logger.info(f"Successfully loaded {len(apps)} application(s)")
        return cls(apps=apps)
