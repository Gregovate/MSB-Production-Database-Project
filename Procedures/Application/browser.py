"""MSB Procedure browser host layered over the accepted read-only API."""
from __future__ import annotations

import os
from pathlib import Path

from flask import Response, send_file

from Procedures.Application.backend import app

BASE_DIR = Path(__file__).resolve().parent


@app.get("/")
def index() -> Response:
    return send_file(BASE_DIR / "index.html")


@app.get("/procedure.css")
def procedure_css() -> Response:
    return send_file(BASE_DIR / "procedure.css", mimetype="text/css")


@app.get("/procedure.js")
def procedure_js() -> Response:
    return send_file(BASE_DIR / "procedure.js", mimetype="application/javascript")


@app.get("/static/analytics.js")
def analytics_js() -> Response:
    return send_file(BASE_DIR / "static" / "analytics.js", mimetype="application/javascript")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8792")), debug=False)
