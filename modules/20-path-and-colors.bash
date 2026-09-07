# shellcheck shell=bash
#  ██████    █████   █████████  ██   ██
#  ██   ██  ██   ██     ███     ██   ██
#  ██████  ███████     ███     ███████
#  ██      ██   ██     ███     ██   ██
#  ██      ██   ██     ███     ██   ██    MODULE: PATH & COLORS
# ─────────────────────────────────────────────────────────────────────────────
# FR: Ajouts PATH idempotents + couleurs LS_COLORS via dircolors.

[[ -d "$HOME/.local/bin" ]] && path_prepend "$HOME/.local/bin"
[[ -d "$HOME/bin"        ]] && path_prepend "$HOME/bin"
path_append "/usr/games"
path_append "/usr/local/games"
path_append "$HOME/.local/share/gem/ruby/3.4.0/bin"
export PATH

# FR: LS_COLORS (ne redéfinit pas les alias).
if command -v dircolors >/dev/null 2>&1; then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
fi
