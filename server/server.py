"""
HealthExport Webhook Receiver
=============================
Lightweight HTTP server to receive health data from the HealthExport iOS app.

Usage:
    python server.py                          # Default: 0.0.0.0:8080
    python server.py --port 9090              # Custom port
    python server.py --forward-url https://... # Forward to another service

API:
    POST /webhook   - Receive health data payload
    GET  /health    - Health check
    GET  /data      - List stored data dates
"""

import argparse
import json
import os
import logging
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DATA_DIR = Path(__file__).parent / "data"
FORWARD_URL = os.environ.get("HEALTH_FORWARD_URL", "")
FORWARD_TIMEOUT = 30  # seconds

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("healthexport")


# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

def save_payload(payload: dict) -> Path:
    """Save payload to data/{date}/{timestamp}.json"""
    date_str = payload.get("data", {}).get("date")
    if not date_str:
        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    date_dir = DATA_DIR / date_str
    date_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now(timezone.utc).strftime("%H-%M-%S")
    filepath = date_dir / f"{ts}.json"

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False, sort_keys=True)

    return filepath


def list_stored_dates() -> list[dict]:
    """List all dates with file counts."""
    if not DATA_DIR.exists():
        return []
    results = []
    for d in sorted(DATA_DIR.iterdir(), reverse=True):
        if d.is_dir():
            count = len(list(d.glob("*.json")))
            if count > 0:
                results.append({"date": d.name, "files": count})
    return results


# ---------------------------------------------------------------------------
# Forwarding
# ---------------------------------------------------------------------------

def forward_payload(payload: dict, url: str) -> bool:
    """Forward payload to another service via POST."""
    try:
        data = json.dumps(payload).encode("utf-8")
        req = Request(url, data=data, headers={"Content-Type": "application/json"})
        with urlopen(req, timeout=FORWARD_TIMEOUT) as resp:
            log.info("Forwarded to %s (status %d)", url, resp.status)
            return True
    except (URLError, OSError) as e:
        log.error("Forward failed: %s", e)
        return False


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------

class HealthHandler(BaseHTTPRequestHandler):
    """Handles /webhook, /health, /data endpoints."""

    def do_GET(self):
        if self.path == "/health":
            self._json_response(200, {"status": "ok", "time": datetime.now(timezone.utc).isoformat()})
        elif self.path == "/data":
            self._json_response(200, list_stored_dates())
        else:
            self._json_response(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/webhook":
            self._json_response(404, {"error": "not found"})
            return

        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            self._json_response(400, {"error": "empty body"})
            return

        try:
            raw = self.rfile.read(content_length)
            payload = json.loads(raw)
        except (json.JSONDecodeError, ValueError) as e:
            self._json_response(400, {"error": f"invalid json: {e}"})
            return

        # Validate minimal structure
        if "data" not in payload:
            self._json_response(400, {"error": "missing 'data' field"})
            return

        device_id = payload.get("device_id", "unknown")
        date_str = payload["data"].get("date", "unknown")
        log.info("Received data from device=%s date=%s size=%d bytes", device_id, date_str, len(raw))

        # Save to file
        filepath = save_payload(payload)
        log.info("Saved to %s", filepath)

        # Forward if configured
        if FORWARD_URL:
            forward_payload(payload, FORWARD_URL)

        self._json_response(200, {"status": "ok", "file": filepath.name})

    def _json_response(self, status: int, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(body, ensure_ascii=False).encode("utf-8"))

    def log_message(self, fmt, *args):
        """Override to use our logger."""
        log.debug(fmt, *args)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="HealthExport Webhook Receiver")
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080, help="Port (default: 8080)")
    parser.add_argument("--forward-url", default="", help="Forward received payloads to this URL")
    args = parser.parse_args()

    global FORWARD_URL
    if args.forward_url:
        FORWARD_URL = args.forward_url

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    server = HTTPServer((args.host, args.port), HealthHandler)
    log.info("HealthExport receiver listening on %s:%d", args.host, args.port)
    if FORWARD_URL:
        log.info("Forwarding enabled → %s", FORWARD_URL)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down...")
        server.server_close()


if __name__ == "__main__":
    main()
