from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = ROOT / "build" / "backend"
BINARIES_DIR = ROOT / "src-tauri" / "binaries"


def run(args: list[str], *, cwd: Path = ROOT) -> None:
    subprocess.run(args, cwd=cwd, check=True)


def main() -> int:
    rustc = shutil.which("rustc")
    if not rustc:
        raise RuntimeError("Install Rust using rustup first; rustc is needed to derive the Tauri target triple.")
    details = subprocess.check_output([rustc, "-vV"], text=True)
    triple = next((line.removeprefix("host: ") for line in details.splitlines() if line.startswith("host: ")), "")
    if not triple:
        raise RuntimeError("Could not get the target triple from rustc -vV.")

    build_venv = ROOT / ".venv-build"
    interpreter = build_venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not interpreter.exists():
        run([sys.executable, "-m", "venv", str(build_venv)])
    run([str(interpreter), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(ROOT / "requirements.lock.txt")])

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    BINARIES_DIR.mkdir(parents=True, exist_ok=True)
    run([
        str(interpreter), "-m", "nuitka", "--mode=onefile",
        "--onefile-tempdir-spec={CACHE_DIR}/Nomi/{VERSION}",
        "--product-version=0.1.0", "--follow-imports", "--assume-yes-for-downloads",
        f"--jobs={os.cpu_count() or 2}", f"--output-dir={BUILD_DIR}",
        "--output-filename=nomi-backend", str(ROOT / "backend" / "entry.py"),
    ])

    suffix = ".exe" if platform.system() == "Windows" else ""
    source = BUILD_DIR / f"nomi-backend{suffix}"
    destination = BINARIES_DIR / f"nomi-backend-{triple}{suffix}"
    if not source.is_file():
        raise RuntimeError(f"Nuitka did not create the expected binary: {source}")
    shutil.copy2(source, destination)
    if os.name != "nt":
        destination.chmod(0o755)
    digest = __import__("hashlib").sha256(destination.read_bytes()).hexdigest()
    print(f"Sidecar: {destination}\nSHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
