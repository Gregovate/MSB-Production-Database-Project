"""MSB Setup Session production application host.

This wraps the validated prototype UI/Procedure routes with the database-backed,
Cloudflare/Directus-governed Setup API. The prototype backend remains available
for local UI validation while this file is the intended protected deployment
entry point after schema approval.
"""
from __future__ import annotations

import os

from backend import app
from setup_api import setup_api

app.register_blueprint(setup_api)

if __name__ == "__main__":
    app.run(
        host=os.environ.get("SETUP_BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8780")),
        debug=False,
    )
