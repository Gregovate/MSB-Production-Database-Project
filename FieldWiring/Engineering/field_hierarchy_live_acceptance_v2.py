"""Run the durable live hierarchy acceptance probe against the final Stage gate."""
from __future__ import annotations

import sys
from pathlib import Path

APPLICATION = Path(__file__).resolve().parents[1] / "Application"
sys.path.insert(0, str(APPLICATION))

import field_hierarchy_live_acceptance as probe
from field_context_hierarchy import resolve_field_hierarchy

# Reuse the accepted diagnostic body while substituting the final canonical
# hierarchy entry point. This keeps the representative live assertions
# identical to the first diagnostic run.
probe.resolve_field_hierarchy = resolve_field_hierarchy

if __name__ == "__main__":
    raise SystemExit(probe.main())
