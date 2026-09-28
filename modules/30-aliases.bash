# shellcheck shell=bash
#    █████   ██      █████    █████    █████   ██████   █████
#   ██   ██  ██        █     ██   ██  ██      ██       ██
#   ███████  ██        █     ███████   █████   █████    █████
#   ██   ██  ██        █     ██   ██       ██  ██           ██
#   ██   ██  ██████  █████   ██   ██   █████   ██████   █████    MODULE: ALIASES
# ─────────────────────────────────────────────────────────────────────────────
# FR: Alias lisibles, sûrs et idempotents.

# --- LS / EZA / LSD avec fallback sécurisé ---
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --git --icons=auto'
  alias ll='eza -l --group-directories-first --git --icons=auto'
  alias la='eza -la --group-directories-first --git --icons=auto'
elif command -v lsd >/dev/null 2>&1; then
  alias ls='lsd --group-dirs=first'
  alias ll='lsd -l --group-dirs=first'
  alias la='lsd -la --group-dirs=first'
else
  # Vérifie si "ls" supporte --group-directories-first
  if command ls --group-directories-first >/dev/null 2>&1; then
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -alF --color=auto --group-directories-first'
    alias la='ls -A --color=auto --group-directories-first'
  else
    alias ls='ls --color=auto'
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
  fi
fi

# FR: grep colorisé (fgrep/egrep redirigés vers grep moderne).
alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'

# FR: Affichages pratiques.
alias df='df -h'
alias free='free -h'

# FR: Sécurité douce (n'affecte pas les scripts).
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# FR: Sudo helpers (NB: espace final sur 'pls' pour chaîner d'autres alias).
# FR : `alias please='sudo !!'` ne peut pas marcher — l'expansion d'historique
#      n'a pas lieu dans un alias. `fc -l` écarte déjà la ligne en cours
#      (« please ») : -1 désigne donc bien la commande précédente.
# FR : un alias homonyme (ancienne version, ~/.bash_aliases) serait développé à la
#      lecture de « nom() { » → erreur de syntaxe au rechargement du .bashrc.
unalias please 2>/dev/null
please() {
  local cmd
  cmd="$(HISTTIMEFORMAT='' builtin fc -ln -1 -1 2>/dev/null)"
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  if [[ -z "$cmd" || "$cmd" == please* ]]; then
    echo "please: aucune commande à relancer." >&2
    return 1
  fi
  printf 'sudo %s\n' "$cmd"
  eval "sudo $cmd"
}
alias pls='sudo '
alias sano='sudo -E nano'

# FR: Gestionnaire de paquets : APT, sinon pacman.
if command -v apt >/dev/null 2>&1; then
  alias au='sudo apt update'
  alias aug='sudo apt update && sudo apt -y upgrade'
  alias asr='apt search'
  alias ain='sudo apt -y install'
  alias arm='sudo apt -y remove'
  alias apc='sudo apt -y autoremove && sudo apt -y autoclean'
# FR : mêmes raccourcis sur Arch. Pas de `pacman -Sy` seul (mise à jour
#      partielle = système cassé) : au et aug font tous deux -Syu.
elif command -v pacman >/dev/null 2>&1; then
  alias au='sudo pacman -Syu'
  alias aug='sudo pacman -Syu'
  alias asr='pacman -Ss'
  alias ain='sudo pacman -S'
  alias arm='sudo pacman -Rs'
  alias apc='pacman -Qdtq | sudo pacman -Rns - ; sudo pacman -Sc'
fi

# FR: Fichiers d'alias utilisateur (optionnel).
if [[ -f "$HOME/.bash_aliases" ]]; then
  # shellcheck disable=SC1091
  . "$HOME/.bash_aliases"
fi
