# shellcheck shell=bash
# shellcheck disable=SC2178,SC2128  # FR : PROMPT_COMMAND est une chaîne OU un tableau selon bash
#   █████    █████   ██████   ██████
#  ██       ██   ██  ██   ██  ██
#  ██       ██   ██  ██████   █████
#  ██       ██   ██  ██   ██  ██
#   █████    █████   ██   ██  ██████   MODULE: CORE (ENV/SEC)
# ─────────────────────────────────────────────────────────────────────────────
# FR: Variables d'environnement cohérentes + sécurité douce.

# FR: Mode « safe » (root par défaut, ou COOLBASH_MODE=safe) : shell minimal,
#     sans emoji, ni git dans le prompt, ni MOTD, ni completion différée.
#     Une valeur déjà définie est respectée.
if [[ -z "${COOLBASH_MODE:-}" ]]; then
  if [[ $EUID -eq 0 ]]; then COOLBASH_MODE="safe"; else COOLBASH_MODE="normal"; fi
fi
export COOLBASH_MODE
_coolbash_safe() { [[ "${COOLBASH_MODE}" == "safe" ]]; }

# FR : messages traduits (share/lang) — déjà chargés quand on vient de la CLI ou
#      d'un ~/.bashrc compilé ; sinon (module sourcé seul : tests) depuis ici.
#      Avant la locale : la langue est celle que l'utilisateur a choisie.
if ! declare -F _coolbash_t >/dev/null 2>&1; then
  COOLBASH_LANG_DIR="${BASH_SOURCE[0]%/*}/../share/lang"
  [[ -r "${COOLBASH_LANG_DIR}/_lang.bash" ]] || COOLBASH_LANG_DIR="${COOLBASH_PREFIX:-$HOME/.coolbash}/share/lang"
  # shellcheck disable=SC1091
  [[ -r "${COOLBASH_LANG_DIR}/_lang.bash" ]] && source "${COOLBASH_LANG_DIR}/_lang.bash"
  unset COOLBASH_LANG_DIR
fi
declare -F _coolbash_lang_init >/dev/null 2>&1 && _coolbash_lang_init
# FR : sans share/lang (CLI copiée seule) : les messages restent en français.
if ! declare -F _coolbash_t >/dev/null 2>&1; then
  _coolbash_t() { printf '%s' "$1"; }
  _coolbash_say() {
    local _cs_f="$1"
    shift
    # shellcheck disable=SC2059
    printf "$_cs_f" "$@"
  }
fi

# FR: Locale fr_FR.UTF-8 par défaut si elle existe sur la machine ; sinon repli
#     sur C.UTF-8 (serveurs minimalistes, CI) pour éviter « setlocale: cannot
#     change locale ». Seulement si ni LANG ni LC_ALL n'est défini : un LANG
#     choisi (en_US…) n'est jamais écrasé par un LC_ALL français (avant 0.34.0,
#     il l'était).
if [[ -z "${LANG:-}" && -z "${LC_ALL:-}" ]]; then
  if locale -a 2>/dev/null | grep -qiE '^fr_FR\.utf-?8$'; then
    COOLBASH_LOCALE="fr_FR.UTF-8"
  else
    COOLBASH_LOCALE="C.UTF-8"
  fi
  export LANG="${LANG:-$COOLBASH_LOCALE}"
  export LC_ALL="${LC_ALL:-$COOLBASH_LOCALE}"
  unset COOLBASH_LOCALE
fi
export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-nano}"
export PAGER="${PAGER:-less}"
export LESS='-R --mouse --ignore-case --LONG-PROMPT --prompt="Less → %f  %lb/%L  (line %l)"'
export LESSSECURE=1 # FR: Désactive les fonctions risquées de less (!, |)

# FR: Sécurité douce: ne pas écraser par accident, permissions par défaut restrictives.
umask 027
set -o noclobber

# FR: Qualité de vie Bash.
shopt -s autocd cdspell dirspell checkjobs extglob globstar histappend cmdhist checkwinsize

# FR: Readline/completion (insensible à la casse, montre tout si ambigu).
# bind 'set completion-ignore-case on'
# bind 'set show-all-if-ambiguous on'
# bind '"\e[Z": menu-complete-backward'  # Shift-Tab = complétion arrière

# FR: Helpers PATH sans doublons (API publique).
# FR : un alias homonyme (ancienne version, ~/.bash_aliases) serait développé à la
#      lecture de « nom() { » → erreur de syntaxe au rechargement du .bashrc.
unalias path_prepend path_append 2>/dev/null
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac }
path_append() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac }

# FR: Ajout idempotent d'une fonction en tête de PROMPT_COMMAND (tableau ou
#     chaîne, selon la version de bash). Utilisé par 10-history et 50-prompt.
_coolbash_prompt_command_add() {
  local fn="$1" item
  if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
    for item in "${PROMPT_COMMAND[@]}"; do [[ "$item" == "$fn" ]] && return 0; done
    PROMPT_COMMAND=("$fn" "${PROMPT_COMMAND[@]}")
  else
    [[ ";${PROMPT_COMMAND:-};" == *";$fn;"* ]] && return 0
    PROMPT_COMMAND="${fn}${PROMPT_COMMAND:+; ${PROMPT_COMMAND}}"
  fi
}
