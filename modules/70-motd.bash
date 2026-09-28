# shellcheck shell=bash
#   ███    ███  ██████  ████████ ██████  
#   ████  ████ ██    ██    ██    ██   ██ 
#   ██ ████ ██ ██    ██    ██    ██   ██ 
#   ██  ██  ██ ██    ██    ██    ██   ██ 
#   ██      ██  ██████     ██    ██████  MODULE: MOTD
# ─────────────────────────────────────────────────────────────────────────────
# FR: Affiche une citation française (share/fortunes, dans la bouche de cowsay,
#     colorée par lolcat) et 6 lignes d'infos système au login, une seule fois
#     par session.
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

# FR : citations en français, une par ligne, un fichier par thème :
#       - embarquées : <racine CoolBash>/share/fortunes/<thème>.txt
#       - personnelles : ~/.coolbash/fortunes/<thème>.txt (jamais écrasées)
#      Tirage en pur bash (mapfile + RANDOM) : zéro processus, là où le
#      programme fortune coûtait 28 ms. COOLBASH_FORTUNE="dev chuck" limite aux
#      thèmes cités ; chaque fichier retenu a le même poids, un thème répété pèse
#      donc plus lourd. Un thème inconnu est ignoré ; aucun thème valide = tous.
_coolbash_fortune() {
  # FR : la sortie est écrite dans la variable nommée par $1 — aucun nom local
  #      ne doit pouvoir la masquer, d'où le préfixe _cf_.
  local _cf_out="$1" _cf_root="${COOLBASH_ROOT:-${COOLBASH_PREFIX:-$HOME/.coolbash}}"
  local _cf_dirs=("$_cf_root/share/fortunes" "${COOLBASH_PREFIX:-$HOME/.coolbash}/fortunes")
  local _cf_d _cf_t _cf_f _cf_files=() _cf_lines=() _cf_n
  for _cf_t in ${COOLBASH_FORTUNE:-}; do
    for _cf_d in "${_cf_dirs[@]}"; do [[ -s "$_cf_d/$_cf_t.txt" ]] && _cf_files+=("$_cf_d/$_cf_t.txt"); done
  done
  if (( ${#_cf_files[@]} == 0 )); then
    for _cf_d in "${_cf_dirs[@]}"; do for _cf_f in "$_cf_d"/*.txt; do [[ -s "$_cf_f" ]] && _cf_files+=("$_cf_f"); done; done
  fi
  (( ${#_cf_files[@]} )) || return 1
  _cf_f="${_cf_files[RANDOM % ${#_cf_files[@]}]}"
  mapfile -t _cf_lines < "$_cf_f"
  _cf_n=${#_cf_lines[@]}; (( _cf_n )) || return 1
  # FR : RANDOM s'arrête à 32767 — combiné pour couvrir les gros fichiers.
  for _ in 1 2 3 4 5; do
    printf -v "$_cf_out" '%s' "${_cf_lines[(RANDOM * 32768 + RANDOM) % _cf_n]}"
    [[ -n "${!_cf_out}" && "${!_cf_out}" != \#* ]] && return 0
  done
  return 1
}

_coolbash_motd() {
  _coolbash_motd_enabled || return 0
  [[ -t 1 ]] || return 0
  local text=""
  if ! _coolbash_fortune text && command -v fortune >/dev/null 2>&1; then text="$(fortune -a 2>/dev/null)"; fi
  if [[ -n "$text" ]]; then
    if command -v cowsay >/dev/null 2>&1; then
      # FR : « -e @@ -T U » = la vache paranoïaque avec sa langue, identique sous
      #      cowsay (Perl) et Neo-cowsay (Go, 3 ms), qui perd la langue avec -p.
      if command -v lolcat >/dev/null 2>&1; then printf '%s\n' "$text" | cowsay -e @@ -T U | lolcat
      else printf '%s\n' "$text" | cowsay -e @@ -T U; fi
    else
      printf '%s\n\n' "$text"
    fi
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
