# Library Entrance

A local application gateway for managing and accessing self-hosted services through a YAML configuration file.

## Getting Started

**Prerequisites:** [uv](https://docs.astral.sh/uv/), [just](https://github.com/casey/just/), Docker, Docker-compose

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
log_level: INFO
allowed_origins:
    - "*"
apps:
    - name: "My API"
      port: 3000
      description: "Backend API service"
      route: /custom

    - name: "Frontend"
      port: 8080
      description: "React development server"

    # Use host IP instead of hostname (for services requiring IP-based access)
    - name: "MiniDLNA"
      port: 8200
      use_host_ip: true
      description: "Media server requiring IP-based access"
```

### Configuration Options

Each app requires:

- `name` (required): Display name for the application
- `port` (required): Port number where the service is running (e.g., `8080`)
- `use_host_ip` (optional, default `false`): Use the host machine's IP address instead of hostname
- `description` (optional): Brief description of the service
- `route` (optional): Additional route path

### Environment Variables

All config values can be overwritten with environment variables starting with `ENTRANCE_`. The location of the config file can be set with `ENTRANCE_CONFIG_FILE`.
