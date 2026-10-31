"""#205 / PR414 source-only release profile. Reuses the proven #305 Setup deployment engine."""
import subprocess
import setup_305_source_only_deploy as engine

# Application source includes approved PR414 and October 17 cache/date refresh.
engine.TARGET = 'ec6d3f0e6a6a1cd69dd60256dcb7f76699e07910'
engine.EXPECTED_OLD = '7740498e6602f36c8cdfd384791bbafaab71ee9e'
engine.OLD_VERSION = 'V0.3.84-direct-crew-cells'
engine.VERSION = 'V0.3.84-direct-crew-cells'

# Shared FieldWiring/Controller checkout is intentionally NOT promoted.
# Capture its read-only live identity for the engine's before/after drift gates.
engine.SHARED = subprocess.check_output(
    ['sudo','env','GIT_TERMINAL_PROMPT=0','git','-C','/opt/fieldwiring','rev-parse','HEAD'],
    text=True,
).strip()

# Preserve existing focused and full Setup tests in the proven engine.
if __name__ == '__main__':
    raise SystemExit(engine.main())
