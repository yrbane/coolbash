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
#     processus. macOS n'a pas /proc : un seul sysctl donne noyau, démarrage,
#     mémoire, cœurs, charge et modèle ; vm_stat la mémoire libre, pmset la
#     batterie (chemins absolus : rien ne dépend du PATH).

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
#      Tirage en pur bash (mapfile ou read + RANDOM) : zéro processus, là où le
#      programme fortune coûtait 28 ms. COOLBASH_FORTUNE="dev chuck" limite aux
#      thèmes cités ; chaque fichier retenu a le même poids, un thème répété pèse
#      donc plus lourd. Un thème inconnu est ignoré ; aucun thème valide = tous —
#      et alors les thèmes personnels (~/.coolbash/fortunes/) comptent double :
#      on les a écrits pour les relire.
_coolbash_fortune() {
  # FR : la sortie est écrite dans la variable nommée par $1 — aucun nom local
  #      ne doit pouvoir la masquer, d'où le préfixe _cf_.
  local _cf_out="$1" _cf_root="${COOLBASH_ROOT:-${COOLBASH_PREFIX:-$HOME/.coolbash}}"
  local _cf_dirs=("$_cf_root/share/fortunes" "${COOLBASH_PREFIX:-$HOME/.coolbash}/fortunes")
  local _cf_d _cf_t _cf_f _cf_files=() _cf_lines=() _cf_n
  for _cf_t in ${COOLBASH_FORTUNE:-}; do
    for _cf_d in "${_cf_dirs[@]}"; do [[ -s "$_cf_d/$_cf_t.txt" ]] && _cf_files+=("$_cf_d/$_cf_t.txt"); done
  done
  if ((${#_cf_files[@]} == 0)); then
    for _cf_f in "${_cf_dirs[0]}"/*.txt; do [[ -s "$_cf_f" ]] && _cf_files+=("$_cf_f"); done
    for _cf_f in "${_cf_dirs[1]}"/*.txt; do [[ -s "$_cf_f" ]] && _cf_files+=("$_cf_f" "$_cf_f"); done
  fi
  ((${#_cf_files[@]})) || return 1
  _cf_f="${_cf_files[RANDOM % ${#_cf_files[@]}]}"
  _coolbash_readlines _cf_lines <"$_cf_f"
  _cf_n=${#_cf_lines[@]}
  ((_cf_n)) || return 1
  # FR : RANDOM s'arrête à 32767 — combiné pour couvrir les gros fichiers.
  for _ in 1 2 3 4 5; do
    printf -v "$_cf_out" '%s' "${_cf_lines[(RANDOM * 32768 + RANDOM) % _cf_n]}"
    [[ -n "${!_cf_out}" && "${!_cf_out}" != \#* ]] && return 0
  done
  return 1
}

# FR : l'état de la machine d'abord, la vache en dernier : c'est elle qu'on
#      veut voir juste au-dessus du prompt.
_coolbash_motd() {
  _coolbash_motd_enabled || return 0
  [[ -t 1 ]] || return 0
  _coolbash_motd_hidden image || _coolbash_motd_image
  _coolbash_motd_sysinfo
  local text=""
  if ! _coolbash_fortune text && command -v fortune >/dev/null 2>&1; then text="$(fortune -a 2>/dev/null)"; fi
  if [[ -n "$text" ]]; then
    if command -v cowsay >/dev/null 2>&1; then
      # FR : « -e @@ -T U » = la vache paranoïaque avec sa langue, identique sous
      #      cowsay (Perl) et Neo-cowsay (Go, 3 ms), qui perd la langue avec -p.
      if command -v lolcat >/dev/null 2>&1; then
        printf '%s\n' "$text" | cowsay -e @@ -T U | lolcat
      else printf '%s\n' "$text" | cowsay -e @@ -T U; fi
    else
      printf '%s\n\n' "$text"
    fi
  fi
  export COOLBASH_MOTD_SHOWN=1
}

# FR : même présentation que « neofetch --stdout », en pur bash.
_coolbash_motd_sysinfo() {
  local kernel os="" host="" up title line uptime
  # FR : macOS — rempli par _coolbash_motd_darwin : mémoire (octets), cœurs, charge.
  #      Local ici, donc visible de _coolbash_motd_mem et _load (portée dynamique).
  local -a _coolbash_motd_sys=()
  if [[ -r /proc/sys/kernel/osrelease ]]; then
    read -r kernel 2>/dev/null </proc/sys/kernel/osrelease || return 0
    read -r up _ 2>/dev/null </proc/uptime || return 0
  else
    _coolbash_motd_darwin || return 0
  fi
  # FR : lu ligne à ligne plutôt que sourcé dans un sous-shell (≈ 1 ms de fork).
  if [[ -z "$os" && -r /etc/os-release ]]; then
    while IFS= read -r line; do
      [[ "$line" == PRETTY_NAME=* ]] && {
        os="${line#PRETTY_NAME=}"
        os="${os%\"}"
        os="${os#\"}"
        break
      }
    done </etc/os-release
  fi
  [[ -n "$host" ]] || read -r host 2>/dev/null </sys/class/dmi/id/product_name
  title="${USER:-$LOGNAME}@${HOSTNAME%%.*}"
  printf '%s\n%s\n' "$title" "${title//?/-}"
  [[ -n "$os" ]] && printf 'OS: %s %s\n' "$os" "${HOSTTYPE:-}"
  [[ -n "$host" ]] && printf 'Host: %s\n' "$host"
  printf 'Kernel: %s\n' "$kernel"
  _coolbash_motd_uptime uptime "${up%.*}"
  printf 'Uptime: %s\n' "$uptime"
  # FR : la date par le printf intégré (pas de processus `date`).
  _coolbash_motd_hidden date || {
    _coolbash_date line '%Y-%m-%d %H:%M (%A)'
    printf 'Date: %s\n' "$line"
  }
  _coolbash_motd_hidden disk || _coolbash_motd_disk
  _coolbash_motd_hidden mem || _coolbash_motd_mem
  _coolbash_motd_hidden load || _coolbash_motd_load
  _coolbash_motd_hidden battery || _coolbash_motd_battery
  _coolbash_motd_hidden reboot || _coolbash_motd_reboot
  _coolbash_motd_hidden failed || _coolbash_motd_failed
  _coolbash_motd_hidden update || _coolbash_motd_update
  _coolbash_motd_hidden note || _coolbash_motd_note
  _coolbash_motd_hidden todo || _coolbash_motd_todo
}

# FR : macOS — renseigne kernel, up, os et host de _coolbash_motd_sysinfo, et
#      _coolbash_motd_sys=(mémoire en octets, cœurs, "l1 l5 l15"). Un seul
#      processus (sysctl, LC_ALL=C : pas de virgule décimale) ; la version de
#      macOS est lue dans SystemVersion.plist, sans sw_vers.
_coolbash_motd_darwin() {
  local line key="" name="" ver="" boot now i=0
  [[ -x /usr/sbin/sysctl ]] || return 1
  while IFS= read -r line; do
    case "$i" in
      0) kernel="$line" ;;
      1)
        boot="${line#*sec = }"
        boot="${boot%%,*}"
        ;;
      2) _coolbash_motd_sys[0]="$line" ;;
      3) _coolbash_motd_sys[1]="$line" ;;
      4)
        line="${line#\{ }"
        _coolbash_motd_sys[2]="${line% \}}"
        ;;
      5) host="$line" ;;
    esac
    i=$((i + 1))
  done < <(LC_ALL=C /usr/sbin/sysctl -n kern.osrelease kern.boottime hw.memsize hw.ncpu vm.loadavg hw.model 2>/dev/null)
  [[ -n "$kernel" && "$boot" =~ ^[0-9]+$ ]] || return 1
  _coolbash_date now %s
  up=$((now - boot))
  while IFS= read -r line; do
    case "$line" in
      *'<key>ProductName</key>'*) key=name ;;
      *'<key>ProductVersion</key>'*) key=ver ;;
      *'<string>'*)
        line="${line#*<string>}"
        line="${line%%</string>*}"
        case "$key" in name) name="$line" ;; ver) ver="$line" ;; esac
        key=""
        ;;
    esac
  done 2>/dev/null </System/Library/CoreServices/SystemVersion.plist
  os="${name:-macOS}${ver:+ $ver}"
  return 0
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
  if (($2 >= 90)); then printf -v "$1" '\e[31m'; elif (($2 >= 80)); then printf -v "$1" '\e[33m'; else printf -v "$1" ''; fi
}

# FR : kB → « 6.2G » (une décimale), sans processus. Sortie dans la variable $1.
_coolbash_motd_human_kb() {
  local kb="$2" unit=K div=1
  if ((kb >= 1048576)); then
    unit=G
    div=1048576
  elif ((kb >= 1024)); then
    unit=M
    div=1024
  fi
  printf -v "$1" '%d.%d%s' $((kb / div)) $((kb % div * 10 / div)) "$unit"
}

# FR : mémoire — /proc/meminfo (MemAvailable = ce que le noyau pourrait libérer).
#      macOS : hw.memsize, et vm_stat pour le disponible (pages libres,
#      inactives et spéculatives).
_coolbash_motd_mem() {
  local key val _ total="" avail="" used pcent line page=4096 pages=0
  if [[ -r /proc/meminfo ]]; then
    while read -r key val _; do
      case "$key" in MemTotal:) total="$val" ;; MemAvailable:) avail="$val" ;; esac
      [[ -n "$total" && -n "$avail" ]] && break
    done 2>/dev/null </proc/meminfo
  elif [[ "${_coolbash_motd_sys[0]:-}" =~ ^[0-9]+$ && -x /usr/bin/vm_stat ]]; then
    while IFS= read -r line; do
      case "$line" in
        *'page size of '*)
          page="${line#*page size of }"
          page="${page%% *}"
          ;;
        'Pages free:'* | 'Pages inactive:'* | 'Pages speculative:'*)
          val="${line##* }"
          val="${val%.}"
          [[ "$val" =~ ^[0-9]+$ ]] && pages=$((pages + val))
          ;;
      esac
    done < <(/usr/bin/vm_stat 2>/dev/null)
    [[ "$page" =~ ^[0-9]+$ ]] || return 0
    total=$((_coolbash_motd_sys[0] / 1024))
    avail=$((pages * page / 1024))
  fi
  [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ && "$total" -gt 0 ]] || return 0
  local color h_used h_total
  used=$((total - avail))
  pcent=$((used * 100 / total))
  _coolbash_motd_pcent_color color "$pcent"
  _coolbash_motd_human_kb h_used "$used"
  _coolbash_motd_human_kb h_total "$total"
  printf "Mem: %s used of %s (${color}%s%%\e[0m)\n" "$h_used" "$h_total" "$pcent"
}

# FR : charge — /proc/loadavg et le nombre de cœurs (glob /sys, pas de nproc).
#      Rouge si la charge 1 min dépasse le nombre de cœurs, jaune à partir de la moitié.
_coolbash_motd_load() {
  local l1 l5 l15 _ cores=0 c color="" l1c
  if [[ -r /proc/loadavg ]]; then
    read -r l1 l5 l15 _ 2>/dev/null </proc/loadavg || return 0
    for c in /sys/devices/system/cpu/cpu[0-9]*; do [[ -d "$c" ]] && cores=$((cores + 1)); done
  else
    # FR : macOS — vm.loadavg et hw.ncpu, déjà lus par _coolbash_motd_darwin.
    read -r l1 l5 l15 _ <<<"${_coolbash_motd_sys[2]:-}"
    [[ "$l1" =~ ^[0-9]+\.[0-9]+$ ]] || return 0
    [[ "${_coolbash_motd_sys[1]:-}" =~ ^[0-9]+$ ]] && cores="${_coolbash_motd_sys[1]}"
  fi
  ((cores > 0)) || cores=1
  l1c="${l1/[.,]/}"
  l1c="${l1c#0}"
  l1c="${l1c:-0}" # 0.52 → 52 (centièmes)
  if ((10#$l1c >= cores * 100)); then color='\e[31m'; elif ((10#$l1c >= cores * 50)); then color='\e[33m'; fi
  local plural=""
  ((cores > 1)) && plural=s
  printf "Load: ${color}%s\e[0m %s %s (%d core%s)\n" "$l1" "$l5" "$l15" "$cores" "$plural"
}

# FR : batterie — /sys/class/power_supply/BAT*. Rouge sous 20 % en décharge, jaune sous 40.
_coolbash_motd_battery() {
  local b cap status color="" line
  # FR : macOS — « -InternalBattery-0 (id=…)	27%; charging; 2:54 remaining » ;
  #      un Mac de bureau n'a pas cette ligne.
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    [[ -x /usr/bin/pmset ]] || return 0
    while IFS= read -r line; do
      [[ "$line" == *InternalBattery* && "$line" =~ ([0-9]+)%\;\ ([^\;]+) ]] || continue
      cap="${BASH_REMATCH[1]}"
      status="${BASH_REMATCH[2]}"
      case "$status" in
        discharging) status=Discharging ;;
        charging) status=Charging ;;
        charged) status=Full ;;
        *) status="Not charging" ;;
      esac
      if [[ "$status" == Discharging ]]; then
        if ((cap < 20)); then color='\e[31m'; elif ((cap < 40)); then color='\e[33m'; fi
      fi
      printf "Battery: ${color}%s%%\e[0m (%s)\n" "$cap" "$status"
    done < <(/usr/bin/pmset -g batt 2>/dev/null)
    return 0
  fi
  for b in /sys/class/power_supply/BAT*; do
    read -r cap 2>/dev/null <"$b/capacity" || continue
    read -r status 2>/dev/null <"$b/status" || status="unknown"
    [[ "$cap" =~ ^[0-9]+$ ]] || continue
    if [[ "$status" == Discharging ]]; then
      if ((cap < 20)); then color='\e[31m'; elif ((cap < 40)); then color='\e[33m'; fi
    fi
    printf "Battery: ${color}%s%%\e[0m (%s)\n" "$cap" "$status"
  done
  return 0
}

# FR : redémarrage requis — Arch : le dossier des modules du noyau qui tourne a
#      disparu (le noyau a été mis à jour) ; Debian : /var/run/reboot-required.
#      Paramètres (tests) : $1 dossier des modules, $2 fichier drapeau.
# shellcheck disable=SC2120  # FR : les arguments servent aux tests
_coolbash_motd_reboot() {
  local modules="${1:-/usr/lib/modules}" flag="${2:-/var/run/reboot-required}" kernel="" d any=0
  if [[ -f "$flag" ]]; then
    printf '\e[31mReboot required\e[0m (%s)\n' "$flag"
    return 0
  fi
  read -r kernel 2>/dev/null </proc/sys/kernel/osrelease || return 0
  [[ -d "$modules" ]] || return 0
  for d in "$modules"/*/; do [[ -d "$d" ]] && any=1 && break; done
  ((any)) || return 0
  [[ -d "$modules/$kernel" ]] || printf '\e[31mReboot required\e[0m: kernel %s is running but its modules are gone (kernel updated)\n' "$kernel"
  return 0
}

# FR : unités systemd en échec — un seul systemctl (≈ 5 ms), affiché seulement si > 0.
_coolbash_motd_failed() {
  local unit _ names="" n=0
  command -v systemctl >/dev/null 2>&1 || return 0
  while read -r unit _; do
    [[ -n "$unit" ]] || continue
    n=$((n + 1))
    names+="${names:+, }$unit"
  done < <(systemctl --failed --no-legend --plain 2>/dev/null)
  ((n > 0)) && printf '\e[31mFailed units: %d\e[0m (%s)\n' "$n" "$names"
  return 0
}

# FR : mise à jour disponible — fichier .update-available écrit en arrière-plan
#      par la CLI (git fetch quotidien), lu ici sans processus.
_coolbash_motd_update() {
  local v
  read -r v 2>/dev/null <"${COOLBASH_PREFIX:-$HOME/.coolbash}/.update-available" || return 0
  [[ -n "$v" && "$v" != "${COOLBASH_VERSION:-}" ]] || return 0
  _coolbash_say '\e[33m⇡ CoolBash %s disponible\e[0m (installée : %s) → coolbash update · coolbash changelog --next\n' "$v" "${COOLBASH_VERSION:-?}"
}

# FR : ~/.coolbash/motd.png (ou .jpg) affiché par `img` (module 43-images) si le
#      terminal sait le faire ; silencieux sinon. COOLBASH_MOTD_IMAGE_WIDTH colonnes.
_coolbash_motd_image() {
  local f
  declare -F img >/dev/null 2>&1 || return 0
  for f in "${COOLBASH_PREFIX:-$HOME/.coolbash}"/motd.{png,jpg,jpeg,gif,webp}; do
    [[ -r "$f" ]] || continue
    img -w "${COOLBASH_MOTD_IMAGE_WIDTH:-40}" "$f" 2>/dev/null
    return 0
  done
  return 0
}

# FR : tâches ouvertes (todo add …), cinq au plus.
_coolbash_motd_todo() {
  local lines=() i
  [[ -s "${COOLBASH_PREFIX:-$HOME/.coolbash}/todo.txt" ]] || return 0
  _coolbash_readlines lines <"${COOLBASH_PREFIX:-$HOME/.coolbash}/todo.txt"
  _coolbash_say '\n\e[1mÀ faire\e[0m (todo) :\n'
  for i in "${!lines[@]}"; do
    ((i >= 5)) && {
      _coolbash_say '  … et %d autre(s)\n' $((${#lines[@]} - 5))
      break
    }
    printf '  \e[1m%2d\e[0m  %s\n' "$((i + 1))" "${lines[i]}"
  done
}

# FR : pense-bête personnel — ~/.coolbash/motd.txt, affiché tel quel.
_coolbash_motd_note() {
  local file="${COOLBASH_PREFIX:-$HOME/.coolbash}/motd.txt" lines=()
  [[ -s "$file" ]] || return 0
  _coolbash_readlines lines <"$file"
  printf '\n'
  printf '\e[36m%s\e[0m\n' "${lines[@]}"
}

# FR : disques — un seul `df -Phl` (local, format POSIX, lisible) : / toujours,
#      (même en overlay dans un conteneur), les autres partitions seulement à
#      partir de 80 % et seulement les vrais périphériques (/dev/…, sauf loop) :
#      pas de tmpfs, pas de snap.
#      Sans df (PATH réduit), pas de ligne.
#      macOS (APFS) : / est le volume système scellé (quelques Go, toujours) ; les
#      données sont sur /System/Volumes/Data, affiché comme « / ». Les autres
#      volumes système (VM, Preboot, simulateurs…) ne sont pas listés, et les
#      tailles perdent leur « i » (466Gi → 466G).
_coolbash_motd_disk() {
  local fs size used _ pcent mount p color data=0
  local -a rows=()
  command -v df >/dev/null 2>&1 || return 0
  _coolbash_readlines rows < <(df -Phl 2>/dev/null)
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    for _ in "${rows[@]}"; do [[ "$_" == *" /System/Volumes/Data" ]] && data=1; done
  fi
  while read -r fs size used _ pcent mount; do
    [[ "$pcent" =~ ^[0-9]+%$ ]] || continue
    p="${pcent%\%}"
    if [[ "${OSTYPE:-}" == darwin* ]]; then
      case "$mount" in
        /) ((data)) && continue ;;
        /System/Volumes/Data) mount=/ ;;
        /System/Volumes/* | /private/var/* | /Library/Developer/*) continue ;;
      esac
      size="${size%i}"
      used="${used%i}"
    fi
    # FR : / toujours (même overlay, en conteneur) ; sinon un vrai périphérique à ≥ 80 %.
    if [[ "$mount" != / ]]; then
      [[ "$fs" == /dev/* && "$fs" != /dev/loop* && "$p" -ge 80 ]] || continue
    fi
    _coolbash_motd_pcent_color color "$p"
    printf "Disk (%s): %s used of %s (${color}%s\e[0m)\n" "$mount" "$used" "$size" "$pcent"
  done < <(printf '%s\n' "${rows[@]}")
  return 0
}

# FR : « 1 day, 7 hours, 1 min » — le format de neofetch. $1 = variable de sortie.
_coolbash_motd_uptime() {
  local s="$2" d h m out=""
  d=$((s / 86400))
  h=$((s % 86400 / 3600))
  m=$((s % 3600 / 60))
  ((d > 0)) && {
    out="$d day"
    ((d > 1)) && out+=s
    out+=", "
  }
  ((h > 0)) && {
    out+="$h hour"
    ((h > 1)) && out+=s
    out+=", "
  }
  out+="$m min"
  ((m != 1)) && out+=s
  printf -v "$1" '%s' "$out"
}
_coolbash_motd
