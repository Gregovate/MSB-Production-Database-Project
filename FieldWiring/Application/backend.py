"""MSB FieldWiring browser API and static application host — V0.1.0."""

from __future__ import annotations

import os
from pathlib import Path

from flask import Flask, Response, jsonify, request, send_from_directory

from repository import ConfigError, PostgresRepository, Repository, SQLiteSnapshotRepository

APP_VERSION = "V0.1.0"
BASE_DIR = Path(__file__).resolve().parent
app = Flask(__name__)


def repository() -> Repository:
    dev_snapshot = os.environ.get("FIELDWIRING_DEV_SNAPSHOT", "").strip()
    if dev_snapshot:
        return SQLiteSnapshotRepository(dev_snapshot)
    dsn = os.environ.get("FIELDWIRING_DATABASE_DSN", "").strip()
    if dsn:
        return PostgresRepository(dsn)
    raise ConfigError(
        "Configure FIELDWIRING_DATABASE_DSN for PostgreSQL or "
        "FIELDWIRING_DEV_SNAPSHOT for explicit read-only development mode"
    )


@app.get("/")
def index() -> Response:
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/fieldwiring.css")
def css() -> Response:
    return send_from_directory(BASE_DIR, "fieldwiring.css")


@app.get("/fieldwiring.js")
def js() -> Response:
    return send_from_directory(BASE_DIR, "fieldwiring.js")


@app.get("/api/health")
def health() -> Response:
    mode = "sqlite-dev" if os.environ.get("FIELDWIRING_DEV_SNAPSHOT") else "postgres"
    return jsonify(status="ok", version=APP_VERSION, data_mode=mode)


@app.get("/api/displays")
def api_displays() -> Response:
    query = request.args.get("q", "")
    return jsonify(displays=repository().search_displays(query))


@app.get("/api/displays/<int:display_id>/context")
def api_display_context(display_id: int) -> Response:
    context = repository().display_context(display_id)
    if context is None:
        return jsonify(error="Display is not available for FieldWiring"), 404
    return jsonify(context=context)


@app.get("/api/stages")
def api_stages() -> Response:
    return jsonify(stages=repository().stages())


@app.errorhandler(ConfigError)
def config_error(exc: ConfigError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), 503


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8790")), debug=False)
