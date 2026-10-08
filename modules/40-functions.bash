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
unalias man mkcd extract up timer coolbash_log coolbash_error backup whoport serve cheat 2>/dev/null
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
coolbash_log() { printf '\e[32m%s\e[0m\n' "$*"; }
coolbash_error() { printf '\e[31m%s\e[0m\n' "$*" >&2; }

# FR: mkcd crée puis cd.
mkcd() { mkdir -p -- "$1" && { cd -- "$1" || return; }; }

# FR: extract [-d] <archive> — selon l'extension ; -d extrait dans un dossier
#     au nom de l'archive. Code 3 si l'outil nécessaire est absent.
extract() {
  local into=0 f abs dir
  local -a cmd
  [[ "${1:-}" == "-d" ]] && {
    into=1
    shift
  }
  f="${1:-}"
  [[ -f "$f" ]] || {
    echo "File not found: $f" >&2
    return 1
  }
  case "$f" in
    *.tar.bz2 | *.tbz2) cmd=(tar xjf) ;;
    *.tar.gz | *.tgz) cmd=(tar xzf) ;;
    *.tar.xz) cmd=(tar xJf) ;;
    *.tar.zst) cmd=(tar --zstd -xf) ;;
    *.tar) cmd=(tar xf) ;;
    *.zip) cmd=(unzip -q) ;;
    *.rar) cmd=(unrar x) ;;
    *.7z) cmd=(7z x) ;;
    # FR : fichier seul compressé — décompressé sur place, -d sans objet.
    *.gz)
      cmd=(gunzip)
      into=0
      ;;
    *.bz2)
      cmd=(bunzip2)
      into=0
      ;;
    *.xz)
      cmd=(unxz)
      into=0
      ;;
    *)
      echo "Unsupported archive format: $f" >&2
      return 2
      ;;
  esac
  command -v "${cmd[0]}" >/dev/null 2>&1 || {
    echo "extract: '${cmd[0]}' is required for $f" >&2
    return 3
  }
  if ((into)); then
    # FR : -d — dans un dossier au nom de l'archive (fini les archives qui
    #      s'étalent dans le dossier courant).
    abs="$(cd "$(dirname -- "$f")" && pwd)/${f##*/}"
    dir="${f##*/}"
    dir="${dir%.tar.*}"
    dir="${dir%.*}"
    mkdir -p -- "$dir" && (cd -- "$dir" && "${cmd[@]}" "$abs")
  else
    "${cmd[@]}" "$f"
  fi
}

# FR: up remonte de N répertoires (1 par défaut).
up() {
  local d="" limit="${1:-1}" i
  for ((i = 1; i <= limit; i++)); do d+="../"; done
  cd "$d" || return
}

# FR: Chronomètre l'exécution d'une commande.
timer() {
  local start end rc ms
  start="${EPOCHREALTIME//[.,]/}"
  "$@"
  rc=$?
  end="${EPOCHREALTIME//[.,]/}"
  ms=$(((end - start) / 1000))
  printf '⏱  %d.%03ds\n' $((ms / 1000)) $((ms % 1000))
  return "$rc"
}

# FR : backup <fichier|dossier>… — copie horodatée à côté : nom.AAAA-MM-JJ-HHMM.bak.
#      cp -a garde permissions et dates, et copie les dossiers ; `command cp`
#      parce que cp est aliasé en cp -i.
backup() {
  local f stamp dest rc=0
  (($#)) || {
    echo "usage : backup <fichier|dossier>…" >&2
    return 1
  }
  printf -v stamp '%(%Y-%m-%d-%H%M)T' -1
  for f in "$@"; do
    f="${f%/}"
    [[ -e "$f" ]] || {
      echo "backup : $f introuvable" >&2
      rc=1
      continue
    }
    dest="$f.$stamp.bak"
    if command cp -a -- "$f" "$dest"; then printf '%s → %s\n' "$f" "$dest"; else rc=1; fi
  done
  return "$rc"
}

# FR : whoport <port> — quel processus écoute sur ce port : ss (pid, nom, ligne
#      de commande via /proc), sinon lsof. Les processus des autres utilisateurs
#      ne montrent pas leur pid sans sudo.
whoport() {
  local port="${1:-}" proto local_addr users pid name cmd found=0
  [[ "$port" =~ ^[0-9]+$ ]] || {
    echo "usage : whoport <port>" >&2
    return 1
  }
  if command -v ss >/dev/null 2>&1; then
    while read -r proto _ _ _ local_addr _ users; do
      [[ "$local_addr" == *:"$port" ]] || continue
      found=1
      name=""
      pid=""
      # FR : users:(("node",pid=4242,fd=19))
      if [[ "$users" == *pid=* ]]; then
        name="${users#*\"}"
        name="${name%%\"*}"
        pid="${users#*pid=}"
        pid="${pid%%,*}"
      fi
      printf '%s/%-4s pid %-7s %s\n' "$port" "$proto" "${pid:-?}" "${name:-(autre utilisateur : sudo whoport)}"
      if [[ -n "$pid" && -r "/proc/$pid/cmdline" ]]; then
        cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)"
        [[ -n "$cmd" ]] && printf '         %s\n' "$cmd"
      fi
    done < <(ss -tulpnH 2>/dev/null)
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -i ":$port" 2>/dev/null | tail -n +2 | grep . && found=1
  else
    echo "whoport : ni ss ni lsof disponible" >&2
    return 1
  fi
  ((found)) || {
    echo "whoport : port $port libre"
    return 1
  }
}

# FR : _coolbash_free_port <départ> — premier port TCP libre à partir de <départ>,
#      testé en pur bash via /dev/tcp (une connexion qui réussit = port occupé).
_coolbash_free_port() {
  local p="${1:-8000}"
  while ((p < 65535)); do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
      printf '%s' "$p"
      return 0
    fi
    p=$((p + 1))
  done
  return 1
}

# FR : serve [dossier] [port] — serveur HTTP statique (python3, sinon php) sur
#      le premier port libre à partir de COOLBASH_SERVE_PORT (8000). URL affichée.
serve() {
  local dir="${1:-.}" port="${2:-}"
  [[ -d "$dir" ]] || {
    echo "serve : $dir n'est pas un dossier" >&2
    return 1
  }
  if [[ -z "$port" ]]; then
    port="$(_coolbash_free_port "${COOLBASH_SERVE_PORT:-8000}")" || {
      echo "serve : aucun port libre" >&2
      return 1
    }
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '\e[32m→ http://localhost:%s/\e[0m  (%s, python3, Ctrl-C pour arrêter)\n' "$port" "$dir"
    python3 -m http.server --directory "$dir" "$port"
  elif command -v php >/dev/null 2>&1; then
    printf '\e[32m→ http://localhost:%s/\e[0m  (%s, php, Ctrl-C pour arrêter)\n' "$port" "$dir"
    php -S "127.0.0.1:$port" -t "$dir"
  else
    echo "serve : ni python3 ni php disponible" >&2
    return 1
  fi
}

# FR : cheat <commande> — des exemples, vite : tldr si présent, sinon la section
#      EXAMPLES du man (extraite en pur bash, surlignages retirés), sinon --help.
#      Complétion : les commandes du PATH.
complete -c cheat
cheat() {
  local cmd="${1:-}" line in=0 found=0
  [[ -n "$cmd" ]] || {
    echo "usage : cheat <commande>" >&2
    return 1
  }
  if command -v tldr >/dev/null 2>&1; then
    tldr "$cmd"
    return
  fi
  if command -v man >/dev/null 2>&1; then
    while IFS= read -r line; do
      line="${line//?$'\b'/}"
      if [[ "$line" =~ ^[A-Z][A-Z[:space:]]*$ ]]; then
        if [[ "$line" == EXAMPLE* ]]; then
          in=1
          found=1
          continue
        fi
        in=0
      fi
      ((in)) && printf '%s\n' "$line"
    done < <(MANWIDTH="${COLUMNS:-100}" command man "$cmd" 2>/dev/null)
    ((found)) && return 0
  fi
  echo "cheat : pas de tldr ni de section EXAMPLES dans le man de $cmd — voici --help :" >&2
  "$cmd" --help 2>&1 | head -40
}
