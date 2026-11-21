# shellcheck shell=bash
#  ██████    █████   █████████  ██   ██
#  ██   ██  ██   ██     ███     ██   ██
#  ██████  ███████     ███     ███████
#  ██      ██   ██     ███     ██   ██
#  ██      ██   ██     ███     ██   ██    MODULE: PATH & COLORS
# ─────────────────────────────────────────────────────────────────────────────
# FR: Ajouts PATH idempotents + couleurs LS_COLORS via dircolors.

# FR : Homebrew sur Mac Apple Silicon — /opt/homebrew n'est pas dans le PATH par
#      défaut (l'installeur ne l'ajoute qu'à ~/.zprofile, que bash ne lit pas).
#      Sur Mac Intel, /usr/local/bin y est déjà.
if [[ -x /opt/homebrew/bin/brew ]]; then
  path_prepend /opt/homebrew/sbin
  path_prepend /opt/homebrew/bin
fi
[[ -d "$HOME/.local/bin" ]] && path_prepend "$HOME/.local/bin"
[[ -d "$HOME/bin" ]] && path_prepend "$HOME/bin"
[[ -d /usr/games ]] && path_append "/usr/games"
[[ -d /usr/local/games ]] && path_append "/usr/local/games"
# FR : gems Ruby utilisateur — quelle que soit la version, seulement si présent.
for COOLBASH_GEM_BIN in "$HOME"/.local/share/gem/ruby/*/bin; do
  [[ -d "$COOLBASH_GEM_BIN" ]] && path_append "$COOLBASH_GEM_BIN"
done
unset COOLBASH_GEM_BIN
export PATH

# FR: LS_COLORS (ne redéfinit pas les alias).
if command -v dircolors >/dev/null 2>&1; then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
fi
