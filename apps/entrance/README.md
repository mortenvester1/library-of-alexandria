# Library Entrance

A local application gateway for managing and accessing self-hosted services through a YAML configuration file.

## Getting Started

**Prerequisites:** [uv](https://docs.astral.sh/uv/), [just](https://github.com/casey/just/), Docker (optional)

1. Clone and install dependencies:

   ```bash
   uv sync --extra dev
   ```

2. Copy the example config and customize it:

   ```bash
   cp config.example.yaml config.yaml
   ```

3. Run locally:

   ```bash
   just dev
   ```

4. Or run with Docker:
   ```bash
   docker-compose up
   ```

Access the app at `http://localhost:8000`

## Configuration

Edit `config.yaml` to define your localhost applications:

```yaml
- name: "My API"
  port: 3000
  description: "Backend API service"

- name: "Frontend"
  port: 8080
  description: "React development server"
```

Each app requires a `name` and `port`. The `description` is optional.

## Settings

Configure the application using environment variables with the `ENTRANCE_` prefix:

- `ENTRANCE_LOG_LEVEL` - Logging level (default: `INFO`)
- `ENTRANCE_CONFIG_FILE` - Path to config file (default: `config.yaml`)
- `ENTRANCE_ALLOW_LOCALHOST_ANY_PORT` - Allow any port on localhost (default: `true`)
- `ENTRANCE_ALLOW_PRIVATE_NETWORK` - Allow private network ranges (default: `true`)

Create a `.env` file in the project root or set variables in your environment.
