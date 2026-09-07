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
export HISTIGNORE='ls:ll:la:cd:pwd:exit:clear'

# FR: Append + lecture incrémentale = évite 'history -c; -r' à chaque prompt.
_coolbash_history_sync() {
  builtin history -a   # FR: Ajoute les nouvelles lignes (session courante)
  builtin history -n   # FR: Lit les nouvelles lignes (autres sessions)
}
# FR: Branché à chaque prompt (avant 0.4.0 la fonction n'était jamais appelée).
_coolbash_prompt_command_add _coolbash_history_sync
