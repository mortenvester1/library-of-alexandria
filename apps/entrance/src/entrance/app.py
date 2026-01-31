import logging
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.templating import Jinja2Templates

import entrance
from entrance.settings import Settings, get_host_ip, get_settings

# Initialize with default settings for logging setup
settings = get_settings()
entrance.set_log_level(settings.log_level)
logger = logging.getLogger(__name__)

templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for application startup and shutdown."""
    # Startup: Configuration already loaded via Settings
    logger.info(f"Starting {entrance.__name__.replace('_', ' ').capitalize()} v{entrance.__version__}")

    settings = get_settings()
    logger.info(f"Loaded {len(settings.apps)} application(s) from configuration")
    logger.debug("Debug logging enabled")
    logger.debug(f"Hostname: {settings.hostname}")
    logger.debug(f"App settings: {settings}")

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

# Add CORS to enable serving over local network
# Use init settings for middleware (can't use dependency injection here)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root(request: Request, settings: Annotated[Settings, Depends(get_settings)]):
    """Root endpoint rendering the main UI with application list.

    Security: Only accessible from local network when properly configured.
    """
    logger.debug(f"Root endpoint accessed from {request.client.host if request.client else 'unknown'}")

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={"apps": settings.apps, "host_ip": settings.hostname},
    )


@app.get("/apps")
async def get_apps(settings: Annotated[Settings, Depends(get_settings)]):
    """Return JSON list of all configured applications.

    Security: Returns validated application configurations only.
    """
    logger.debug(f"Apps endpoint accessed, returning {len(settings.apps)} app(s)")
    return settings.apps


@app.get("/health")
async def health_check(settings: Annotated[Settings, Depends(get_settings)]):
    """Health check endpoint for monitoring.

    Returns:
        dict: Status information including number of configured apps
    """
    return {
        "status": "healthy",
        "apps_configured": len(settings.apps),
    }


@app.get("/favicon.ico")
async def favicon(request: Request):
    """Return a library emoji favicon to prevent 404 errors in browser logs."""
    return templates.TemplateResponse(
        request=request,
        name="favicon.svg",
        media_type="image/svg+xml",
    )
