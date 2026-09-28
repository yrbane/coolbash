# shellcheck shell=bash
# shellcheck disable=SC2154,SC2178,SC2034  # FR : faux positifs des namerefs (local -n) et de PS0
#  ██████  ██████   █████  ███    ███ ██████  ███████
#  ██   ██ ██   ██ ██   ██ ████  ████ ██   ██    █
#  ██████  ██████  ██   ██ ██ ████ ██ ██████     █
#  ██      ██   ██ ██   ██ ██  ██  ██ ██         █
#  ██      ██   ██  █████  ██      ██ ██         █      MODULE: PROMPT
# ─────────────────────────────────────────────────────────────────────────────
# FR: Prompt dynamique (git, venv, durée, code retour, emoji, icônes).
#     - Durée : PS0 + EPOCHREALTIME (bash ≥ 4.4), zéro trap DEBUG.
#     - Git : un seul `git status --porcelain=v2 --branch`, sans verrou optionnel.
#     - PS0 : heure de départ en gris + commande dans le titre du terminal.
#     - Icônes : Nerd Font par défaut, repli « basic » (Unicode standard) ou 0.
#     - Hôte : icône et couleur selon le contexte (local, SSH, conteneur).
#     - Terminal : OSC 7 (dossier courant) et notification après une commande longue.
#     - Outils : version php/node si composer.json/package.json (cache par binaire).
#     Réglages : COOLBASH_PROMPT_MIN_MS (défaut 1000), COOLBASH_PROMPT_GIT=0,
#                COOLBASH_PROMPT_GIT_UNTRACKED=0, COOLBASH_PS0_STAMP=0,
#                COOLBASH_PS0_TITLE=0, COOLBASH_PS0_EXTRA="…",
#                COOLBASH_PROMPT_ICONS=nerd|basic|0, COOLBASH_PS1_OSC7=0,
#                COOLBASH_PROMPT_BELL_MS (défaut 30000, 0 = jamais),
#                COOLBASH_PROMPT_TOOLS=0, PROMPT_DIRTRIM (défaut 3),
#                COOLBASH_PROMPT_PATH_FISH=0 (jamais d'abréviation ~/D/coolbash),
#                COOLBASH_PROMPT_TRANSIENT=1 (prompt réduit après l'Entrée, expérimental).

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  return 0
fi

# --- Couleurs & symboles -----------------------------------------------------
declare -gA COOLBASH_PROMPT_COLOR COOLBASH_PROMPT_SYM

# FR : jeu d'icônes du prompt. Trois modes :
#      - nerd  : glyphes Nerd Font (zones privées Unicode, écrits en `\uXXXX`
#                pour rester lisibles dans le source) — il faut une Nerd Font
#                dans le terminal ;
#      - basic : symboles Unicode standard, rendus par n'importe quelle police ;
#      - 0     : aucune icône.
#      Défaut : 0 sur la console (TERM=linux), basic en mode safe, nerd sinon —
#      sauf si `make install` n'a trouvé aucune Nerd Font (<prefix>/.nerdfont
#      vaut 1) : basic. En SSH ce fichier est ignoré, la police qui compte est
#      celle du poste qui affiche le terminal.
#      Une valeur explicite de COOLBASH_PROMPT_ICONS est toujours respectée ;
#      une valeur inconnue retombe sur basic.
_coolbash_prompt_init_icons() {
  local -n s=COOLBASH_PROMPT_SYM
  if [[ -z "${COOLBASH_PROMPT_ICONS:-}" ]]; then
    if [[ "${TERM:-}" == linux ]]; then
      COOLBASH_PROMPT_ICONS=0
    elif _coolbash_safe; then
      COOLBASH_PROMPT_ICONS=basic
    else
      local font=""
      COOLBASH_PROMPT_ICONS=nerd
      if [[ -z "${SSH_CONNECTION:-}${SSH_TTY:-}${SSH_CLIENT:-}" ]] \
        && read -r font 2>/dev/null <"${COOLBASH_PREFIX:-$HOME/.coolbash}/.nerdfont" && [[ "$font" == 1 ]]; then
        COOLBASH_PROMPT_ICONS=basic
      fi
    fi
  fi
  case "${COOLBASH_PROMPT_ICONS}" in
    nerd)
      # FR : nf-fa-user, nf-fa-desktop, nf-dev-git_branch, nf-dev-python,
      #      nf-fa-hourglass_half, nf-fa-folder_open, nf-md-lock, nf-fa-clock_o,
      #      nf-fa-times_circle, nf-fa-cog, nf-fa-lock, nf-fa-plug, nf-fa-cube,
      #      nf-dev-php, nf-dev-nodejs_small.
      s=([user]=$'\uf007' [host]=$'\uf108' [branch]=$'\ue725' [venv]=$'\ue73c'
        [time]=$'\uf252' [path]=$'\uf07c' [root]=$'\U000f033e'
        [clock]=$'\uf017' [err]=$'\uf057' [jobs]=$'\uf013' [ro]=$'\uf023'
        [ssh]=$'\uf1e6' [container]=$'\uf1b2' [php]=$'\ue73d' [node]=$'\ue718')
      ;;
    0)
      s=([user]="" [host]="" [branch]="" [venv]="" [time]="" [path]="" [root]=""
        [clock]="" [err]="✖" [jobs]="⚙" [ro]="⊘" [ssh]="" [container]="" [php]="" [node]="")
      ;;
    *)
      COOLBASH_PROMPT_ICONS=basic
      s=([user]="" [host]="" [branch]="⎇" [venv]="⚗" [time]="⧗" [path]="" [root]="⚠"
        [clock]="⏱" [err]="✖" [jobs]="⚙" [ro]="⊘" [ssh]="⇄" [container]="▣" [php]="" [node]="")
      ;;
  esac
}
_coolbash_prompt_init_icons

# FR : `\w` ne garde que les 3 derniers dossiers (« …/a/b/c »). Réglage bash
#      natif, respecté s'il est déjà défini.
PROMPT_DIRTRIM="${PROMPT_DIRTRIM:-3}"

# --- Hôte : local, SSH ou conteneur ------------------------------------------
# FR : calculé une fois au chargement. En SSH, la couleur de l'hôte dérive de
#      son nom : chaque serveur garde sa couleur d'une session à l'autre, on
#      les distingue d'un coup d'œil. En local, accent fixe. Les marqueurs de
#      conteneur sont surchargeables (tests).
_coolbash_prompt_init_host() {
  local -n c=COOLBASH_PROMPT_COLOR
  local m h=0 i name="${HOSTNAME:-localhost}"
  COOLBASH_PROMPT_HOST_KIND=local
  for m in ${COOLBASH_PROMPT_CONTAINER_MARKERS:-/.dockerenv /run/.containerenv}; do
    [[ -e "$m" ]] && {
      COOLBASH_PROMPT_HOST_KIND=container
      break
    }
  done
  if [[ "${COOLBASH_PROMPT_HOST_KIND}" == local && -n "${SSH_CONNECTION:-}${SSH_TTY:-}${SSH_CLIENT:-}" ]]; then
    COOLBASH_PROMPT_HOST_KIND=ssh
  fi
  for ((i = 0; i < ${#name}; i++)); do
    printf -v m '%d' "'${name:i:1}"
    h=$(((h * 31 + m) % 65521))
  done
  if [[ "${COLORTERM:-}" =~ (24bit|truecolor) ]]; then
    local -a pal=("255 120 120" "255 180 80" "220 220 90" "120 220 120" "90 200 220" "150 150 255" "230 130 230" "255 150 190")
    # shellcheck disable=SC2086
    _coolbash_prompt_rgb 'c[host_hash]' ${pal[h % 8]}
  else
    c[host_hash]="\[\e[$((31 + h % 6))m\]"
  fi
}

# FR : $1 = variable (ou élément de tableau) de sortie — pas de sous-shell,
#      chaque $(…) coûtait ≈ 1 ms au démarrage.
_coolbash_prompt_rgb() { printf -v "$1" '\[\e[38;2;%s;%s;%sm\]' "$2" "$3" "$4"; }
_coolbash_prompt_bgrgb() { printf -v "$1" '\[\e[48;2;%s;%s;%sm\]' "$2" "$3" "$4"; }

# FR : palettes truecolor — user|accent|git|info|fond erreur|root|accent root|chemin|heure.
#      COOLBASH_PROMPT_THEME, sinon le fichier ~/.coolbash/theme (écrit par
#      `coolbash theme <nom>`), sinon coolbash. `mono` : gras et vidéo inverse,
#      aucune couleur. Sur un terminal sans truecolor, seuls coolbash et mono changent.
_coolbash_prompt_theme_palette() {
  case "$1" in
    nord) printf '%s' "163 190 140|180 142 173|235 203 139|136 192 208|191 97 106|191 97 106|208 135 112|129 161 193|143 188 187" ;;
    dracula) printf '%s' "80 250 123|189 147 249|241 250 140|139 233 253|255 85 85|255 85 85|255 184 108|255 121 198|98 114 164" ;;
    solarized) printf '%s' "133 153 0|108 113 196|181 137 0|42 161 152|220 50 47|220 50 47|203 75 22|38 139 210|147 161 161" ;;
    gruvbox) printf '%s' "184 187 38|211 134 155|250 189 47|131 165 152|204 36 29|251 73 52|254 128 25|131 165 152|168 153 132" ;;
    coolbash) printf '%s' "110 210 65|200 120 255|255 210 110|160 170 255|60 0 20|255 110 110|255 170 80|80 150 255|90 200 200" ;;
    *) return 1 ;;
  esac
}

_coolbash_prompt_init_colors() {
  local -n c=COOLBASH_PROMPT_COLOR
  local theme="${COOLBASH_PROMPT_THEME:-}" pal
  [[ -z "$theme" ]] && read -r theme 2>/dev/null <"${COOLBASH_PREFIX:-$HOME/.coolbash}/theme"
  theme="${theme:-coolbash}"
  [[ "$theme" == mono ]] || _coolbash_prompt_theme_palette "$theme" >/dev/null || theme=coolbash
  COOLBASH_PROMPT_THEME_ACTIVE="$theme"
  c[reset]='\[\e[0m\]'
  c[bold]='\[\e[1m\]'
  c[path]='\[\e[1;34m\]'
  c[time]='\[\e[0;36m\]'
  if [[ "$theme" == mono ]]; then
    c[user]='' c[user_accent]='' c[git]='' c[info]='' c[root]='\[\e[1m\]' c[root_accent]='\[\e[1m\]'
    c[path]='\[\e[1m\]' c[time]='' c[err]='\[\e[7m\]'
    return 0
  fi
  if [[ "${COLORTERM:-}" =~ (24bit|truecolor) ]]; then
    pal="$(_coolbash_prompt_theme_palette "$theme")"
    local -a t
    IFS='|' read -ra t <<<"$pal"
    # shellcheck disable=SC2086
    {
      _coolbash_prompt_rgb 'c[user]' ${t[0]}
      _coolbash_prompt_rgb 'c[user_accent]' ${t[1]}
      _coolbash_prompt_rgb 'c[git]' ${t[2]}
      _coolbash_prompt_rgb 'c[info]' ${t[3]}
      _coolbash_prompt_bgrgb 'c[err]' ${t[4]}
      _coolbash_prompt_rgb 'c[root]' ${t[5]}
      _coolbash_prompt_rgb 'c[root_accent]' ${t[6]}
      _coolbash_prompt_rgb 'c[path]' ${t[7]}
      _coolbash_prompt_rgb 'c[time]' ${t[8]}
    }
    c[err]+='\[\e[97m\]'
    c[path]="${c[bold]}${c[path]}"
  else
    c[user]='\[\e[36m\]'
    c[user_accent]='\[\e[35m\]'
    c[git]='\[\e[33m\]'
    c[info]='\[\e[34m\]'
    c[err]='\[\e[41m\]\[\e[97m\]'
    c[root]='\[\e[31m\]'
    c[root_accent]='\[\e[91m\]'
  fi
}
_coolbash_prompt_init_colors
_coolbash_prompt_init_host

# --- Emoji de session --------------------------------------------------------
_coolbash_prompt_pick_emoji() {
  local -a pool
  if [[ $EUID -eq 0 ]]; then
    pool=(👹 💀 🤖 🔧 🧯 🧱 🔥 🏴‍☠️ ⚙️ 🧪 🛠️ 🧰)
  else pool=(🐶 🐱 🐹 🐻 🦊 🐼 🐸 🦄 🐝 🦋 🐙 🐬 🐧 🦖 🐢 🐍 🌿 🌼 🌻 🌈 🚀); fi
  printf '%s' "${pool[RANDOM % ${#pool[@]}]}"
}
# FR: mode safe → pas d'emoji, pas de git (sauf réglage explicite).
if _coolbash_safe; then
  COOLBASH_PROMPT_EMOJI="${COOLBASH_PROMPT_EMOJI-}"
  COOLBASH_PROMPT_GIT="${COOLBASH_PROMPT_GIT-0}"
else
  COOLBASH_PROMPT_EMOJI="${COOLBASH_PROMPT_EMOJI-$(_coolbash_prompt_pick_emoji)}"
fi

# --- PS0 : développé à l'Entrée, juste avant l'exécution de la commande -------
# FR : trois rôles, dans cet ordre :
#      1. top départ du chrono : l'affectation arithmétique placée dans un
#         indice de tableau persiste dans le shell courant, et `${…:+}` garantit
#         qu'elle n'affiche rien. EPOCHREALTIME suit le séparateur décimal de
#         la locale (« . » ou « , »), d'où le nettoyage ;
#      2. titre du terminal = commande en cours (COOLBASH_PS0_TITLE=0 pour
#         désactiver) ; PS1 le remet ensuite à « user@host: dossier » ;
#      3. heure réelle de départ en gris (COOLBASH_PS0_STAMP=0 pour désactiver),
#         car l'heure du prompt date de son affichage, pas de l'Entrée.
#      COOLBASH_PS0_EXTRA est ajouté tel quel à la fin (PS0 personnel).
#      Pas de `\[ \]` ici : hors PS1/PS2, bash les imprimerait.
COOLBASH_PROMPT_T0=0
COOLBASH_PROMPT_LAST_MS=0
COOLBASH_PROMPT_PS0_SINK=()

_coolbash_prompt_ps0_title() {
  local n cmd
  read -r n cmd <<<"$(HISTTIMEFORMAT='' builtin history 1)"
  [[ -n "${cmd:-}" ]] || return 0
  printf '\e]0;%s\a' "${cmd:0:70}"
}

# FR : chemin courant avec ~, abrégé façon fish (~/D/coolbash/modules) quand il
#      dépasse la moitié du terminal : chaque dossier réduit à sa première lettre
#      (deux pour un dossier caché), le dernier entier. $1 = variable de sortie ;
#      vide = chemin court, garder \w (et PROMPT_DIRTRIM).
_coolbash_prompt_path_fish() {
  local p="$PWD" last out="" part
  local -a parts
  [[ -n "${HOME:-}" && "$p" == "$HOME"* ]] && p="~${p#"$HOME"}"
  if ((${#p} <= ${COLUMNS:-80} / 2)); then
    printf -v "$1" ''
    return 0
  fi
  last="${p##*/}"
  IFS='/' read -ra parts <<<"${p%/*}"
  for part in "${parts[@]}"; do
    case "$part" in
      "" | "~") out+="$part/" ;;
      .*) out+="${part:0:2}/" ;;
      *) out+="${part:0:1}/" ;;
    esac
  done
  out+="$last"
  # FR : PS1 est ré-expansé : pas d'antislash ni de $ nus dans un chemin.
  out="${out//\\/\\\\}"
  out="${out//\$/\\\$}"
  printf -v "$1" '%s' "$out"
}

# FR : prompt transient (COOLBASH_PROMPT_TRANSIENT=1, expérimental) : à l'Entrée,
#      les deux lignes du prompt sont effacées et remplacées par « chemin $ commande »
#      sur une seule ligne — un écran d'historique compact. Le nombre de lignes à
#      remonter est calculé (largeur du terminal), pas mesuré : approximatif avec
#      des glyphes larges ou une commande sur plusieurs lignes.
_coolbash_prompt_transient() {
  local n cmd path lines cols="${COLUMNS:-80}"
  read -r n cmd <<<"$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)"
  COLUMNS=1 _coolbash_prompt_path_fish path
  path="${path//\\\\/\\}"
  path="${path//\\\$/\$}"
  lines=$((2 + (${#path} + 3 + ${#cmd}) / cols))
  printf '\e[%dA\r\e[J\e[1m%s\e[0m $ %s\n' "$lines" "$path" "${cmd:-}"
}

_coolbash_prompt_ps0_build() {
  # shellcheck disable=SC2016
  local ps0='${COOLBASH_PROMPT_PS0_SINK[$((COOLBASH_PROMPT_T0 = ${EPOCHREALTIME//[.,]/}))]:+}'
  # shellcheck disable=SC2016
  [[ "${COOLBASH_PROMPT_TRANSIENT:-0}" == 1 ]] && ps0+='$(_coolbash_prompt_transient)'
  if [[ "${COOLBASH_PS0_TITLE:-1}" != 0 ]] && _coolbash_prompt_term_has_title; then
    # shellcheck disable=SC2016
    ps0+='$(_coolbash_prompt_ps0_title)'
  fi
  [[ "${COOLBASH_PS0_STAMP:-1}" != 0 ]] && ps0+='\e[2m  ⏱ \t\e[0m\n'
  PS0="${ps0}${COOLBASH_PS0_EXTRA:-}"
}

_coolbash_prompt_term_has_title() {
  case "${TERM:-}" in
    xterm* | rxvt* | tmux* | screen* | alacritty* | foot* | kitty* | wezterm* | contour*) return 0 ;;
    *) return 1 ;;
  esac
}
_coolbash_prompt_ps0_build

_coolbash_prompt_elapsed() {
  local now="${EPOCHREALTIME//[.,]/}"
  if ((COOLBASH_PROMPT_T0 > 0)); then
    COOLBASH_PROMPT_LAST_MS=$(((now - COOLBASH_PROMPT_T0) / 1000))
  else
    COOLBASH_PROMPT_LAST_MS=0
  fi
  COOLBASH_PROMPT_T0=0
}

_coolbash_prompt_duration() {
  local ms="${COOLBASH_PROMPT_LAST_MS:-0}" min="${COOLBASH_PROMPT_MIN_MS:-1000}"
  ((ms >= min)) || return 0
  if ((ms >= 60000)); then
    printf '%dm%02ds' $((ms / 60000)) $((ms % 60000 / 1000))
  else
    printf '%d.%02ds' $((ms / 1000)) $((ms % 1000 / 10))
  fi
}

# --- Git : un seul appel, jamais de verrou -----------------------------------
_coolbash_prompt_git() {
  [[ "${COOLBASH_PROMPT_GIT:-1}" == 0 ]] && return 0
  command -v git >/dev/null 2>&1 || return 0
  local -a opts=(--porcelain=v2 --branch --show-stash)
  [[ "${COOLBASH_PROMPT_GIT_UNTRACKED:-1}" == 0 ]] && opts+=(-uno)
  local line head="" oid="" ahead=0 behind=0 stash=0 staged=0 unstaged=0 untracked=0 conflict=0
  while IFS= read -r line; do
    case "$line" in
      "# branch.head "*) head="${line#"# branch.head "}" ;;
      "# branch.oid "*) oid="${line#"# branch.oid "}" ;;
      "# branch.ab "*)
        line="${line#"# branch.ab +"}"
        ahead="${line%% *}"
        behind="${line##*-}"
        ;;
      "# stash "*) stash="${line#"# stash "}" ;;
      "1 "* | "2 "*)
        [[ "${line:2:1}" != "." ]] && staged=1
        [[ "${line:3:1}" != "." ]] && unstaged=1
        ;;
      "? "*) untracked=1 ;;
      "u "*) conflict=1 ;;
    esac
  done < <(GIT_OPTIONAL_LOCKS=0 git status "${opts[@]}" 2>/dev/null)
  [[ -n "$head" ]] || return 0
  [[ "$head" == "(detached)" ]] && head="${oid:0:7}"
  local flags=""
  ((staged)) && flags+="*"
  ((unstaged)) && flags+="+"
  ((untracked)) && flags+="?"
  ((conflict)) && flags+="!"
  ((ahead)) && flags+="↑${ahead}"
  ((behind)) && flags+="↓${behind}"
  ((stash)) && flags+="≡${stash}"
  printf '%s%s' "$head" "$flags"
}

# --- Segments simples --------------------------------------------------------
# FR : 128 + n = tué par le signal n ; on affiche son nom quand il est connu.
_coolbash_prompt_status() {
  local ec="${1:-0}" what
  [[ "$ec" =~ ^[0-9]+$ ]] || return 0
  ((ec == 0)) && return 0
  case "$ec" in
    129) what=HUP ;; 130) what=INT ;; 131) what=QUIT ;; 134) what=ABRT ;;
    137) what=KILL ;; 139) what=SEGV ;; 141) what=PIPE ;; 143) what=TERM ;;
    *) what="$ec" ;;
  esac
  printf '%s %s' "${COOLBASH_PROMPT_SYM[err]:-✖}" "$what"
}

_coolbash_prompt_venv() {
  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    printf '%s' "${VIRTUAL_ENV##*/}"
  elif [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
    printf '%s' "${CONDA_DEFAULT_ENV}"
  fi
  return 0
}

# FR : `jobs -p` dans une substitution voit bien les jobs du shell courant.
_coolbash_prompt_jobs() {
  local -a j
  # shellcheck disable=SC2207
  j=($(jobs -p))
  ((${#j[@]})) && printf '%s %d' "${COOLBASH_PROMPT_SYM[jobs]:-⚙}" "${#j[@]}"
  return 0
}

# --- Outils : php / node, détectés par fichier, version en cache -------------
# FR : un seul lancement par binaire et par session (clé = chemin résolu, donc
#      nvm qui change de node est vu). Le résultat est écrit dans la variable
#      passée en argument, pas sur stdout : une substitution `$(…)` perdrait
#      le cache à chaque prompt. Désactivé en mode safe.
declare -gA COOLBASH_PROMPT_TOOL_CACHE
_coolbash_prompt_tool_version() {
  # FR : les locaux sont préfixés `_tvr_` — une nameref se résout dans la portée
  #      courante, un local homonyme masquerait la variable de l'appelant.
  local -n _tvr_valr_out="$2"
  local _tvr_valr_tool="$1" _tvr_valr_bin _tvr_val
  _tvr_valr_out=""
  _tvr_valr_bin="$(command -v "$_tvr_valr_tool" 2>/dev/null)" || return 1
  [[ -n "$_tvr_valr_bin" ]] || return 1
  if [[ -z "${COOLBASH_PROMPT_TOOL_CACHE[$_tvr_valr_bin]+x}" ]]; then
    case "$_tvr_valr_tool" in
      php) _tvr_val="$("$_tvr_valr_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)" ;;
      node)
        _tvr_val="$("$_tvr_valr_bin" --version 2>/dev/null)"
        _tvr_val="${_tvr_val#v}"
        _tvr_val="${_tvr_val%.*}"
        ;;
    esac
    COOLBASH_PROMPT_TOOL_CACHE[$_tvr_valr_bin]="$_tvr_val"
  fi
  _tvr_valr_out="${COOLBASH_PROMPT_TOOL_CACHE[$_tvr_valr_bin]}"
}
# _coolbash_prompt_tools <variable de sortie>
_coolbash_prompt_tools() {
  local -n _tout="$1"
  _tout=""
  [[ "${COOLBASH_PROMPT_TOOLS:-1}" == 0 ]] && return 0
  _coolbash_safe && return 0
  local -n _tsym=COOLBASH_PROMPT_SYM
  local _tv _ttool _tfile
  for _ttool in php node; do
    case "$_ttool" in php) _tfile=composer.json ;; node) _tfile=package.json ;; esac
    [[ -f "$_tfile" ]] || continue
    _coolbash_prompt_tool_version "$_ttool" _tv || continue
    [[ -n "$_tv" ]] || continue
    _tout+="${_tout:+  }${_tsym[$_ttool]:-$_ttool} ${_tv}"
  done
}

# --- Terminal : OSC 7 et notification ----------------------------------------
# FR : OSC 7 = « le dossier courant est … » ; un nouvel onglet (foot, kitty,
#      wezterm, VTE) s'ouvre alors au même endroit. Chemin encodé octet par
#      octet (LC_ALL=C), ce qui couvre l'UTF-8.
_coolbash_prompt_osc7() {
  local LC_ALL=C path="$PWD" out="" i c
  for ((i = 0; i < ${#path}; i++)); do
    c="${path:i:1}"
    case "$c" in
      [A-Za-z0-9/_.~-]) out+="$c" ;;
      *)
        printf -v c '%%%02X' "'$c"
        out+="$c"
        ;;
    esac
  done
  printf '%s' '\[\e]7;file://'"${HOSTNAME:-localhost}${out}"'\a\]'
}
# FR : après une commande longue : sonnerie (urgence dans la plupart des
#      terminaux) + OSC 777 (notification bureau : foot, urxvt, VTE récents).
_coolbash_prompt_notify() {
  local ms="${COOLBASH_PROMPT_LAST_MS:-0}" min="${COOLBASH_PROMPT_BELL_MS:-30000}" n cmd dur
  ((min > 0 && ms >= min)) || return 0
  read -r n cmd <<<"$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)"
  dur="$(COOLBASH_PROMPT_MIN_MS=0 _coolbash_prompt_duration)"
  printf '%s' '\[\a\e]777;notify;CoolBash;'"${cmd:-Commande terminée} · ${dur}"'\a\]'
}

# --- Construction du prompt --------------------------------------------------
_coolbash_prompt_build() {
  local ec=$?
  _coolbash_prompt_elapsed
  local -n c=COOLBASH_PROMPT_COLOR s=COOLBASH_PROMPT_SYM
  local who host chevron clock hicon hcolor ro="" git="" venv="" tools="" dur="" jobs="" err="" seg
  # FR : `${s[x]:+${s[x]} }` — icône suivie d'une espace, ou rien du tout
  #      (mode 0) : jamais d'espace orpheline. L'icône d'hôte (écran, prise,
  #      cube) déborde de sa cellule : deux espaces, sinon elle touche le nom.
  #      L'heure garde ses crochets seulement sans icône.
  clock='[\t]'
  [[ -n "${s[clock]}" ]] && clock="${s[clock]} \t"
  case "${COOLBASH_PROMPT_HOST_KIND:-local}" in
    ssh)
      hicon="${s[ssh]}"
      hcolor="${c[host_hash]}"
      ;;
    container)
      hicon="${s[container]}"
      hcolor="${c[host_hash]}"
      ;;
    *)
      hicon="${s[host]}"
      hcolor="${c[user_accent]}"
      ;;
  esac
  if [[ $EUID -eq 0 ]]; then
    who="${c[root]}${c[bold]}${s[root]:+${s[root]} }root${c[reset]}"
    [[ "${COOLBASH_PROMPT_HOST_KIND:-local}" == local ]] && hcolor="${c[root_accent]}"
    chevron="${c[root]}#${c[reset]}"
  else
    who="${c[user]}${c[bold]}${s[user]:+${s[user]} }\u${c[reset]}"
    # FR : chevron rouge après un échec — le repère le plus rapide.
    if ((ec == 0)); then chevron="${c[user]}\$${c[reset]}"; else chevron="${c[root]}\$${c[reset]}"; fi
  fi
  host="${hcolor} ${hicon:+${hicon}  }\h${c[reset]}"
  [[ -w "$PWD" ]] || ro="${s[ro]:+${s[ro]} }"
  local wpath='\w'
  if [[ "${COOLBASH_PROMPT_PATH_FISH:-1}" != 0 ]]; then
    _coolbash_prompt_path_fish seg
    [[ -n "$seg" ]] && wpath="$seg"
  fi
  seg="$(_coolbash_prompt_git)"
  [[ -n "$seg" ]] && git=" ${c[git]}${s[branch]:+${s[branch]} }${seg}${c[reset]}"
  seg="$(_coolbash_prompt_venv)"
  [[ -n "$seg" ]] && venv=" ${c[info]}${s[venv]:+${s[venv]} }${seg}${c[reset]}"
  _coolbash_prompt_tools seg
  [[ -n "$seg" ]] && tools=" ${c[info]}${seg}${c[reset]}"
  seg="$(_coolbash_prompt_duration)"
  [[ -n "$seg" ]] && dur=" ${c[info]}${s[time]:+${s[time]} }${seg}${c[reset]}"
  seg="$(_coolbash_prompt_jobs)"
  [[ -n "$seg" ]] && jobs=" ${c[info]}${seg}${c[reset]}"
  seg="$(_coolbash_prompt_status "$ec")"
  [[ -n "$seg" ]] && err=" ${c[err]} ${seg} ${c[reset]}"
  # FR : titre remis par PS1, sauf si la distribution le fait déjà dans
  #      PROMPT_COMMAND (Arch : /etc/bash.bashrc écrit \033]0;…).
  local title=""
  if _coolbash_prompt_term_has_title; then
    if [[ "${COOLBASH_PS0_TITLE:-1}" != 0 && "${PROMPT_COMMAND[*]}" != *']0;'* ]]; then
      title='\[\e]0;\u@\h: \w\a\]'
      # FR : après une commande longue, le titre garde son nom, son sort et sa
      #      durée jusqu'au prochain prompt : on voit de loin quel onglet a fini.
      local min="${COOLBASH_PROMPT_BELL_MS:-30000}"
      if ((min > 0 && COOLBASH_PROMPT_LAST_MS >= min)); then
        local n cmd dur mark='✔'
        ((ec != 0)) && mark='✘'
        read -r n cmd <<<"$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)"
        dur="$(COOLBASH_PROMPT_MIN_MS=0 _coolbash_prompt_duration)"
        cmd="${cmd//\\/}"
        cmd="${cmd//\$/\\\$}"
        title='\[\e]0;'"${mark} ${cmd:0:60} · ${dur}"'\a\]'
      fi
    fi
    [[ "${COOLBASH_PS1_OSC7:-1}" != 0 ]] && title+="$(_coolbash_prompt_osc7)"
    title+="$(_coolbash_prompt_notify)"
  fi
  PS1="${title}"$'\n'"${COOLBASH_PROMPT_EMOJI:+${COOLBASH_PROMPT_EMOJI} }${c[time]}${clock}${c[reset]} ${who} at ${host}${git}${venv}${tools}${dur}${jobs}${err}"$'\n'"${c[bold]}${c[path]}${ro}${s[path]:+${s[path]} }${wpath}${c[reset]} ${chevron} "
}

# --- Enregistrement dans PROMPT_COMMAND (helper commun de 00-core) -----------
_coolbash_prompt_command_add _coolbash_prompt_build
unset -f _coolbash_prompt_pick_emoji _coolbash_prompt_init_colors _coolbash_prompt_init_icons _coolbash_prompt_init_host _coolbash_prompt_rgb _coolbash_prompt_bgrgb _coolbash_prompt_ps0_build _coolbash_prompt_theme_palette
