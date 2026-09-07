# =============================================================================
#  CoolBash Completions (60-completion.bash)
#  Version: Safe Lazy-Load Edition
# =============================================================================

# FR: Fonction de chargement différé (évite blocage terminal)
_load_completions_safely() {
  # Empêche le double chargement
  [[ -n "${BASH_COMPLETION_LOADED:-}" ]] && return
  export BASH_COMPLETION_LOADED=1

  # Chargement du système
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion 2>/dev/null || true
  elif [[ -r /etc/bash_completion ]]; then
    . /etc/bash_completion 2>/dev/null || true
  fi

  # FR: Completions spécifiques (silencieuses)
  if declare -F _git >/dev/null 2>&1; then
    complete -o default -o nospace -F _git g
  fi

  command -v composer >/dev/null 2>&1 && eval "$(composer completion bash 2>/dev/null)" || true
  command -v symfony  >/dev/null 2>&1 && eval "$(symfony completion bash 2>/dev/null)" || true

  [[ -f "$HOME/.fzf.bash" ]] && . "$HOME/.fzf.bash" 2>/dev/null || true

  # FR: GPG_TTY pour pinentry (commits signés)
  command -v gpg >/dev/null 2>&1 && export GPG_TTY="$(tty)" || true
}


