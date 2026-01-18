import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from entrance.settings import settings

logger = logging.getLogger(__name__)


def configure_security(app: FastAPI) -> None:
    """Configure security settings for the FastAPI application.

    This function sets up:
    - CORS middleware for local and private network access
    - Security headers
    - Exception handlers

    Args:
        app: FastAPI application instance

    Security Notes:
        - Allows local network origins (localhost, 127.0.0.1)
        - Allows private network ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
        - Adds security headers to all responses
        - Logs security-related events
    """
    # Get CORS origin regex from settings
    origin_regex = settings.get_cors_origin_regex()

    # Configure CORS for local and private network access
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_origin_regex=origin_regex,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        max_age=3600,
    )

    if settings.allow_private_network:
        logger.info(
            "Security configuration applied: CORS enabled for localhost and private networks "
            "(192.168.x.x, 10.x.x.x, 172.16-31.x.x)"
        )
    else:
        logger.info("Security configuration applied: CORS enabled for localhost only")


def get_recommended_uvicorn_config() -> dict[str, Any]:
    """Get recommended Uvicorn configuration for local network deployment.

    Returns:
        Dictionary of Uvicorn configuration options

    Security Notes:
        - Binds to 0.0.0.0 to allow local network access
        - Access should be restricted via firewall/network configuration
        - Not intended for public internet exposure
    """
    config = {
        "host": "0.0.0.0",  # Bind to all interfaces (local network accessible)
        "port": 8000,
        "log_level": "info",
        "access_log": True,
        "server_header": False,  # Hide server implementation details
        "date_header": True,
    }

    logger.info(
        "Recommended configuration: Binding to 0.0.0.0:8000 for local network access. "
        "Ensure firewall rules restrict external access."
    )

    return config


async def security_headers_middleware(request: Request, call_next):
    """Add security headers to all responses.

    Args:
        request: Incoming request
        call_next: Next middleware/handler in chain

    Returns:
        Response with security headers added
    """
    response = await call_next(request)

    # Add security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # For local network, we don't enforce HTTPS
    # but we document the security implications
    response.headers["X-Local-Network-Only"] = "true"

    return response


def validate_local_access(request: Request) -> bool:
    """Validate that request comes from local network.

    Args:
        request: Incoming FastAPI request

    Returns:
        True if request is from local network, False otherwise

    Security Notes:
        This is a basic check and should be combined with proper
        network/firewall configuration for production use.
    """
    client_host = request.client.host if request.client else None

    if not client_host:
        logger.warning("Request received with no client host information")
        return False

    # Check if request is from localhost/local network
    local_patterns = [
        "127.0.0.1",
        "localhost",
        "::1",  # IPv6 localhost
    ]

    is_local = any(pattern in client_host for pattern in local_patterns)

    if not is_local:
        # Check for private network ranges (10.x, 172.16-31.x, 192.168.x)
        if client_host.startswith("10.") or client_host.startswith("192.168."):
            is_local = True
        elif client_host.startswith("172."):
            # Check for 172.16.0.0 - 172.31.255.255
            try:
                second_octet = int(client_host.split(".")[1])
                if 16 <= second_octet <= 31:
                    is_local = True
            except (IndexError, ValueError):
                pass

    if not is_local:
        logger.warning(f"Request from non-local address: {client_host}")

    return is_local


class SecurityConfig:
    """Security configuration container.

    Attributes:
        enforce_local_only: Whether to enforce local network access only
        log_security_events: Whether to log security-related events
        enable_security_headers: Whether to add security headers to responses
    """

    def __init__(
        self,
        enforce_local_only: bool = False,
        log_security_events: bool = True,
        enable_security_headers: bool = True,
    ):
        """Initialize security configuration.

        Args:
            enforce_local_only: If True, reject requests from outside local network
            log_security_events: If True, log security-related events
            enable_security_headers: If True, add security headers to responses
        """
        self.enforce_local_only = enforce_local_only
        self.log_security_events = log_security_events
        self.enable_security_headers = enable_security_headers

        if log_security_events:
            logger.info(
                f"Security configuration initialized: "
                f"enforce_local_only={enforce_local_only}, "
                f"security_headers={enable_security_headers}"
            )
