# shellcheck shell=bash
#  ██   ██  █████   █████  ███████   █████   ██████   ██   ██
#  ██   ██    █    ██         █    ██   ██  ██   ██   ██ ██
#  ███████    █     █████     █    ██   ██  ██████      █
#  ██   ██    █         ██    █    ██   ██  ██   ██     █
#  ██   ██  █████   █████     █     █████   ██   ██     █     MODULE: HISTORY
# ─────────────────────────────────────────────────────────────────────────────
# FR: Historique volumineux, horodaté, partagé entre sessions (sans flush complet).

export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTTIMEFORMAT='%F %T  '
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE='ls:ll:la:cd:pwd:exit:clear:history*:fg:bg:jobs'

# FR: Append + lecture incrémentale = évite 'history -c; -r' à chaque prompt.
_coolbash_history_sync() {
  builtin history -a   # FR: Ajoute les nouvelles lignes (session courante)
  builtin history -n   # FR: Lit les nouvelles lignes (autres sessions)
}
# FR: Branché à chaque prompt (avant 0.4.0 la fonction n'était jamais appelée).
_coolbash_prompt_command_add _coolbash_history_sync

# FR : Ctrl-R / Ctrl-T / Alt-C via fzf, en shell interactif seulement (ces
#      fichiers définissent leurs propres fonctions). Emplacements : Arch,
#      Debian/Ubuntu, Fedora, puis ~/.fzf. COOLBASH_FZF=0 pour s'en passer,
#      COOLBASH_FZF_KEYBINDINGS pour imposer un fichier.
if [[ $- == *i* && "${COOLBASH_FZF:-1}" != 0 ]] && ! _coolbash_safe && command -v fzf >/dev/null 2>&1; then
  for COOLBASH_FZF_FILE in "${COOLBASH_FZF_KEYBINDINGS:-}" /usr/share/fzf/key-bindings.bash \
      /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/shell/key-bindings.bash "$HOME/.fzf/shell/key-bindings.bash"; do
    if [[ -n "$COOLBASH_FZF_FILE" && -r "$COOLBASH_FZF_FILE" ]]; then
      # shellcheck disable=SC1090
      . "$COOLBASH_FZF_FILE" 2>/dev/null
      break
    fi
  done
  unset COOLBASH_FZF_FILE
fi
true
