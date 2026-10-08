# shellcheck shell=bash
#  ██     ██  ██████  ██████  ██   ██
#  ██     ██ ██    ██ ██   ██ ██  ██
#  ██  █  ██ ██    ██ ██████  █████
#  ██ ███ ██ ██    ██ ██   ██ ██  ██
#   ███ ███   ██████  ██   ██ ██   ██   MODULE: WORKSPACE
# ─────────────────────────────────────────────────────────────────────────────
# FR: Le poste de travail :
#     - hooks de dossier : un fichier .coolbash.bash à la racine d'un projet est
#       sourcé à l'entrée et défait à la sortie — après un `coolbash allow`
#       explicite (empreinte du fichier ; modifié = à réautoriser),
#     - todo : liste de tâches (~/.coolbash/todo.txt), reprise dans le MOTD,
#     - remind 15m "…" : notification bureau après un délai, en tâche de fond,
#     - retry N cmd… : relance jusqu'au succès, délai croissant,
#     - copy / paste / copypath : presse-papiers (wl-copy, xclip, xsel, pbcopy,
#       OSC 52 en SSH ou sans outil).
#     Réglages : COOLBASH_HOOKS=0.

_coolbash_safe && return 0

unalias todo remind retry copy paste copypath 2>/dev/null

# --- hooks de dossier ---------------------------------------------------------------
# FR : ~/.coolbash/allowed : « chemin<TAB>empreinte » (cksum, une seule fois à
#      l'autorisation et à l'entrée dans le projet — jamais à chaque prompt).
COOLBASH_HOOK_ACTIVE=""
COOLBASH_HOOK_WARNED=""

_coolbash_hook_find() { # $1 = variable de sortie (chemin du .coolbash.bash, ou vide)
  local d="$PWD"
  while [[ -n "$d" ]]; do
    if [[ -f "$d/.coolbash.bash" ]]; then
      printf -v "$1" '%s' "$d/.coolbash.bash"
      return 0
    fi
    d="${d%/*}"
  done
  printf -v "$1" ''
  return 1
}

_coolbash_hook_fingerprint() { # $1 = fichier → stdout
  cksum <"$1" 2>/dev/null | cut -d' ' -f1-2
}

_coolbash_hook_allowed() { # $1 = fichier
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/allowed" path fp want
  [[ -r "$file" ]] || return 1
  want="$(_coolbash_hook_fingerprint "$1")"
  while IFS=$'\t' read -r path fp; do
    [[ "$path" == "$1" && "$fp" == "$want" ]] && return 0
  done <"$file"
  return 1
}

_coolbash_hook_unload() {
  [[ -n "$COOLBASH_HOOK_ACTIVE" ]] || return 0
  if declare -F coolbash_hook_unload >/dev/null 2>&1; then
    coolbash_hook_unload
    unset -f coolbash_hook_unload
  fi
  COOLBASH_HOOK_ACTIVE=""
}

# FR : à chaque prompt — coût : un [[ -f ]] par niveau de dossier.
_coolbash_hook_check() {
  [[ "${COOLBASH_HOOKS:-1}" == 0 ]] && return 0
  local hook
  _coolbash_hook_find hook
  [[ "$hook" == "$COOLBASH_HOOK_ACTIVE" ]] && return 0
  _coolbash_hook_unload
  [[ -n "$hook" ]] || return 0
  if _coolbash_hook_allowed "$hook"; then
    # shellcheck disable=SC1090
    source "$hook" && COOLBASH_HOOK_ACTIVE="$hook"
  elif [[ "$COOLBASH_HOOK_WARNED" != *"|$hook|"* ]]; then
    COOLBASH_HOOK_WARNED+="|$hook|"
    _coolbash_say '\e[33m⚑ %s trouvé mais non autorisé\e[0m — lis-le, puis : coolbash allow\n' "${hook/#$HOME/\~}" >&2
  fi
  return 0
}
_coolbash_prompt_command_add _coolbash_hook_check

# --- todo -----------------------------------------------------------------------------
# FR : todo | todo add "…" | todo done N | todo rm N — fichier ~/.coolbash/todo.txt,
#      une tâche par ligne ; « done » la retire (et l'archive dans todo.done).
todo() {
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/todo.txt" n i
  local -a lines=()
  case "${1:-}" in
    add | a)
      shift
      [[ -n "$*" ]] || {
        _coolbash_say 'usage : todo add "texte"\n' >&2
        return 1
      }
      mkdir -p "${file%/*}" && printf '%s\n' "$*" >>"$file" || return 1
      ;;
    done | d | rm)
      n="${2:-}"
      [[ "$n" =~ ^[0-9]+$ && "$n" -ge 1 ]] || {
        _coolbash_say 'usage : todo %s <numéro>\n' "$1" >&2
        return 1
      }
      [[ -r "$file" ]] && mapfile -t lines <"$file"
      ((n <= ${#lines[@]})) || {
        _coolbash_say 'todo : pas de tâche n° %s\n' "$n" >&2
        return 1
      }
      [[ "$1" != rm ]] && printf '%s\t%s\n' "$(printf '%(%Y-%m-%d)T' -1)" "${lines[n - 1]}" >>"${file%.txt}.done"
      unset 'lines[n-1]'
      if ((${#lines[@]})); then printf '%s\n' "${lines[@]}" >|"$file"; else rm -f "$file"; fi
      ;;
    "" | list | ls) ;;
    *)
      _coolbash_say 'usage : todo [add "texte" | done N | rm N]\n' >&2
      return 1
      ;;
  esac
  [[ -r "$file" ]] && mapfile -t lines <"$file"
  ((${#lines[@]})) || {
    _coolbash_say 'todo : rien à faire ✔\n'
    return 0
  }
  for i in "${!lines[@]}"; do printf '  \e[1m%2d\e[0m  %s\n' "$((i + 1))" "${lines[i]}"; done
}

# FR : complétion : les sous-commandes, puis les numéros des tâches pour done / rm.
_coolbash_todo_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" file="${COOLBASH_PREFIX:-$HOME/.coolbash}/todo.txt" n i line
  COMPREPLY=()
  if ((COMP_CWORD == 1)); then
    mapfile -t COMPREPLY < <(compgen -W "add done rm list" -- "$cur")
  elif ((COMP_CWORD == 2)) && [[ "${COMP_WORDS[1]}" == @(done|rm|d) && -r "$file" ]]; then
    # FR : pas `read -r _` : bash réécrit $_ après chaque commande (boucle sans fin).
    n=0
    while IFS= read -r line || [[ -n "$line" ]]; do n=$((n + 1)); done <"$file"
    for ((i = 1; i <= n; i++)); do [[ "$i" == "$cur"* ]] && COMPREPLY+=("$i"); done
  fi
}
complete -F _coolbash_todo_complete todo

# --- remind ----------------------------------------------------------------------------
# FR : remind <délai> <texte> — 30s, 15m, 2h, ou des secondes. Détaché (double
#      fork). À l'échéance : notify-send s'il existe, et de toute façon la ligne
#      sur le terminal d'origine (sonnerie + OSC 777 pour les terminaux qui savent).
remind() {
  local spec="${1:-}" secs text tty
  shift
  text="${*:-Rappel}"
  case "$spec" in
    *s) secs="${spec%s}" ;;
    *m) secs=$((${spec%m} * 60)) ;;
    *h) secs=$((${spec%h} * 3600)) ;;
    *) secs="$spec" ;;
  esac
  [[ "$secs" =~ ^[0-9]+$ ]] || {
    _coolbash_say 'usage : remind <30s|15m|2h> "texte"\n' >&2
    return 1
  }
  tty="$(tty 2>/dev/null)" || tty=""
  (
    (
      sleep "$secs"
      command -v notify-send >/dev/null 2>&1 && notify-send "⏰ $(_coolbash_t 'Rappel')" "$text" 2>/dev/null
      [[ -w "$tty" ]] && printf '\a\e]777;notify;%s;%s\a\n\e[1;33m⏰ %s\e[0m\n' "$(_coolbash_t 'Rappel')" "$text" "$text" >"$tty" 2>/dev/null
    ) &
  ) >/dev/null 2>&1
  _coolbash_say '⏰ dans %ss : %s\n' "$secs" "$text"
}

# --- retry -------------------------------------------------------------------------------
# FR : retry <N> <commande…> — jusqu'à N essais, délai 1, 2, 4… s (plafond 60).
retry() {
  local n="${1:-}" i delay=1 rc
  shift
  [[ "$n" =~ ^[0-9]+$ && "$n" -ge 1 && $# -ge 1 ]] || {
    _coolbash_say 'usage : retry <N> <commande…>\n' >&2
    return 1
  }
  for ((i = 1; i <= n; i++)); do
    "$@" && return 0
    rc=$?
    ((i == n)) && break
    _coolbash_say 'retry : échec %d/%d (code %d), nouvel essai dans %ds\n' "$i" "$n" "$rc" "$delay" >&2
    sleep "$delay"
    ((delay < 60)) && delay=$((delay * 2))
  done
  _coolbash_say 'retry : abandon après %s essais\n' "$n" >&2
  return "$rc"
}

# --- copy / paste / copypath ------------------------------------------------------------
# FR : copy [texte] (sinon stdin) → presse-papiers. Outil selon la session :
#      wl-copy (Wayland), xclip / xsel (X11), pbcopy (macOS) ; sinon, ou en SSH,
#      OSC 52 : le terminal qui affiche reçoit le texte (foot, kitty, wezterm,
#      alacritty, tmux configuré…), même à distance.
_coolbash_clip_tool() {
  if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
    printf 'osc52'
  elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    printf 'wl'
  elif [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    printf 'xclip'
  elif [[ -n "${DISPLAY:-}" ]] && command -v xsel >/dev/null 2>&1; then
    printf 'xsel'
  elif command -v pbcopy >/dev/null 2>&1; then
    printf 'pb'
  else
    printf 'osc52'
  fi
}
copy() {
  local text
  if (($#)); then text="$*"; else text="$(cat)"; fi
  case "$(_coolbash_clip_tool)" in
    wl) printf '%s' "$text" | wl-copy ;;
    xclip) printf '%s' "$text" | xclip -selection clipboard ;;
    xsel) printf '%s' "$text" | xsel --clipboard --input ;;
    pb) printf '%s' "$text" | pbcopy ;;
    osc52) printf '\e]52;c;%s\a' "$(printf '%s' "$text" | base64 | tr -d '\n')" ;;
  esac
}
paste() {
  case "$(_coolbash_clip_tool)" in
    wl) wl-paste --no-newline ;;
    xclip) xclip -selection clipboard -o ;;
    xsel) xsel --clipboard --output ;;
    pb) pbpaste ;;
    *)
      _coolbash_say "paste : pas d'outil de presse-papiers ici (OSC 52 ne sait qu'écrire)\n" >&2
      return 1
      ;;
  esac
}
copypath() {
  local p="${1:-.}"
  [[ -e "$p" ]] || {
    _coolbash_say 'copypath : %s introuvable\n' "$p" >&2
    return 1
  }
  p="$(cd -- "$(dirname -- "$p")" && printf '%s/%s' "$PWD" "$(basename -- "$p")")"
  p="${p%/.}"
  copy "$p" && printf '%s\n' "$p"
}
true
