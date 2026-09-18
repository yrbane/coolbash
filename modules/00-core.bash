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

# FR: Locale fr_FR.UTF-8 par défaut si elle existe sur la machine ; sinon repli
#     sur C.UTF-8 (serveurs minimalistes, CI) pour éviter « setlocale: cannot
#     change locale ». Une valeur déjà définie n'est jamais modifiée.
if [[ -z "${LANG:-}" || -z "${LC_ALL:-}" ]]; then
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
export LESSSECURE=1        # FR: Désactive les fonctions risquées de less (!, |)

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
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac; }
path_append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1";; esac; }

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
