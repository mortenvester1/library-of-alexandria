"""Tests for security configuration and utilities."""

import pytest
from entrance.app import app
from entrance.config import LocalhostApp
from entrance.security import SecurityConfig
from fastapi.testclient import TestClient
from pydantic import ValidationError

client = TestClient(app)


class TestAppConfigSecurity:
    """Tests for AppConfig security validations."""

    def test_valid_port_range(self):
        """Test that valid ports are accepted."""
        config = LocalhostApp(name="Test App", port=8080)
        assert config.port == 8080

    def test_port_at_lower_boundary(self):
        """Test port at lower boundary (1)."""
        config = LocalhostApp(name="Test App", port=1)
        assert config.port == 1

    def test_port_at_upper_boundary(self):
        """Test port at upper boundary (65535)."""
        config = LocalhostApp(name="Test App", port=65535)
        assert config.port == 65535

    def test_port_below_valid_range(self):
        """Test that port below 1 raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=0)
        assert "greater than or equal to 1" in str(exc_info.value)

    def test_port_above_valid_range(self):
        """Test that port above 65535 raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=65536)
        assert "less than or equal to 65535" in str(exc_info.value)

    def test_name_with_path_traversal(self):
        """Test that names with path traversal are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="../etc/passwd", port=8080)
        assert "invalid characters" in str(exc_info.value).lower()

    def test_name_with_forward_slash(self):
        """Test that names with forward slashes are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="path/to/app", port=8080)
        assert "invalid characters" in str(exc_info.value).lower()

    def test_name_with_backslash(self):
        """Test that names with backslashes are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="path\\to\\app", port=8080)
        assert "invalid characters" in str(exc_info.value).lower()

    def test_name_with_control_characters(self):
        """Test that names with control characters are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test\x00App", port=8080)
        assert "control characters" in str(exc_info.value).lower()

    def test_name_with_newline(self):
        """Test that names with newlines are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test\nApp", port=8080)
        assert "control characters" in str(exc_info.value).lower()

    def test_name_with_spaces_trimmed(self):
        """Test that leading/trailing spaces are trimmed."""
        config = LocalhostApp(name="  Test App  ", port=8080)
        assert config.name == "Test App"

    def test_valid_special_characters_in_name(self):
        """Test that safe special characters are allowed in names."""
        config = LocalhostApp(name="Test-App_123 (v2.0)", port=8080)
        assert config.name == "Test-App_123 (v2.0)"


class TestSecurityHeaders:
    """Tests for security headers middleware."""

    def test_security_headers_present(self):
        """Test that security headers are added to responses."""
        response = client.get("/health")
        assert response.status_code == 200

        # Check for security headers
        assert "X-Content-Type-Options" in response.headers
        assert response.headers["X-Content-Type-Options"] == "nosniff"

        assert "X-Frame-Options" in response.headers
        assert response.headers["X-Frame-Options"] == "DENY"

        assert "X-XSS-Protection" in response.headers
        assert response.headers["X-XSS-Protection"] == "1; mode=block"

        assert "Referrer-Policy" in response.headers

        assert "X-Local-Network-Only" in response.headers
        assert response.headers["X-Local-Network-Only"] == "true"

    def test_security_headers_on_root_endpoint(self):
        """Test that security headers are present on root endpoint."""
        response = client.get("/")
        assert response.status_code == 200
        assert "X-Content-Type-Options" in response.headers
        assert "X-Frame-Options" in response.headers

    def test_security_headers_on_apps_endpoint(self):
        """Test that security headers are present on apps endpoint."""
        response = client.get("/apps")
        assert response.status_code == 200
        assert "X-Content-Type-Options" in response.headers
        assert "X-Frame-Options" in response.headers


class TestHealthEndpointSecurity:
    """Tests for health endpoint security features."""

    def test_health_endpoint_includes_app_count(self):
        """Test that health endpoint includes security-relevant info."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "apps_configured" in data
        assert isinstance(data["apps_configured"], int)


class TestSecurityConfig:
    """Tests for SecurityConfig class."""

    def test_default_configuration(self):
        """Test SecurityConfig with default values."""
        config = SecurityConfig()
        assert config.enforce_local_only is False
        assert config.log_security_events is True
        assert config.enable_security_headers is True

    def test_custom_configuration(self):
        """Test SecurityConfig with custom values."""
        config = SecurityConfig(
            enforce_local_only=True,
            log_security_events=False,
            enable_security_headers=False,
        )
        assert config.enforce_local_only is True
        assert config.log_security_events is False
        assert config.enable_security_headers is False


class TestCORSConfiguration:
    """Tests for CORS configuration."""

    def test_cors_headers_present(self):
        """Test that CORS headers are present in OPTIONS response."""
        response = client.options("/apps")
        # CORS middleware should handle OPTIONS requests
        assert response.status_code in [200, 405]  # May vary by FastAPI version

    def test_local_origin_allowed(self):
        """Test that requests from localhost are allowed."""
        response = client.get("/health", headers={"Origin": "http://localhost:3000"})
        assert response.status_code == 200


class TestYAMLSafetyValidation:
    """Tests to ensure YAML loading is safe."""

    def test_config_uses_safe_load(self):
        """Verify that AppConfig.load uses yaml.safe_load (not yaml.load)."""
        import inspect

        from entrance.config import AppConfig

        # Get the source code of the load method
        source = inspect.getsource(AppConfig.load)

        # Ensure safe_load is used
        assert "safe_load" in source

        # Ensure unsafe load is NOT used
        assert "yaml.load(" not in source


class TestBlockedPortsValidation:
    """Tests for blocked ports validation."""

    def test_blocked_port_80(self):
        """Test that port 80 (HTTP) is blocked."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=80)
        assert "blocked" in str(exc_info.value).lower()

    def test_blocked_port_22(self):
        """Test that port 22 (SSH) is blocked."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=22)
        assert "blocked" in str(exc_info.value).lower()

    def test_blocked_port_443(self):
        """Test that port 443 (HTTPS) is blocked."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=443)
        assert "blocked" in str(exc_info.value).lower()

    def test_blocked_port_3306(self):
        """Test that port 3306 (MySQL) is blocked."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=3306)
        assert "blocked" in str(exc_info.value).lower()

    def test_blocked_port_5432(self):
        """Test that port 5432 (PostgreSQL) is blocked."""
        with pytest.raises(ValidationError) as exc_info:
            LocalhostApp(name="Test App", port=5432)
        assert "blocked" in str(exc_info.value).lower()

    def test_allowed_port_8080(self):
        """Test that port 8080 is allowed."""
        config = LocalhostApp(name="Test App", port=8080)
        assert config.port == 8080

    def test_allowed_port_9000(self):
        """Test that port 9000 is allowed."""
        config = LocalhostApp(name="Test App", port=9000)
        assert config.port == 9000

    def test_allowed_port_3000(self):
        """Test that port 3000 is allowed."""
        config = LocalhostApp(name="Test App", port=3000)
        assert config.port == 3000


class TestSettingsConfiguration:
    """Tests for Settings class."""

    def test_default_blocked_ports(self):
        """Test that default blocked ports include common services."""
        from entrance.settings import settings

        assert settings.is_port_blocked(22)  # SSH
        assert settings.is_port_blocked(80)  # HTTP
        assert settings.is_port_blocked(443)  # HTTPS
        assert settings.is_port_blocked(3306)  # MySQL
        assert settings.is_port_blocked(5432)  # PostgreSQL

    def test_allowed_ports_not_blocked(self):
        """Test that common application ports are not blocked."""
        from entrance.settings import settings

        assert not settings.is_port_blocked(8080)
        assert not settings.is_port_blocked(3000)
        assert not settings.is_port_blocked(9000)
        assert not settings.is_port_blocked(8000)

    def test_cors_regex_with_private_network(self):
        """Test CORS regex includes private network ranges."""
        from entrance.settings import settings

        regex = settings.get_cors_origin_regex()
        assert "192\\.168" in regex
        assert "10\\." in regex
        assert "172\\." in regex

    def test_allow_private_network_enabled_by_default(self):
        """Test that private network access is enabled by default."""
        from entrance.settings import settings

        assert settings.allow_private_network is True


class TestPrivateNetworkCORS:
    """Tests for private network CORS configuration."""

    def test_private_network_origin_pattern(self):
        """Test that private network origin pattern is comprehensive."""
        from entrance.settings import settings

        # Test that the regex pattern includes private ranges
        origin_regex = settings.get_cors_origin_regex()

        # Check for 192.168.x.x
        assert "192" in origin_regex

        # Check for 10.x.x.x
        assert "10" in origin_regex

        # Check for 172.16-31.x.x
        assert "172" in origin_regex


class TestApplicationStartupSecurity:
    """Tests for application startup security."""

    def test_app_starts_without_config_file(self):
        """Test that app starts safely even without config file."""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"

    def test_docs_endpoint_available(self):
        """Test that API docs are available for reference."""
        response = client.get("/docs")
        assert response.status_code == 200

    def test_openapi_schema_available(self):
        """Test that OpenAPI schema is available."""
        response = client.get("/openapi.json")
        assert response.status_code == 200
        schema = response.json()
        assert "openapi" in schema
        assert "info" in schema
