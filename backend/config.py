import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.environ.get("NOMI_DATA_DIR", os.environ.get("JOURNAL_DATA_DIR", BASE_DIR / "data")))
DB_PATH = DATA_DIR / "journal.db"
AUDIO_DIR = DATA_DIR / "audio"
MEDIA_DIR = DATA_DIR / "media"
LOG_DIR = DATA_DIR / "logs"

HOST = os.environ.get("NOMI_HOST", "127.0.0.1")
PORT = int(os.environ.get("NOMI_PORT", "8000"))
APP_VERSION = os.environ.get("NOMI_APP_VERSION", "0.1.0")
API_TOKEN = os.environ.get("NOMI_API_TOKEN")

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
CHAT_MODEL = os.environ.get("CHAT_MODEL", "qwen2.5:3b")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")

LINK_SIM_THRESHOLD = float(os.environ.get("LINK_SIM_THRESHOLD", "0.35"))
REL_SIM_THRESHOLD = float(os.environ.get("REL_SIM_THRESHOLD", "0.20"))
FOLLOWUP_MIN_SIM = float(os.environ.get("FOLLOWUP_MIN_SIM", "0.45"))
RAG_TOP_K = int(os.environ.get("RAG_TOP_K", "6"))
GRAPH_MAX_ENTRIES = int(os.environ.get("GRAPH_MAX_ENTRIES", "300"))


def ensure_dirs():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
