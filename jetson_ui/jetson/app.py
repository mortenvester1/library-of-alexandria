from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from jetson.config import Settings, get_settings

app = FastAPI()
templates = Jinja2Templates(directory=(Path(__file__).parent / "templates").absolute())


@app.get("/", response_class=HTMLResponse)
async def read_root(
    request: Request, settings: Annotated[Settings, Depends(get_settings)]
):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "config": {
                app.name.capitalize(): f"{settings.host_name}:{app.port}"
                for app in settings.apps
            }
        },
    )


@app.get("/info")
async def info(settings: Annotated[Settings, Depends(get_settings)]):
    return {"app_name": settings.app_name, "n_apps": len(settings.apps)}
