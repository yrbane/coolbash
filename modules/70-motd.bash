# shellcheck shell=bash
#   ███    ███  ██████  ████████ ██████  
#   ████  ████ ██    ██    ██    ██   ██ 
#   ██ ████ ██ ██    ██    ██    ██   ██ 
#   ██  ██  ██ ██    ██    ██    ██   ██ 
#   ██      ██  ██████     ██    ██████  MODULE: MOTD
# ─────────────────────────────────────────────────────────────────────────────
# FR: Affiche une citation française (share/fortunes, dans la bouche de cowsay,
#     colorée par lolcat) et 8 lignes d'infos système au login (user@host, OS,
#     Host, Kernel, Uptime, Date, Disk), une seule fois par session.
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
  local kernel os="" host="" up title line uptime
  read -r kernel 2>/dev/null < /proc/sys/kernel/osrelease || return 0
  read -r up _ 2>/dev/null < /proc/uptime || return 0
  # FR : lu ligne à ligne plutôt que sourcé dans un sous-shell (≈ 1 ms de fork).
  if [[ -r /etc/os-release ]]; then
    while IFS= read -r line; do
      [[ "$line" == PRETTY_NAME=* ]] && { os="${line#PRETTY_NAME=}"; os="${os%\"}"; os="${os#\"}"; break; }
    done < /etc/os-release
  fi
  read -r host 2>/dev/null < /sys/class/dmi/id/product_name
  title="${USER:-$LOGNAME}@${HOSTNAME%%.*}"
  printf '%s\n%s\n' "$title" "${title//?/-}"
  [[ -n "$os" ]]   && printf 'OS: %s %s\n' "$os" "${HOSTTYPE:-}"
  [[ -n "$host" ]] && printf 'Host: %s\n' "$host"
  printf 'Kernel: %s\n' "$kernel"
  _coolbash_motd_uptime uptime "${up%.*}"
  printf 'Uptime: %s\n' "$uptime"
  # FR : la date par le printf intégré (pas de processus `date`).
  _coolbash_motd_hidden date || printf 'Date: %(%Y-%m-%d %H:%M)T (%(%A)T)\n' -1 -1
  _coolbash_motd_hidden disk    || _coolbash_motd_disk
  _coolbash_motd_hidden mem     || _coolbash_motd_mem
  _coolbash_motd_hidden load    || _coolbash_motd_load
  _coolbash_motd_hidden battery || _coolbash_motd_battery
  _coolbash_motd_hidden reboot  || _coolbash_motd_reboot
  _coolbash_motd_hidden failed  || _coolbash_motd_failed
  _coolbash_motd_hidden note    || _coolbash_motd_note
}

# FR : COOLBASH_MOTD_HIDE="battery load" — lignes à ne pas afficher.
_coolbash_motd_hidden() {
  local w
  for w in ${COOLBASH_MOTD_HIDE:-}; do [[ "$w" == "$1" ]] && return 0; done
  return 1
}

# FR : couleur d'un pourcentage d'occupation : jaune dès 80, rouge dès 90.
#      Sortie dans la variable $1 (pas de sous-shell : chaque $(…) coûte ≈ 1 ms).
_coolbash_motd_pcent_color() {
  if (( $2 >= 90 )); then printf -v "$1" '\e[31m'; elif (( $2 >= 80 )); then printf -v "$1" '\e[33m'; else printf -v "$1" ''; fi
}

# FR : kB → « 6.2G » (une décimale), sans processus. Sortie dans la variable $1.
_coolbash_motd_human_kb() {
  local kb="$2" unit=K div=1
  if (( kb >= 1048576 )); then unit=G; div=1048576; elif (( kb >= 1024 )); then unit=M; div=1024; fi
  printf -v "$1" '%d.%d%s' $(( kb / div )) $(( kb % div * 10 / div )) "$unit"
}

# FR : mémoire — /proc/meminfo (MemAvailable = ce que le noyau pourrait libérer).
_coolbash_motd_mem() {
  local key val _ total="" avail="" used pcent
  while read -r key val _; do
    case "$key" in MemTotal:) total="$val" ;; MemAvailable:) avail="$val" ;; esac
    [[ -n "$total" && -n "$avail" ]] && break
  done 2>/dev/null < /proc/meminfo
  [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ && "$total" -gt 0 ]] || return 0
  local color h_used h_total
  used=$(( total - avail )); pcent=$(( used * 100 / total ))
  _coolbash_motd_pcent_color color "$pcent"
  _coolbash_motd_human_kb h_used "$used"; _coolbash_motd_human_kb h_total "$total"
  printf "Mem: %s used of %s (${color}%s%%\e[0m)\n" "$h_used" "$h_total" "$pcent"
}

# FR : charge — /proc/loadavg et le nombre de cœurs (glob /sys, pas de nproc).
#      Rouge si la charge 1 min dépasse le nombre de cœurs, jaune à partir de la moitié.
_coolbash_motd_load() {
  local l1 l5 l15 _ cores=0 c color="" l1c
  read -r l1 l5 l15 _ 2>/dev/null < /proc/loadavg || return 0
  for c in /sys/devices/system/cpu/cpu[0-9]*; do [[ -d "$c" ]] && cores=$(( cores + 1 )); done
  (( cores > 0 )) || cores=1
  l1c="${l1/[.,]/}"; l1c="${l1c#0}"; l1c="${l1c:-0}"   # 0.52 → 52 (centièmes)
  if (( 10#$l1c >= cores * 100 )); then color='\e[31m'; elif (( 10#$l1c >= cores * 50 )); then color='\e[33m'; fi
  local plural=""; (( cores > 1 )) && plural=s
  printf "Load: ${color}%s\e[0m %s %s (%d core%s)\n" "$l1" "$l5" "$l15" "$cores" "$plural"
}

# FR : batterie — /sys/class/power_supply/BAT*. Rouge sous 20 % en décharge, jaune sous 40.
_coolbash_motd_battery() {
  local b cap status color=""
  for b in /sys/class/power_supply/BAT*; do
    read -r cap 2>/dev/null < "$b/capacity" || continue
    read -r status 2>/dev/null < "$b/status" || status="unknown"
    [[ "$cap" =~ ^[0-9]+$ ]] || continue
    if [[ "$status" == Discharging ]]; then
      if (( cap < 20 )); then color='\e[31m'; elif (( cap < 40 )); then color='\e[33m'; fi
    fi
    printf "Battery: ${color}%s%%\e[0m (%s)\n" "$cap" "$status"
  done
  return 0
}

# FR : redémarrage requis — Arch : le dossier des modules du noyau qui tourne a
#      disparu (le noyau a été mis à jour) ; Debian : /var/run/reboot-required.
#      Paramètres (tests) : $1 dossier des modules, $2 fichier drapeau.
_coolbash_motd_reboot() {
  local modules="${1:-/usr/lib/modules}" flag="${2:-/var/run/reboot-required}" kernel="" d any=0
  if [[ -f "$flag" ]]; then printf '\e[31mReboot required\e[0m (%s)\n' "$flag"; return 0; fi
  read -r kernel 2>/dev/null < /proc/sys/kernel/osrelease || return 0
  [[ -d "$modules" ]] || return 0
  for d in "$modules"/*/; do [[ -d "$d" ]] && any=1 && break; done
  (( any )) || return 0
  [[ -d "$modules/$kernel" ]] || printf '\e[31mReboot required\e[0m: kernel %s is running but its modules are gone (kernel updated)\n' "$kernel"
  return 0
}

# FR : unités systemd en échec — un seul systemctl (≈ 5 ms), affiché seulement si > 0.
_coolbash_motd_failed() {
  local unit _ names="" n=0
  command -v systemctl >/dev/null 2>&1 || return 0
  while read -r unit _; do
    [[ -n "$unit" ]] || continue
    n=$(( n + 1 )); names+="${names:+, }$unit"
  done < <(systemctl --failed --no-legend --plain 2>/dev/null)
  (( n > 0 )) && printf '\e[31mFailed units: %d\e[0m (%s)\n' "$n" "$names"
  return 0
}

# FR : pense-bête personnel — ~/.coolbash/motd.txt, affiché tel quel.
_coolbash_motd_note() {
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/motd.txt" lines=()
  [[ -s "$file" ]] || return 0
  mapfile -t lines < "$file"
  printf '\n'; printf '\e[36m%s\e[0m\n' "${lines[@]}"
}

# FR : disques — un seul `df -Phl` (local, format POSIX, lisible) : / toujours,
#      les autres partitions seulement à partir de 80 %. Seuls les vrais
#      périphériques (/dev/…, sauf loop) comptent : pas de tmpfs, pas de snap.
#      Sans df (PATH réduit), pas de ligne.
_coolbash_motd_disk() {
  local fs size used _ pcent mount p color
  command -v df >/dev/null 2>&1 || return 0
  while read -r fs size used _ pcent mount; do
    [[ "$fs" == /dev/* && "$fs" != /dev/loop* && "$pcent" =~ ^[0-9]+%$ ]] || continue
    p="${pcent%\%}"
    [[ "$mount" == / || "$p" -ge 80 ]] || continue
    _coolbash_motd_pcent_color color "$p"
    printf "Disk (%s): %s used of %s (${color}%s\e[0m)\n" "$mount" "$used" "$size" "$pcent"
  done < <(df -Phl 2>/dev/null)
  return 0
}

# FR : « 1 day, 7 hours, 1 min » — le format de neofetch. $1 = variable de sortie.
_coolbash_motd_uptime() {
  local s="$2" d h m out=""
  d=$(( s / 86400 )); h=$(( s % 86400 / 3600 )); m=$(( s % 3600 / 60 ))
  (( d > 0 )) && { out="$d day"; (( d > 1 )) && out+=s; out+=", "; }
  (( h > 0 )) && { out+="$h hour"; (( h > 1 )) && out+=s; out+=", "; }
  out+="$m min"; (( m != 1 )) && out+=s
  printf -v "$1" '%s' "$out"
}
_coolbash_motd
