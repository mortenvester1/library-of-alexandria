"""Tests for the FastAPI application."""

import tempfile
from pathlib import Path

import pytest
import yaml
from entrance.app import app, app_config
from entrance.config import AppConfig, LocalhostApp
from fastapi.testclient import TestClient

client = TestClient(app)


@pytest.fixture
def sample_config_file():
    """Create a temporary config file for testing."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
        config_data = [
            {"name": "Test App 1", "port": 8080, "description": "First test app"},
            {"name": "Test App 2", "port": 3000},
        ]
        yaml.dump(config_data, f)
        yield Path(f.name)
    Path(f.name).unlink(missing_ok=True)


@pytest.fixture
def load_test_config(sample_config_file, monkeypatch):
    """Load test config into the app's config."""
    import entrance.app

    test_config = AppConfig.load(sample_config_file)
    monkeypatch.setattr(entrance.app, "app_config", test_config)
    yield
    # Reset to empty config
    monkeypatch.setattr(entrance.app, "app_config", AppConfig(apps=[]))


def test_root_endpoint_returns_html():
    """Test the root endpoint returns HTML."""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Alexandria Home" in response.text


def test_root_endpoint_displays_apps(load_test_config):
    """Test the root endpoint displays configured apps."""
    response = client.get("/")
    assert response.status_code == 200
    assert "Test App 1" in response.text
    assert "Test App 2" in response.text
    assert "8080" in response.text
    assert "3000" in response.text


def test_apps_endpoint_returns_empty_list(monkeypatch):
    """Test /apps endpoint returns empty list when no config loaded."""
    import entrance.app

    monkeypatch.setattr(entrance.app, "app_config", AppConfig(apps=[]))
    response = client.get("/apps")
    assert response.status_code == 200
    assert response.json() == []


def test_apps_endpoint_returns_app_list(load_test_config):
    """Test /apps endpoint returns list of configured apps."""
    response = client.get("/apps")
    assert response.status_code == 200
    apps = response.json()
    assert len(apps) == 2
    assert apps[0]["name"] == "Test App 1"
    assert apps[0]["port"] == 8080
    assert apps[0]["description"] == "First test app"
    assert apps[1]["name"] == "Test App 2"
    assert apps[1]["port"] == 3000
    assert apps[1]["description"] is None


def test_health_check():
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "apps_configured" in data
    assert isinstance(data["apps_configured"], int)


def test_apps_endpoint_json_schema(load_test_config):
    """Test /apps endpoint returns proper JSON schema."""
    response = client.get("/apps")
    assert response.status_code == 200
    apps = response.json()
    for app_data in apps:
        assert "name" in app_data
        assert "port" in app_data
        assert "description" in app_data
        assert isinstance(app_data["name"], str)
        assert isinstance(app_data["port"], int)
