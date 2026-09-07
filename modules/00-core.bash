# shellcheck shell=bash
#   █████    █████   ██████   ██████
#  ██       ██   ██  ██   ██  ██
#  ██       ██   ██  ██████   █████
#  ██       ██   ██  ██   ██  ██
#   █████    █████   ██   ██  ██████   MODULE: CORE (ENV/SEC)
# ─────────────────────────────────────────────────────────────────────────────
# FR: Variables d'environnement cohérentes + sécurité douce.

# Disable MOTD and fancy aliases for root (minimal shell)
if [[ $EUID -eq 0 ]]; then
  export COOLBASH_MODE="safe"
else
  export COOLBASH_MODE="normal"
fi

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

# FR: Helpers PATH sans doublons.
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac; }
path_append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1";; esac; }
