import logging
from contextlib import asynccontextmanager
from pathlib import Path

import colorlog
from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates

import entrance
from entrance.config import AppConfig
from entrance.security import configure_security, security_headers_middleware
from entrance.settings import settings

# Set up logging with colors
handler = colorlog.StreamHandler()
handler.setFormatter(
    colorlog.ColoredFormatter(
        "[%(asctime)s][%(log_color)s%(levelname)s%(reset)s][%(name)s]%(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        reset=True,
        log_colors={
            "DEBUG": "cyan",
            "INFO": "green",
            "WARNING": "yellow",
            "ERROR": "red",
            "CRITICAL": "red,bg_white",
        },
    )
)

# Configure logger for this module only
logger = logging.getLogger(__name__)
logger.addHandler(handler)
logger.setLevel(settings.log_level.upper())

# Set up templates directory
templates_dir = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(templates_dir))

# Global variable to hold config
app_config: AppConfig | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for application startup and shutdown."""
    # Startup: Load configuration
    global app_config
    logger.info(f"Starting {entrance.__name__.replace('_', ' ').capitalize()} v{entrance.__version__}")
    try:
        app_config = AppConfig.load(settings.config_file)
    except FileNotFoundError:
        # Config file doesn't exist
        logger.warning("Configuration file not found, starting with empty application list")
        app_config = AppConfig(apps=[])
    except Exception as e:
        logger.error(f"Failed to load config: {e}, starting with empty application list")
        app_config = AppConfig(apps=[])

    logger.info(f"Loaded {len(app_config.apps)} application(s) from configuration")
    logger.debug(f"app config: {app_config}")
    logger.debug(f"app settings: {settings}")

    yield

    # Shutdown: cleanup if needed
    logger.info("Shutting down Alexandria Home application")


app = FastAPI(
    title=entrance.__name__,
    version=entrance.__version__,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure security (CORS, headers, etc.)
configure_security(app)

# Add security headers middleware
app.middleware("http")(security_headers_middleware)


@app.get("/")
async def root(request: Request):
    """Root endpoint rendering the main UI with application list.

    Security: Only accessible from local network when properly configured.
    """
    logger.debug(f"Root endpoint accessed from {request.client.host if request.client else 'unknown'}")
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={"apps": app_config.apps if app_config else []},
    )


@app.get("/apps")
async def get_apps():
    """Return JSON list of all configured applications.

    Security: Returns validated application configurations only.
    """
    apps = app_config.apps if app_config else []
    logger.debug(f"Apps endpoint accessed, returning {len(apps)} app(s)")
    return apps


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring.

    Returns:
        dict: Status information including number of configured apps
    """
    apps_count = len(app_config.apps) if app_config else 0
    return {
        "status": "healthy",
        "apps_configured": apps_count,
    }
