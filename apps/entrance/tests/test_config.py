"""Tests for the configuration module."""

import tempfile
from pathlib import Path

import pytest
import yaml
from entrance.config import AppConfig, LocalhostApp
from pydantic import ValidationError


class TestLocalhostApp:
    """Tests for the LocalhostApp model."""

    def test_valid_app_config_with_description(self):
        """Test creating a valid app config with all fields."""
        config = LocalhostApp(name="Test App", port=8080, description="A test application")
        assert config.name == "Test App"
        assert config.port == 8080
        assert config.description == "A test application"

    def test_valid_app_config_without_description(self):
        """Test creating a valid app config without description."""
        config = LocalhostApp(name="Test App", port=8080)
        assert config.name == "Test App"
        assert config.port == 8080
        assert config.description is None

    def test_invalid_empty_name(self):
        """Test that empty name raises validation error."""
        with pytest.raises(ValidationError):
            LocalhostApp(name="", port=8080)

    def test_invalid_port_too_low(self):
        """Test that port below 1 raises validation error."""
        with pytest.raises(ValidationError):
            LocalhostApp(name="Test App", port=0)

    def test_invalid_port_too_high(self):
        """Test that port above 65535 raises validation error."""
        with pytest.raises(ValidationError):
            LocalhostApp(name="Test App", port=65536)

    def test_invalid_port_type(self):
        """Test that non-integer port raises validation error."""
        with pytest.raises(ValidationError):
            LocalhostApp(name="Test App", port="not-a-number")

    def test_missing_required_field(self):
        """Test that missing required fields raise validation error."""
        with pytest.raises(ValidationError):
            LocalhostApp(name="Test App")


class TestAppConfig:
    """Tests for the AppConfig class."""

    @pytest.fixture
    def temp_config_file(self):
        """Create a temporary config file for testing."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
            yield Path(f.name)
        # Cleanup
        Path(f.name).unlink(missing_ok=True)

    def test_load_valid_config(self, temp_config_file):
        """Test loading a valid configuration file."""
        config_data = [
            {"name": "App 1", "port": 8080, "description": "First app"},
            {"name": "App 2", "port": 3000, "description": "Second app"},
        ]
        with open(temp_config_file, "w") as f:
            yaml.dump(config_data, f)

        config = AppConfig.load(temp_config_file)

        assert len(config.apps) == 2
        assert config.apps[0].name == "App 1"
        assert config.apps[0].port == 8080
        assert config.apps[0].description == "First app"
        assert config.apps[1].name == "App 2"
        assert config.apps[1].port == 3000

    def test_load_config_without_description(self, temp_config_file):
        """Test loading config with apps missing optional description."""
        config_data = [
            {"name": "App 1", "port": 8080},
            {"name": "App 2", "port": 3000, "description": "Has description"},
        ]
        with open(temp_config_file, "w") as f:
            yaml.dump(config_data, f)

        config = AppConfig.load(temp_config_file)

        assert len(config.apps) == 2
        assert config.apps[0].description is None
        assert config.apps[1].description == "Has description"

    def test_load_empty_file(self, temp_config_file):
        """Test that empty config file raises ValueError."""
        with open(temp_config_file, "w") as f:
            f.write("")

        with pytest.raises(ValueError, match="Empty YAML file"):
            AppConfig.load(temp_config_file)

    def test_load_non_list_config(self, temp_config_file):
        """Test that non-list config raises ValueError."""
        config_data = {"name": "App 1", "port": 8080}
        with open(temp_config_file, "w") as f:
            yaml.dump(config_data, f)

        with pytest.raises(ValueError, match="Configuration must be a list"):
            AppConfig.load(temp_config_file)

    def test_load_missing_required_field(self, temp_config_file):
        """Test that missing required field raises ValidationError."""
        config_data = [{"name": "App 1"}]  # Missing port
        with open(temp_config_file, "w") as f:
            yaml.dump(config_data, f)

        with pytest.raises(ValidationError):
            AppConfig.load(temp_config_file)

    def test_load_invalid_port(self, temp_config_file):
        """Test that invalid port raises ValidationError."""
        config_data = [{"name": "App 1", "port": 99999}]
        with open(temp_config_file, "w") as f:
            yaml.dump(config_data, f)

        with pytest.raises(ValidationError):
            AppConfig.load(temp_config_file)

    def test_file_not_found(self):
        """Test that non-existent file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError, match="Configuration file not found"):
            AppConfig.load("non_existent_file.yaml")

    def test_create_empty_app_config(self):
        """Test creating an empty AppConfig."""
        config = AppConfig()
        assert config.apps == []

    def test_create_app_config_with_apps(self):
        """Test creating an AppConfig with apps."""
        apps = [
            LocalhostApp(name="App 1", port=8080),
            LocalhostApp(name="App 2", port=3000),
        ]
        config = AppConfig(apps=apps)
        assert len(config.apps) == 2
        assert config.apps[0].name == "App 1"
        assert config.apps[1].name == "App 2"
