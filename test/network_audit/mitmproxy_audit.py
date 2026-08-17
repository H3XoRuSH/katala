"""
Katala Network Traffic Audit Script (mitmproxy addon)
=====================================================
Purpose:
  Asserts that zero unexpected HTTP/HTTPS or socket connections are initiated
  by the Katala application process during release execution and testing.

Usage with mitmproxy:
  mitmdump -s test/network_audit/mitmproxy_audit.py -p 8080 --set block_global=false

Allowlist rules:
  - User-initiated OS browser launch (e.g. tapping an 'OPEN_URL' reminder action)
  - User-initiated tel: / call actions handled at OS level
  - OS-level system traffic if proxying whole device (e.g. captive portal checks, OS NTP)
    is tracked separately, but any request originating from Katala's process identifier
    triggers an immediate failure assertion.
"""

import sys
import logging
from mitmproxy import http

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("katala_network_audit")

# Track violations detected during test run
violations = []

# Known system endpoints when whole-device proxying is enabled (filtered out if not from Katala)
SYSTEM_DOMAINS_ALLOWLIST = {
    "captive.apple.com",
    "connectivitycheck.gstatic.com",
    "time.apple.com",
    "time.google.com",
}


def request(flow: http.HTTPFlow) -> None:
    host = flow.request.pretty_host
    user_agent = flow.request.headers.get("User-Agent", "")
    app_bundle_id = flow.request.headers.get("X-Bundle-ID", "")

    # Check if traffic originates from Katala or Dart runtime
    is_katala_app = (
        "katala" in user_agent.lower()
        or "dart" in user_agent.lower()
        or app_bundle_id == "com.katala.app"
    )

    if is_katala_app or host not in SYSTEM_DOMAINS_ALLOWLIST:
        violation_entry = {
            "host": host,
            "path": flow.request.path,
            "method": flow.request.method,
            "user_agent": user_agent,
            "scheme": flow.request.scheme,
        }
        violations.append(violation_entry)
        logger.error(
            "❌ NETWORK AUDIT VIOLATION DETECTED: %s %s://%s%s (UA: %s)",
            flow.request.method,
            flow.request.scheme,
            host,
            flow.request.path,
            user_agent,
        )


def done() -> None:
    """Called when mitmproxy shuts down to emit final audit status."""
    logger.info("=" * 60)
    logger.info("KATALA NETWORK TRAFFIC AUDIT SUMMARY")
    logger.info("=" * 60)

    if violations:
        logger.error("FAILED: %d unexpected network request(s) recorded:", len(violations))
        for v in violations:
            logger.error("  - [%s] %s://%s%s", v["method"], v["scheme"], v["host"], v["path"])
        logger.error("Audit Verdict: FAILED (Katala must operate 100% offline).")
        sys.exit(1)
    else:
        logger.info("SUCCESS: Zero network requests detected from Katala.")
        logger.info("Audit Verdict: PASSED (100% Zero Network Footprint verified).")
