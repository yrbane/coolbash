# shellcheck shell=bash
#   ███    ███  ██████  ████████ ██████  
#   ████  ████ ██    ██    ██    ██   ██ 
#   ██ ████ ██ ██    ██    ██    ██   ██ 
#   ██  ██  ██ ██    ██    ██    ██   ██ 
#   ██      ██  ██████     ██    ██████  MODULE: MOTD
# ─────────────────────────────────────────────────────────────────────────────
# FR: Affiche un message fun (fortune+cowsay+lolcat) et neofetch au login,
#     une seule fois par session.

# FR: Conditions d'affichage, testables sans terminal.
_coolbash_motd_enabled() {
  [[ -n "${MOTD_DISABLE:-}" ]] && return 1
  [[ "${COOLBASH_MOTD:-1}" == 0 ]] && return 1
  [[ -n "${COOLBASH_MOTD_SHOWN:-}" ]] && return 1
  _coolbash_safe && return 1
  return 0
}

_coolbash_motd() {
  _coolbash_motd_enabled || return 0
  [[ -t 1 ]] || return 0
  if command -v fortune >/dev/null 2>&1 && command -v cowsay >/dev/null 2>&1; then
    if command -v lolcat >/dev/null 2>&1; then fortune -a | cowsay -T U -p | lolcat
    else fortune -a | cowsay -T U -p; fi
  fi
  if command -v neofetch >/dev/null 2>&1; then
    neofetch --disable packages --stdout | sed -n '1,6p'
  fi
  export COOLBASH_MOTD_SHOWN=1
}
_coolbash_motd
