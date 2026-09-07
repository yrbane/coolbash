# shellcheck shell=bash
#  ██████  ██   ██  ███████  ██   ██   █████   ██   ██
#  ██   ██  ██ ██      █     ██   ██  ██   ██  ███  ██
#  ██████    ███       █     ███████  ██   ██  ██ ██ ██
#  ██         █        █     ██   ██  ██   ██  ██  ███
#  ██         █        █     ██   ██   █████   ██   ██   MODULE: PYTHON VENV
# ─────────────────────────────────────────────────────────────────────────────
# FR: Helpers venv portables (évite les chemins codés en dur).

# FR: Crée et active un venv (.venv par défaut ou chemin fourni).
mkvenv() {
  local target="${1:-.venv}"
  python3 -m venv "$target" && . "$target/bin/activate"
}

# FR: Active .venv dans le dossier courant si présent.
workon() {
  [[ -d ".venv" ]] && . ".venv/bin/activate" || echo "No .venv found in current directory."
}
