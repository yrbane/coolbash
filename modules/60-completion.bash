# shellcheck shell=bash
#   █████   █████  ███    ███ ██████  ██      ██████  ███████ █████  █████  ██   ██
#  ██      ██   ██ ████  ████ ██   ██ ██      ██         █      █   ██   ██ ███  ██
#  ██      ██   ██ ██ ████ ██ ██████  ██      █████      █      █   ██   ██ ██ ██ ██
#  ██      ██   ██ ██  ██  ██ ██      ██      ██         █      █   ██   ██ ██  ███
#   █████   █████  ██      ██ ██      ██████  ██████     █    █████  █████  ██   ██   MODULE: COMPLETION
# ─────────────────────────────────────────────────────────────────────────────
# FR: Completions Bash/Git/fzf chargées au premier <Tab> (chargement différé
#     réel : bash-completion coûte ~50 ms, inutile de le payer à chaque shell).
#     Avant 0.4.0 la fonction de chargement n'était jamais appelée.

_coolbash_completion_load() {
  [[ -n "${COOLBASH_COMPLETION_LOADED:-}" ]] && return 0
  COOLBASH_COMPLETION_LOADED=1
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck disable=SC1091
    . /usr/share/bash-completion/bash_completion 2>/dev/null || true
  elif [[ -r /etc/bash_completion ]]; then
    # shellcheck disable=SC1091
    . /etc/bash_completion 2>/dev/null || true
  fi
  # FR: alias `g` → completion git.
  declare -F _git >/dev/null 2>&1 && complete -o default -o nospace -F _git g
  command -v composer >/dev/null 2>&1 && eval "$(composer completion bash 2>/dev/null)" || true
  command -v symfony  >/dev/null 2>&1 && eval "$(symfony completion bash 2>/dev/null)" || true
  # shellcheck disable=SC1091
  [[ -f "$HOME/.fzf.bash" ]] && . "$HOME/.fzf.bash" 2>/dev/null || true
  return 0
}

# FR: Chargeur par défaut (-D) : charge tout au premier <Tab>, se retire, puis
#     renvoie 124 pour que bash relance la completion avec les vraies règles.
_coolbash_completion_lazy() {
  complete -r -D 2>/dev/null
  _coolbash_completion_load
  return 124
}

if ! _coolbash_safe; then
  complete -D -F _coolbash_completion_lazy
fi

# FR: GPG_TTY pour pinentry (commits signés).
if command -v gpg >/dev/null 2>&1 && [[ -t 0 ]]; then
  GPG_TTY="$(tty)"
  export GPG_TTY
fi
true
