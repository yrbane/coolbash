# shellcheck shell=bash
#   ███    ███  ██████  ████████ ██████  
#   ████  ████ ██    ██    ██    ██   ██ 
#   ██ ████ ██ ██    ██    ██    ██   ██ 
#   ██  ██  ██ ██    ██    ██    ██   ██ 
#   ██      ██  ██████     ██    ██████  MODULE: MOTD
# ─────────────────────────────────────────────────────────────────────────────
# FR: Affiche un message fun (fortune+cowsay+lolcat) et neofetch au login,
#     une seule fois par session.

print_motd_once() {
  [[ -n "${MOTD_DISABLE:-}" ]] && return
  [[ -n "${BASHRC_MOTD_SHOWN:-}" ]] && return
  [[ -t 1 ]] || return
  if command -v fortune cowsay lolcat >/dev/null 2>&1; then
    fortune -a | cowsay -T U -p | lolcat
  fi
  if command -v neofetch >/dev/null 2>&1; then
    neofetch --disable packages --stdout | sed -n '1,6p'
  fi
  export BASHRC_MOTD_SHOWN=1
}
print_motd_once || true
