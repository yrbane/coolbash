# shellcheck shell=bash
#  ██████  ██   ██  ███████  ██   ██   █████   ██   ██
#  ██   ██  ██ ██      █     ██   ██  ██   ██  ███  ██
#  ██████    ███       █     ███████  ██   ██  ██ ██ ██
#  ██         █        █     ██   ██  ██   ██  ██  ███
#  ██         █        █     ██   ██   █████   ██   ██   MODULE: PYTHON VENV
# ─────────────────────────────────────────────────────────────────────────────
# FR: Helpers venv portables (évite les chemins codés en dur).

# FR: Crée et active un venv (.venv par défaut ou chemin fourni).
# FR : un alias homonyme (ancienne version, ~/.bash_aliases) serait développé à la
#      lecture de « nom() { » → erreur de syntaxe au rechargement du .bashrc.
unalias mkvenv workon 2>/dev/null
mkvenv() {
  local target="${1:-.venv}"
  python3 -m venv "$target" && . "$target/bin/activate"
}

# FR: Active .venv dans le dossier courant si présent.
workon() {
  if [[ -d ".venv" ]]; then
    # shellcheck disable=SC1091
    . ".venv/bin/activate"
  else
    echo "No .venv found in current directory."
  fi
}
