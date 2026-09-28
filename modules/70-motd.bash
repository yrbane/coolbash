# shellcheck shell=bash
#   ███    ███  ██████  ████████ ██████  
#   ████  ████ ██    ██    ██    ██   ██ 
#   ██ ████ ██ ██    ██    ██    ██   ██ 
#   ██  ██  ██ ██    ██    ██    ██   ██ 
#   ██      ██  ██████     ██    ██████  MODULE: MOTD
# ─────────────────────────────────────────────────────────────────────────────
# FR: Affiche un message fun (fortune+cowsay+lolcat) et 6 lignes d'infos
#     système au login, une seule fois par session.
#     neofetch calculait tout (GPU, résolution, thème, police du terminal…)
#     pour qu'on n'en garde que 6 lignes : de 0,5 à 2,7 s par shell. Les mêmes
#     lignes sont lues dans /proc, /sys et /etc/os-release, sans un seul
#     processus. Sans /proc (macOS), ce bloc est simplement absent.

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
  _coolbash_motd_sysinfo
  export COOLBASH_MOTD_SHOWN=1
}

# FR : même présentation que « neofetch --stdout », en pur bash.
_coolbash_motd_sysinfo() {
  local kernel os="" host="" up title PRETTY_NAME=""
  read -r kernel 2>/dev/null < /proc/sys/kernel/osrelease || return 0
  read -r up _ 2>/dev/null < /proc/uptime || return 0
  # shellcheck disable=SC1091
  [[ -r /etc/os-release ]] && { PRETTY_NAME="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-}")"; os="$PRETTY_NAME"; }
  read -r host 2>/dev/null < /sys/class/dmi/id/product_name
  title="${USER:-$LOGNAME}@${HOSTNAME%%.*}"
  printf '%s\n%s\n' "$title" "${title//?/-}"
  [[ -n "$os" ]]   && printf 'OS: %s %s\n' "$os" "${HOSTTYPE:-}"
  [[ -n "$host" ]] && printf 'Host: %s\n' "$host"
  printf 'Kernel: %s\n' "$kernel"
  printf 'Uptime: %s\n' "$(_coolbash_motd_uptime "${up%.*}")"
}

# FR : « 1 day, 7 hours, 1 min » — le format de neofetch.
_coolbash_motd_uptime() {
  local s="$1" d h m out=""
  d=$(( s / 86400 )); h=$(( s % 86400 / 3600 )); m=$(( s % 3600 / 60 ))
  (( d > 0 )) && out="$d day$([[ $d -gt 1 ]] && printf s), "
  (( h > 0 )) && out+="$h hour$([[ $h -gt 1 ]] && printf s), "
  out+="$m min$([[ $m -ne 1 ]] && printf s)"
  printf '%s' "$out"
}
_coolbash_motd
