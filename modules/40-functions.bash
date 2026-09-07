# shellcheck shell=bash
#  ██████  ██   ██  ██   ██   █████  ███████  █████   █████   ██   ██   █████
#  ██      ██   ██  ███  ██  ██        █    ██   ██  ██   ██  ███  ██  ██
#  █████   ██   ██  ██ ██ ██  ██        █    ██   ██  ██   ██  ██ ██ ██  █████
#  ██      ██   ██  ██  ███  ██        █    ██   ██  ██   ██  ██  ███      ██
#  ██       █████   ██   ██   █████    █     █████   █████   ██   ██  █████   MODULE: FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# FR: man pages colorisées (via variables LESS_TERMCAP)
man() {
  env \
  LESS_TERMCAP_mb=$'\E[01;31m' \
  LESS_TERMCAP_md=$'\E[01;31m' \
  LESS_TERMCAP_me=$'\E[0m' \
  LESS_TERMCAP_se=$'\E[0m' \
  LESS_TERMCAP_so=$'\E[01;31m' \
  LESS_TERMCAP_ue=$'\E[0m' \
  LESS_TERMCAP_us=$'\E[01;32m' \
  man "$@"
}

# FR: Logs colorés simples.
log()   { printf "\e[32m%s\e[0m\n" "$1"; }
error() { printf "\e[31m%s\e[0m\n" "$1" >&2; }

# FR: mkcd crée puis cd.
mkcd () { mkdir -p -- "$1" && cd -- "$1"; }

# FR: extract selon l'extension.
extract () {
  local f="$1"
  [[ -f "$f" ]] || { echo "File not found: $f"; return 1; }
  case "$f" in
    *.tar.bz2)   tar xjf "$f"   ;;
    *.tar.gz)    tar xzf "$f"   ;;
    *.tar.xz)    tar xJf "$f"   ;;
    *.tar.zst)   tar --zstd -xvf "$f" ;;
    *.tar)       tar xf "$f"    ;;
    *.tbz2)      tar xjf "$f"   ;;
    *.tgz)       tar xzf "$f"   ;;
    *.zip)       unzip "$f"     ;;
    *.rar)       unrar x "$f"   ;;
    *.7z)        7z x "$f"      ;;
    *.gz)        gunzip "$f"    ;;
    *.bz2)       bunzip2 "$f"   ;;
    *.xz)        unxz "$f"      ;;
    *)           echo "Unsupported archive format: $f" ; return 2 ;;
  esac
}

# FR: up remonte de N répertoires (1 par défaut).
up () {
  local d="" limit="${1:-1}"
  for ((i=1; i<=limit; i++)); do d+="../"; done
  cd "$d" || return
}

# FR: Chronomètre l'exécution d'une commande.
timer () {
  local start end
  start=$(date +%s)
  "$@"
  end=$(date +%s)
  echo "⏱  $(( end - start ))s"
}
