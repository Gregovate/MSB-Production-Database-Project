from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
BACKEND = APP_DIR / "production_backend.py"


def source() -> str:
    return BACKEND.read_text(encoding="utf-8")


def test_setup_performance_trace_is_api_only_and_low_overhead() -> None:
    text = source()

    assert 'request.path.startswith("/api/setup/")' in text
    assert "@app.before_request" in text
    assert "@app.after_request" in text
    assert "@app.teardown_request" in text
    assert "time.perf_counter()" in text
    assert "threading.Lock()" in text
    assert "uuid.uuid4().hex[:12]" in text

    # Instrumentation itself must not query the database or create network work.
    trace = text[text.index("def _setup_perf_is_traced_request"):text.index("def _no_store")]
    assert "psycopg2" not in trace
    assert "requests." not in trace
    assert "urllib" not in trace
    assert "subprocess" not in trace


def test_setup_performance_trace_records_operator_and_request_shape_without_payloads() -> None:
    text = source()

    assert 'Cf-Access-Authenticated-User-Email' in text
    assert "operator=%s" in text
    assert "request.method" in text
    assert "request.url_rule.rule" in text
    assert "response.status_code" in text
    assert "response_bytes=%s" in text
    assert "os.getpid()" in text
    assert "threading.get_ident()" in text
    assert "active_in_worker=%s" in text

    # Do not persist request bodies, query strings, arbitrary headers, or SQL.
    trace = text[text.index("def _setup_perf_is_traced_request"):text.index("def _no_store")]
    for forbidden in (
        "request.get_data",
        "request.get_json",
        "request.form",
        "request.args",
        "request.query_string",
        "request.headers.items",
        "cursor(",
        "execute(",
    ):
        assert forbidden not in trace


def test_setup_performance_trace_exposes_browser_correlation_headers() -> None:
    text = source()

    assert 'response.headers["Server-Timing"]' in text
    assert 'app;dur=' in text
    assert 'response.headers["X-MSB-Request-ID"]' in text
    assert "SETUP_PERF" in text
    assert "_SETUP_PERF_SUMMARY_SECONDS = 60.0" in text
    assert "_SETUP_PERF_SLOW_MS = 250.0" in text


def test_setup_performance_trace_has_dedicated_info_logger() -> None:
    text = source()

    assert 'logging.getLogger("msb.setup.performance")' in text
    assert "_SETUP_PERF_LOGGER.setLevel(logging.INFO)" in text
    assert "_SETUP_PERF_LOGGER.propagate = False" in text
    assert "logging.StreamHandler()" in text
    assert "_SETUP_PERF_LOGGER.info(" in text


def test_setup_performance_trace_summarizes_fast_gets_and_keeps_exceptions() -> None:
    text = source()

    assert "def _setup_perf_record_summary(" in text
    assert "SETUP_PERF_SUMMARY" in text or '"_SUMMARY' in text
    assert 'event_kind = "ERROR"' in text
    assert 'event_kind = "WRITE"' in text
    assert 'event_kind = "SLOW"' in text
    assert 'request.method != "GET"' in text
    assert "elapsed_ms >= _SETUP_PERF_SLOW_MS" in text
    assert 'route_stats["count"] += 1' in text
    assert 'route_stats["total_ms"] += elapsed_ms' in text
    assert 'window["max_active"] = max(window["max_active"], active)' in text
    assert "response_bytes" in text
    assert "_SETUP_PERF_WINDOWS[operator] = _setup_perf_new_window(now)" in text


def test_setup_performance_trace_version_is_distinct() -> None:
    text = source()
    assert 'PRODUCTION_VERSION = "V0.3.17-performance-trace"' in text
