# Overview
This project aims to create a local network gateway website that serves as a single entry point to access various locally hosted applications. The site will run on a designated port and dynamically discover applications from a YAML configuration file, providing links or embeds to each application running on the device. The backend will be implemented in Python 3.13, with configuration centralized in `pyproject.toml`. The UI and API layers will be built using FastAPI, and the entire application will be containerized with Docker and orchestrated via `docker-compose`.

# Core Features
- **Dynamic Application Discovery**: Read a YAML config file to list available apps and their ports.
- **Unified Entry Page**: Single page application (SPA) served by FastAPI that displays discovered apps with clickable links.
- **Secure Local Routing**: Ensure all routing stays within the local network, no external exposure.
- **Responsive UI**: Simple, intuitive UI for Users to select apps.
- **Configurable Port Mapping**: Users can edit the YAML to add/remove apps.

# User Experience
- **User Personas**: 
  - *Developer*: Needs quick access to multiple local services.
  - *Visitor*: Accesses a curated list of local apps via a simple URL.
- **Key Flows**:
  1. Start the gateway service.
  2. Read `config.yaml` to generate app list.
  3. Render UI with clickable tiles/links.
  4. Navigate to selected app (opens in same tab or new tab).
- **UI Considerations**: Use responsive design, minimal dependencies, accessible navigation.

# Technical Architecture
- **System Components**:
  - Backend Service: Python 3.13 + FastAPI hosting UI and API.
  - Config Parser (YAML) – reads `config.yaml`.
  - UI Renderer – FastAPI Jinja2 templates or static assets.
- **Data Models**:
  - `App` object with `name`, `url`, `port`, `description`.
- **APIs**:
  - `GET /` returns the main UI page.
  - `GET /apps` returns JSON list of discovered apps.
  - `GET /health` health check.
- **Infrastructure**:
  - Runs inside a Docker container built with a multi‑stage Dockerfile.
  - `docker-compose.yml` defines the service and any supporting services.
  - Configuration for Python tooling (e.g., `pyproject.toml`) manages dependencies, linting, and formatting.
- **Testing**:
  - Unit tests written with `pytest` to verify config parsing, routing, and health endpoints.

# Development Roadmap
- **MVP**:
  - Scaffold FastAPI project with Python 3.13.
  - Implement YAML config loader.
  - Build UI page that lists apps.
  - Add health check endpoint.
  - Create `pyproject.toml` with ruff configuration and pytest entry points.
- **Docker Integration**:
  - Write Dockerfile for building the FastAPI container.
  - Write `docker-compose.yml` to run the container and optionally other dependent services.
  - Test end‑to‑end deployment locally.
- **Future Enhancements**:
  - Support deep linking.
  - Add authentication/authorization.
  - Provide API for external integration.
  - Implement automated CI/CD pipelines with linting (`ruff`) and testing (`pytest`).

# Logical Dependency Chain
1. Define YAML config schema.
2. Implement config loader in Python.
3. Develop FastAPI routes for UI and API.
4. Set up `pyproject.toml` with ruff and pytest configurations.
5. Create Dockerfile and docker‑compose.yml.
6. Build, test, and refine the containerized service.
7. Refine UI/UX based on feedback.

# Risks and Mitigations
- **Technical Challenge**: Port conflicts – mitigated by allowing configurable ports in both FastAPI and compose.
- **MVP Scope**: Limited UI – mitigated by using simple Jinja2 templates for MVP.
- **Resource Constraints** – mitigated by using lightweight Python packages and Docker for consistent environments.

# Appendix
- **Research**: Exploration of local network service discovery methods and FastAPI best practices.
- **Technical Specs**: 
  - Language: Python 3.13.
  - Backend: FastAPI, Uvicorn server.
  - Frontend: Jinja2 templates / static HTML/JS.
  - Container: Docker (multi‑stage build).
  - Build/Lint/Test: `pyproject.toml` (ruff), `pytest`.