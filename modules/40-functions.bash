# shellcheck shell=bash
#  ██████  ██   ██  ██   ██   █████  ███████  █████   █████   ██   ██   █████
#  ██      ██   ██  ███  ██  ██        █    ██   ██  ██   ██  ███  ██  ██
#  █████   ██   ██  ██ ██ ██  ██        █    ██   ██  ██   ██  ██ ██ ██  █████
#  ██      ██   ██  ██  ███  ██        █    ██   ██  ██   ██  ██  ███      ██
#  ██       █████   ██   ██   █████    █     █████   █████   ██   ██  █████   MODULE: FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# FR: man pages colorisées (via variables LESS_TERMCAP)
# FR : un alias homonyme (ancienne version, ~/.bash_aliases) serait développé à la
#      lecture de « nom() { » → erreur de syntaxe au rechargement du .bashrc.
unalias man mkcd extract up timer coolbash_log coolbash_error 2>/dev/null
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

# FR: Logs colorés simples (API publique). `log`/`error` masquaient des commandes
#     génériques ; renommés en 0.4.0.
coolbash_log()   { printf '\e[32m%s\e[0m\n' "$*"; }
coolbash_error() { printf '\e[31m%s\e[0m\n' "$*" >&2; }

# FR: mkcd crée puis cd.
mkcd () { mkdir -p -- "$1" && { cd -- "$1" || return; }; }

# FR: extract [-d] <archive> — selon l'extension ; -d extrait dans un dossier
#     au nom de l'archive. Code 3 si l'outil nécessaire est absent.
extract () {
  local into=0 f abs dir
  local -a cmd
  [[ "${1:-}" == "-d" ]] && { into=1; shift; }
  f="${1:-}"
  [[ -f "$f" ]] || { echo "File not found: $f" >&2; return 1; }
  case "$f" in
    *.tar.bz2|*.tbz2) cmd=(tar xjf) ;;
    *.tar.gz|*.tgz)   cmd=(tar xzf) ;;
    *.tar.xz)         cmd=(tar xJf) ;;
    *.tar.zst)        cmd=(tar --zstd -xf) ;;
    *.tar)            cmd=(tar xf) ;;
    *.zip)            cmd=(unzip -q) ;;
    *.rar)            cmd=(unrar x) ;;
    *.7z)             cmd=(7z x) ;;
    # FR : fichier seul compressé — décompressé sur place, -d sans objet.
    *.gz)             cmd=(gunzip);  into=0 ;;
    *.bz2)            cmd=(bunzip2); into=0 ;;
    *.xz)             cmd=(unxz);    into=0 ;;
    *) echo "Unsupported archive format: $f" >&2; return 2 ;;
  esac
  command -v "${cmd[0]}" >/dev/null 2>&1 || { echo "extract: '${cmd[0]}' is required for $f" >&2; return 3; }
  if (( into )); then
    # FR : -d — dans un dossier au nom de l'archive (fini les archives qui
    #      s'étalent dans le dossier courant).
    abs="$(cd "$(dirname -- "$f")" && pwd)/${f##*/}"
    dir="${f##*/}"; dir="${dir%.tar.*}"; dir="${dir%.*}"
    mkdir -p -- "$dir" && ( cd -- "$dir" && "${cmd[@]}" "$abs" )
  else
    "${cmd[@]}" "$f"
  fi
}

# FR: up remonte de N répertoires (1 par défaut).
up () {
  local d="" limit="${1:-1}" i
  for ((i=1; i<=limit; i++)); do d+="../"; done
  cd "$d" || return
}

# FR: Chronomètre l'exécution d'une commande.
timer () {
  local start end rc ms
  start="${EPOCHREALTIME//[.,]/}"
  "$@"; rc=$?
  end="${EPOCHREALTIME//[.,]/}"
  ms=$(( (end - start) / 1000 ))
  printf '⏱  %d.%03ds\n' $(( ms / 1000 )) $(( ms % 1000 ))
  return "$rc"
}
