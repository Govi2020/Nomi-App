"""Programmatic backend launcher shared by development and Nuitka builds."""

import argparse
import ipaddress
import logging
import os
import sys
import threading
from logging.handlers import RotatingFileHandler
from pathlib import Path

# Support both `python backend/entry.py` and `python -m backend.entry`.
if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend import config
from backend.server import app


def _is_loopback(host: str) -> bool:
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def _watch_stdin(server):
    try:
        for line in sys.stdin:
            if line.strip() == "SHUTDOWN":
                server.should_exit = True
                return
    except (OSError, ValueError):
        pass
    server.should_exit = True


def _configure_logging():
    config.ensure_dirs()
    handler = RotatingFileHandler(
        config.LOG_DIR / "backend-stdio.log",
        maxBytes=2_000_000,
        backupCount=3,
        encoding="utf-8",
    )
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        handlers=[handler],
        force=True,
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description="Nomi local backend")
    parser.add_argument("--host", default=config.HOST)
    parser.add_argument("--port", type=int, default=config.PORT)
    parser.add_argument("--mcp-server", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.mcp_server:
        from backend.mcp_server import run_stdio

        run_stdio()
        return 0

    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    if not _is_loopback(args.host) and os.environ.get("NOMI_ALLOW_NON_LOOPBACK") != "1":
        parser.error("Nomi binds to loopback only; set NOMI_ALLOW_NON_LOOPBACK=1 to override")

    # Nuitka's compiled modules share this marker with the MCP client so MCP
    # can re-enter this executable in stdio-server mode instead of Python.
    if getattr(sys, "frozen", False) or "__compiled__" in globals():
        os.environ["NOMI_MCP_SELF_SPAWN"] = "1"

    _configure_logging()
    import uvicorn

    server = uvicorn.Server(
        uvicorn.Config(
            app,
            host=args.host,
            port=args.port,
            access_log=False,
            log_config=None,
        )
    )
    watchdog = threading.Thread(target=_watch_stdin, args=(server,), daemon=True, name="stdin-shutdown")
    watchdog.start()
    server.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
