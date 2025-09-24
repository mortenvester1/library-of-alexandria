# Jetson

## Getting Started

1. Install asdf and install dependencies with `asdf install`

1. Create `.envrc` to override defaults in code

```sh
export JETSON_UI_PORT=XXXX
```

1. Configure applications in `.env.yaml`

```yaml
apps:
    - name: app-name
      port: 8000
      url_postfix: web/ui
```

1. Run with `uv run uvicorn jetson.app:app --reload --port $JETSON_UI_PORT --host 0.0.0.0`
