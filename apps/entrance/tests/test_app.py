"""Tests for the FastAPI application."""

import pytest
from fastapi.testclient import TestClient

from entrance.app import app
from entrance.settings import Settings


@pytest.fixture
def client():
    """Create a test client."""
    return TestClient(app)


def test_root_endpoint_returns_html(client):
    """Test the root endpoint returns HTML."""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Library of Alexandria Entrance" in response.text


def test_root_endpoint_structure(client):
    """Test that root endpoint has expected HTML structure."""
    response = client.get("/")
    assert response.status_code == 200
    # Should have either app cards or "no apps" message
    html = response.text
    assert "app-grid" in html or "no-apps" in html


def test_apps_endpoint_returns_json(client):
    """Test /apps endpoint returns JSON list."""
    response = client.get("/apps")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_apps_endpoint_structure(client):
    """Test /apps endpoint returns proper structure."""
    response = client.get("/apps")
    assert response.status_code == 200
    apps = response.json()

    # If there are apps, they should have the right structure
    for app_data in apps:
        assert "name" in app_data
        assert "port" in app_data
        assert "use_host_ip" in app_data
        assert "description" in app_data
        assert isinstance(app_data["name"], str)
        assert isinstance(app_data["port"], int)
        assert 1 <= app_data["port"] <= 65535
        assert isinstance(app_data["use_host_ip"], bool)


def test_health_check(client):
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "apps_configured" in data
    assert isinstance(data["apps_configured"], int)
    assert data["apps_configured"] >= 0


def test_favicon_endpoint(client):
    """Test that favicon endpoint returns SVG."""
    response = client.get("/favicon.ico")
    assert response.status_code == 200
    assert "image/svg+xml" in response.headers["content-type"]
    assert "🏛️" in response.text


def test_settings_configuration():
    """Test that settings can be instantiated and have expected attributes."""
    settings = Settings()
    assert hasattr(settings, "log_level")
    assert hasattr(settings, "apps")
    assert hasattr(settings, "blocked_ports")
    assert hasattr(settings, "allowed_origins")
    assert isinstance(settings.apps, list)
    assert isinstance(settings.blocked_ports, set)
    assert isinstance(settings.allowed_origins, list)


def test_host_ip_flag():
    """Test that use_host_ip flag works correctly."""
    from entrance.settings import LocalhostApp, get_host_ip

    # Test app with use_host_ip flag
    app_with_host_ip = LocalhostApp(name="Test App", port=8200, use_host_ip=True, description="Test")
    assert app_with_host_ip.use_host_ip is True
    assert app_with_host_ip.port == 8200

    # Test app without use_host_ip flag (default False)
    app_without_flag = LocalhostApp(name="Test App 2", port=8080, description="Test")
    assert app_without_flag.use_host_ip is False
    assert app_without_flag.port == 8080

    # Verify get_host_ip returns a valid IP
    host_ip = get_host_ip()
    assert isinstance(host_ip, str)
    assert len(host_ip) > 0
    # Basic IP format check (has dots)
    assert "." in host_ip
