# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # FR : variables posées par printf -v, lues par PS0/PS1
#  ██████  ██████   █████  ███    ███ ██████  ███████
#  ██   ██ ██   ██ ██   ██ ████  ████ ██   ██    █
#  ██████  ██████  ██   ██ ██ ████ ██ ██████     █
#  ██      ██   ██ ██   ██ ██  ██  ██ ██         █
#  ██      ██   ██  █████  ██      ██ ██         █      MODULE: PROMPT
# ─────────────────────────────────────────────────────────────────────────────
# FR: Prompt dynamique (git, venv, durée, code retour, emoji, icônes).
#     - Durée : PS0 + EPOCHREALTIME (bash ≥ 5), PS0 + SECONDS (bash 4.4), ou
#       l'horodatage de l'historique (bash 3.2 → 4.3, sans PS0) — zéro trap DEBUG.
#     - Git : un seul `git status --porcelain=v2 --branch`, sans verrou optionnel.
#     - PS0 (bash ≥ 4.4) : heure de départ en gris + commande dans le titre du terminal.
#     - Icônes : Nerd Font par défaut, repli « basic » (Unicode standard) ou 0.
#     - Hôte : icône et couleur selon le contexte (local, SSH, conteneur).
#     - Terminal : OSC 7 (dossier courant), OSC 133 (marques de prompt : saut de
#       prompt en prompt, sélection de la sortie d'une commande) et notification
#       après une commande longue.
#     - Niveau de shell (sous-shell, please, nix-shell) et jobs, stoppés à part.
#     - Outils : version php/node si composer.json/package.json (cache par binaire).
#     Réglages : COOLBASH_PROMPT_MIN_MS (défaut 1000), COOLBASH_PROMPT_GIT=0,
#                COOLBASH_PROMPT_GIT_UNTRACKED=0, COOLBASH_PS0_STAMP=0,
#                COOLBASH_PS0_TITLE=0, COOLBASH_PS0_EXTRA="…",
#                COOLBASH_PROMPT_ICONS=nerd|basic|0, COOLBASH_PS1_OSC7=0,
#                COOLBASH_PROMPT_BELL_MS (défaut 30000, 0 = jamais),
#                COOLBASH_PROMPT_TOOLS=0, PROMPT_DIRTRIM (défaut 3),
#                COOLBASH_PROMPT_PATH_FISH=0 (jamais d'abréviation ~/D/coolbash),
#                COOLBASH_PROMPT_TRANSIENT=1 (prompt réduit après l'Entrée, expérimental),
#                COOLBASH_PROMPT_CLOUD=0 (ni contexte kube ni profil AWS),
#                COOLBASH_PROMPT_PROD (motif « prod » qui passe le segment en rouge),
#                COOLBASH_PROMPT_OSC133=0 (pas de marques de prompt),
#                COOLBASH_PROMPT_SHLVL=0 (pas de niveau de shell).

# --- Couleurs & symboles -----------------------------------------------------
# FR : une variable par couleur et par icône — COOLBASH_PROMPT_COLOR_<nom>,
#      COOLBASH_PROMPT_SYM_<nom> — plutôt que deux tableaux associatifs, que le
#      bash 3.2 de macOS n'a pas.

# FR : jeu d'icônes du prompt. Trois modes :
#      - nerd  : glyphes Nerd Font (zones privées Unicode, écrits en octets
#                UTF-8 `\xNN` : lisibles dans le source, et bash < 4.2 ne
#                connaît pas `\uXXXX`) — il faut une Nerd Font dans le terminal ;
#      - basic : symboles Unicode standard, rendus par n'importe quelle police ;
#      - 0     : aucune icône.
#      Défaut : 0 sur la console (TERM=linux), basic en mode safe, nerd sinon —
#      sauf si `make install` n'a trouvé aucune Nerd Font (<prefix>/.nerdfont
#      vaut 1) : basic. En SSH ce fichier est ignoré, la police qui compte est
#      celle du poste qui affiche le terminal.
#      Une valeur explicite de COOLBASH_PROMPT_ICONS est toujours respectée ;
#      une valeur inconnue retombe sur basic.
_coolbash_prompt_init_icons() {
  local k
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
      #      nf-dev-php, nf-dev-nodejs_small, nf-fa-sitemap (niveau de shell).
      COOLBASH_PROMPT_SYM_user=$'\xef\x80\x87'      # U+F007
      COOLBASH_PROMPT_SYM_host=$'\xef\x84\x88'      # U+F108
      COOLBASH_PROMPT_SYM_branch=$'\xee\x9c\xa5'    # U+E725
      COOLBASH_PROMPT_SYM_venv=$'\xee\x9c\xbc'      # U+E73C
      COOLBASH_PROMPT_SYM_time=$'\xef\x89\x92'      # U+F252
      COOLBASH_PROMPT_SYM_path=$'\xef\x81\xbc'      # U+F07C
      COOLBASH_PROMPT_SYM_root=$'\xf3\xb0\x8c\xbe'  # U+F033E
      COOLBASH_PROMPT_SYM_clock=$'\xef\x80\x97'     # U+F017
      COOLBASH_PROMPT_SYM_err=$'\xef\x81\x97'       # U+F057
      COOLBASH_PROMPT_SYM_jobs=$'\xef\x80\x93'      # U+F013
      COOLBASH_PROMPT_SYM_ro=$'\xef\x80\xa3'        # U+F023
      COOLBASH_PROMPT_SYM_ssh=$'\xef\x87\xa6'       # U+F1E6
      COOLBASH_PROMPT_SYM_container=$'\xef\x86\xb2' # U+F1B2
      COOLBASH_PROMPT_SYM_php=$'\xee\x9c\xbd'       # U+E73D
      COOLBASH_PROMPT_SYM_node=$'\xee\x9c\x98'      # U+E718
      COOLBASH_PROMPT_SYM_rust=$'\xee\x9e\xa8'      # U+E7A8
      COOLBASH_PROMPT_SYM_kube=$'\xf3\xb1\x83\xbe'  # U+F10FE
      COOLBASH_PROMPT_SYM_aws=$'\xef\x89\xb0'       # U+F270
      COOLBASH_PROMPT_SYM_shlvl=$'\xef\x83\xa8'     # U+F0E8
      ;;
    0)
      for k in user host branch venv time path root clock err jobs ro ssh container php node rust kube aws shlvl; do printf -v "COOLBASH_PROMPT_SYM_$k" ''; done
      COOLBASH_PROMPT_SYM_err="✖" COOLBASH_PROMPT_SYM_jobs="⚙" COOLBASH_PROMPT_SYM_ro="⊘" COOLBASH_PROMPT_SYM_shlvl="⧉"
      ;;
    *)
      COOLBASH_PROMPT_ICONS=basic
      for k in user host branch venv time path root clock err jobs ro ssh container php node rust kube aws shlvl; do printf -v "COOLBASH_PROMPT_SYM_$k" ''; done
      COOLBASH_PROMPT_SYM_branch="⎇" COOLBASH_PROMPT_SYM_venv="⚗" COOLBASH_PROMPT_SYM_time="⧗" COOLBASH_PROMPT_SYM_root="⚠"
      COOLBASH_PROMPT_SYM_clock="⏱" COOLBASH_PROMPT_SYM_err="✖" COOLBASH_PROMPT_SYM_jobs="⚙" COOLBASH_PROMPT_SYM_ro="⊘"
      COOLBASH_PROMPT_SYM_ssh="⇄" COOLBASH_PROMPT_SYM_container="▣" COOLBASH_PROMPT_SYM_kube="⎈" COOLBASH_PROMPT_SYM_aws="☁"
      COOLBASH_PROMPT_SYM_shlvl="⧉"
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
    _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_host_hash ${pal[h % 8]}
  else
    COOLBASH_PROMPT_COLOR_host_hash="\[\e[$((31 + h % 6))m\]"
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
  local theme="${COOLBASH_PROMPT_THEME:-}" pal
  [[ -z "$theme" ]] && read -r theme 2>/dev/null <"${COOLBASH_PREFIX:-$HOME/.coolbash}/theme"
  theme="${theme:-coolbash}"
  [[ "$theme" == mono ]] || _coolbash_prompt_theme_palette "$theme" >/dev/null || theme=coolbash
  COOLBASH_PROMPT_THEME_ACTIVE="$theme"
  COOLBASH_PROMPT_COLOR_reset='\[\e[0m\]'
  COOLBASH_PROMPT_COLOR_bold='\[\e[1m\]'
  COOLBASH_PROMPT_COLOR_path='\[\e[1;34m\]'
  COOLBASH_PROMPT_COLOR_time='\[\e[0;36m\]'
  if [[ "$theme" == mono ]]; then
    COOLBASH_PROMPT_COLOR_user='' COOLBASH_PROMPT_COLOR_user_accent='' COOLBASH_PROMPT_COLOR_git='' COOLBASH_PROMPT_COLOR_info='' COOLBASH_PROMPT_COLOR_root='\[\e[1m\]' COOLBASH_PROMPT_COLOR_root_accent='\[\e[1m\]'
    COOLBASH_PROMPT_COLOR_path='\[\e[1m\]' COOLBASH_PROMPT_COLOR_time='' COOLBASH_PROMPT_COLOR_err='\[\e[7m\]'
    return 0
  fi
  if [[ "${COLORTERM:-}" =~ (24bit|truecolor) ]]; then
    pal="$(_coolbash_prompt_theme_palette "$theme")"
    local -a t
    IFS='|' read -ra t <<<"$pal"
    # shellcheck disable=SC2086
    {
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_user ${t[0]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_user_accent ${t[1]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_git ${t[2]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_info ${t[3]}
      _coolbash_prompt_bgrgb COOLBASH_PROMPT_COLOR_err ${t[4]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_root ${t[5]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_root_accent ${t[6]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_path ${t[7]}
      _coolbash_prompt_rgb COOLBASH_PROMPT_COLOR_time ${t[8]}
    }
    COOLBASH_PROMPT_COLOR_err+='\[\e[97m\]'
    COOLBASH_PROMPT_COLOR_path="${COOLBASH_PROMPT_COLOR_bold}${COOLBASH_PROMPT_COLOR_path}"
  else
    COOLBASH_PROMPT_COLOR_user='\[\e[36m\]'
    COOLBASH_PROMPT_COLOR_user_accent='\[\e[35m\]'
    COOLBASH_PROMPT_COLOR_git='\[\e[33m\]'
    COOLBASH_PROMPT_COLOR_info='\[\e[34m\]'
    COOLBASH_PROMPT_COLOR_err='\[\e[41m\]\[\e[97m\]'
    COOLBASH_PROMPT_COLOR_root='\[\e[31m\]'
    COOLBASH_PROMPT_COLOR_root_accent='\[\e[91m\]'
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
#      Trois horloges, selon ce que le bash sait faire :
#        realtime  bash ≥ 5.0 : PS0 + EPOCHREALTIME, à la microseconde ;
#        seconds   bash 4.4   : PS0 + SECONDS, à la seconde ;
#        history   bash < 4.4 (dont le 3.2 de macOS) : pas de PS0 — ni heure sous
#                  la commande, ni titre, ni prompt transient. La durée vient de
#                  l'horodatage que l'historique garde de chaque commande, à la
#                  seconde ; une commande que l'historique ignore (doublon,
#                  espace en tête) n'a pas de durée.
COOLBASH_PROMPT_T0=0
COOLBASH_PROMPT_LAST_MS=0
COOLBASH_PROMPT_PS0_SINK=()
if ((COOLBASH_BASH >= 500)) && [[ -n "${EPOCHREALTIME:-}" ]]; then
  COOLBASH_PROMPT_CLOCK=realtime
elif ((COOLBASH_BASH >= 404)); then
  COOLBASH_PROMPT_CLOCK=seconds
else
  COOLBASH_PROMPT_CLOCK=history
  COOLBASH_PROMPT_HIST_N=""
  # FR : époque du lancement du shell : « maintenant » = cette base + SECONDS,
  #      sans lancer date à chaque prompt.
  _coolbash_date COOLBASH_PROMPT_EPOCH0 %s
  COOLBASH_PROMPT_EPOCH0=$((COOLBASH_PROMPT_EPOCH0 - SECONDS))
fi

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
  local ps0
  # shellcheck disable=SC2016  # FR : PS0 est développé plus tard, à chaque Entrée
  case "$COOLBASH_PROMPT_CLOCK" in
    realtime) ps0='${COOLBASH_PROMPT_PS0_SINK[$((COOLBASH_PROMPT_T0 = ${EPOCHREALTIME//[.,]/}))]:+}' ;;
    seconds) ps0='${COOLBASH_PROMPT_PS0_SINK[$((COOLBASH_PROMPT_T0 = SECONDS * 1000000 + 1))]:+}' ;;
    *) return 0 ;;
  esac
  # shellcheck disable=SC2016
  [[ "${COOLBASH_PROMPT_TRANSIENT:-0}" == 1 ]] && ps0+='$(_coolbash_prompt_transient)'
  if [[ "${COOLBASH_PS0_TITLE:-1}" != 0 ]] && _coolbash_prompt_term_has_title; then
    # shellcheck disable=SC2016
    ps0+='$(_coolbash_prompt_ps0_title)'
  fi
  # FR : OSC 133 C = « la sortie de la commande commence ici ».
  _coolbash_prompt_osc133_wanted && ps0+='\e]133;C\a'
  [[ "${COOLBASH_PS0_STAMP:-1}" != 0 ]] && ps0+='\e[2m  ⏱ \t\e[0m\n'
  PS0="${ps0}${COOLBASH_PS0_EXTRA:-}"
}

_coolbash_prompt_term_has_title() {
  case "${TERM:-}" in
    xterm* | rxvt* | tmux* | screen* | alacritty* | foot* | kitty* | wezterm* | contour*) return 0 ;;
    *) return 1 ;;
  esac
}

# FR : OSC 133 (intégration shell : kitty, foot, wezterm, ghostty, VTE récents,
#      iTerm2) : A = début du prompt, B = fin du prompt (la saisie commence),
#      C = début de la sortie, D;code = fin de commande. Le terminal sait alors
#      sauter de prompt en prompt (kitty : ctrl+shift+z/x, foot : ctrl+shift+z),
#      sélectionner la sortie d'une commande d'un clic, ou colorer la marge
#      selon le code retour. Pas émis si le terminal injecte déjà la sienne
#      (kitty avec shell_integration, VTE avec vte.sh), ni sur un terminal sans
#      titre (console, dumb). COOLBASH_PROMPT_OSC133=0 désactive.
_coolbash_prompt_osc133_wanted() {
  [[ "${COOLBASH_PROMPT_OSC133:-1}" != 0 ]] || return 1
  if [[ -n "${KITTY_SHELL_INTEGRATION:-}" && "${KITTY_SHELL_INTEGRATION}" != *disabled* && "${KITTY_SHELL_INTEGRATION}" != *no-prompt-mark* ]]; then
    return 1
  fi
  [[ "${PROMPT_COMMAND[*]}" == *__vte_prompt_command* ]] && return 1
  _coolbash_prompt_term_has_title
}
_coolbash_prompt_ps0_build

_coolbash_prompt_elapsed() {
  local now n t _
  case "$COOLBASH_PROMPT_CLOCK" in
    realtime) now="${EPOCHREALTIME//[.,]/}" ;;
    seconds) now=$((SECONDS * 1000000 + 1)) ;;
    *)
      # FR : « 501  1763711111 commande » — une entrée déjà vue au prompt précédent
      #      (Entrée à vide) ne compte pas, ni la première (elle vient d'une autre session).
      COOLBASH_PROMPT_LAST_MS=0
      read -r n t _ <<<"$(HISTTIMEFORMAT='%s ' builtin history 1 2>/dev/null)"
      [[ "$n" =~ ^[0-9]+$ && "$t" =~ ^[0-9]+$ ]] || return 0
      if [[ -n "$COOLBASH_PROMPT_HIST_N" && "$n" != "$COOLBASH_PROMPT_HIST_N" ]]; then
        now=$(((COOLBASH_PROMPT_EPOCH0 + SECONDS - t) * 1000))
        # FR : l'historique date à la seconde : une commande de 0,2 s à cheval
        #      sur deux secondes « dure » 1 s. En dessous de 2 s, on ne dit rien.
        ((now >= 2000)) && COOLBASH_PROMPT_LAST_MS=$now
      fi
      COOLBASH_PROMPT_HIST_N="$n"
      return 0
      ;;
  esac
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
  elif [[ "${COOLBASH_PROMPT_CLOCK:-}" == history ]]; then
    # FR : bash < 4.4 : mesure à la seconde près, pas de fausses décimales.
    printf '%ds' $((ms / 1000))
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
  printf '%s %s' "${COOLBASH_PROMPT_SYM_err:-✖}" "$what"
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
#      Les jobs stoppés (Ctrl-Z) sont comptés à part : « ⚙ 2 ⏸1 » — c'est
#      celui qu'on oublie et qui bloque la fermeture du terminal.
_coolbash_prompt_jobs() {
  local -a j s
  # shellcheck disable=SC2207
  j=($(jobs -p))
  ((${#j[@]})) || return 0
  # shellcheck disable=SC2207
  s=($(jobs -sp))
  printf '%s %d' "${COOLBASH_PROMPT_SYM_jobs:-⚙}" "${#j[@]}"
  ((${#s[@]})) && printf ' ⏸%d' "${#s[@]}"
  return 0
}

# FR : niveau de shell — dans un sous-shell (bash lancé à la main, please,
#      nix-shell, :terminal de vim), on l'oublie vite et on ferme le mauvais.
#      Référence : le SHLVL du premier shell CoolBash de la lignée (exporté) ;
#      le segment n'apparaît qu'au-delà : « ⧉ 2 » = un niveau sous le premier.
#      COOLBASH_PROMPT_SHLVL=0 désactive.
[[ -n "${COOLBASH_SHLVL_BASE:-}" ]] || export COOLBASH_SHLVL_BASE="${SHLVL:-1}"
_coolbash_prompt_shlvl() {
  [[ "${COOLBASH_PROMPT_SHLVL:-1}" == 0 ]] && return 0
  local d=$((${SHLVL:-1} - ${COOLBASH_SHLVL_BASE:-1}))
  ((d > 0)) && printf '%s %d' "${COOLBASH_PROMPT_SYM_shlvl:-⧉}" "$((d + 1))"
  return 0
}

# --- Outils : php / node, détectés par fichier, version en cache -------------
# FR : un seul lancement par binaire et par session (clé = chemin résolu, donc
#      nvm qui change de node est vu). Le résultat est écrit dans la variable
#      passée en argument, pas sur stdout : une substitution `$(…)` perdrait
#      le cache à chaque prompt. Désactivé en mode safe.
# FR : le cache = deux tableaux parallèles (binaire, version) : trois entrées au
#      plus, et le bash 3.2 de macOS n'a pas de tableau associatif.
COOLBASH_PROMPT_TOOL_BINS=()
COOLBASH_PROMPT_TOOL_VERS=()
_coolbash_prompt_tool_version() {
  # FR : les locaux sont préfixés `_tvr_` — la sortie est écrite dans la variable
  #      nommée par $2, un local homonyme la masquerait.
  local _tvr_tool="$1" _tvr_bin _tvr_val="" _tvr_i _tvr_cmd="$1"
  printf -v "$2" ''
  [[ "$_tvr_tool" == rust ]] && _tvr_cmd=rustc
  _tvr_bin="$(command -v "$_tvr_cmd" 2>/dev/null)" || return 1
  [[ -n "$_tvr_bin" ]] || return 1
  for ((_tvr_i = 0; _tvr_i < ${#COOLBASH_PROMPT_TOOL_BINS[@]}; _tvr_i++)); do
    [[ "${COOLBASH_PROMPT_TOOL_BINS[_tvr_i]}" == "$_tvr_bin" ]] || continue
    printf -v "$2" '%s' "${COOLBASH_PROMPT_TOOL_VERS[_tvr_i]}"
    return 0
  done
  case "$_tvr_tool" in
    php) _tvr_val="$("$_tvr_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)" ;;
    node)
      _tvr_val="$("$_tvr_bin" --version 2>/dev/null)"
      _tvr_val="${_tvr_val#v}"
      _tvr_val="${_tvr_val%.*}"
      ;;
    rust)
      # FR : « rustc 1.80.0 (abc 2024-07-21) » → 1.80
      _tvr_val="$("$_tvr_bin" --version 2>/dev/null)"
      _tvr_val="${_tvr_val#rustc }"
      _tvr_val="${_tvr_val%% *}"
      _tvr_val="${_tvr_val%.*}"
      ;;
  esac
  COOLBASH_PROMPT_TOOL_BINS[${#COOLBASH_PROMPT_TOOL_BINS[@]}]="$_tvr_bin"
  COOLBASH_PROMPT_TOOL_VERS[${#COOLBASH_PROMPT_TOOL_VERS[@]}]="$_tvr_val"
  printf -v "$2" '%s' "$_tvr_val"
}
# FR : rust-toolchain.toml (channel = "1.79.0") ou rust-toolchain (une ligne) du
#      projet : la version voulue, sans lancer rustc. $1 = variable de sortie.
_coolbash_prompt_rust_toolchain() {
  local _rt_line _rt_v=""
  printf -v "$1" ''
  if [[ -r rust-toolchain.toml ]]; then
    while IFS= read -r _rt_line; do
      [[ "$_rt_line" == *channel* ]] && {
        _rt_v="${_rt_line#*=}"
        break
      }
    done <rust-toolchain.toml
  elif [[ -r rust-toolchain ]]; then
    read -r _rt_v <rust-toolchain
  fi
  _rt_v="${_rt_v//[\"\' ]/}"
  [[ -n "$_rt_v" ]] || return 1
  [[ "$_rt_v" =~ ^[0-9]+\.[0-9]+ ]] && _rt_v="${BASH_REMATCH[0]}"
  printf -v "$1" '%s' "$_rt_v"
}

# _coolbash_prompt_tools <variable de sortie>
_coolbash_prompt_tools() {
  local _tout="" _tv _ttool _tfile _tsym
  printf -v "$1" ''
  [[ "${COOLBASH_PROMPT_TOOLS:-1}" == 0 ]] && return 0
  _coolbash_safe && return 0
  for _ttool in php node rust; do
    case "$_ttool" in php) _tfile=composer.json ;; node) _tfile=package.json ;; rust) _tfile=Cargo.toml ;; esac
    [[ -f "$_tfile" ]] || continue
    if [[ "$_ttool" == rust ]] && _coolbash_prompt_rust_toolchain _tv; then :; else
      _coolbash_prompt_tool_version "$_ttool" _tv || continue
    fi
    [[ -n "$_tv" ]] || continue
    _tsym="COOLBASH_PROMPT_SYM_$_ttool"
    _tout+="${_tout:+  }${!_tsym:-$_ttool} ${_tv}"
  done
  printf -v "$1" '%s' "$_tout"
}

# FR : contexte cloud — Kubernetes (current-context du kubeconfig, lu en pur
#      bash) et profil AWS (AWS_PROFILE ou AWS_VAULT). Rouge et gras quand le nom
#      contient COOLBASH_PROMPT_PROD (« prod »). COOLBASH_PROMPT_CLOUD=0 cache.
#      $1 = variable de sortie ; locaux préfixés _cl_ pour ne pas la masquer.
_coolbash_prompt_cloud() {
  local _cl_out="" _cl_sym
  printf -v "$1" ''
  [[ "${COOLBASH_PROMPT_CLOUD:-1}" == 0 ]] && return 0
  local _cl_file="${KUBECONFIG:-$HOME/.kube/config}" _cl_line _cl_ctx="" _cl_aws="${AWS_PROFILE:-${AWS_VAULT:-}}" _cl_seg _cl_col _cl_kind _cl_val
  _cl_file="${_cl_file%%:*}"
  if [[ -r "$_cl_file" ]]; then
    while IFS= read -r _cl_line; do
      [[ "$_cl_line" == current-context:* ]] && {
        _cl_ctx="${_cl_line#current-context:}"
        _cl_ctx="${_cl_ctx//[\"\' ]/}"
        break
      }
    done <"$_cl_file"
  fi
  for _cl_seg in "kube:$_cl_ctx" "aws:$_cl_aws"; do
    _cl_kind="${_cl_seg%%:*}"
    _cl_val="${_cl_seg#*:}"
    [[ -n "$_cl_val" ]] || continue
    _cl_col="${COOLBASH_PROMPT_COLOR_info}"
    [[ "$_cl_val" == *"${COOLBASH_PROMPT_PROD:-prod}"* ]] && _cl_col="${COOLBASH_PROMPT_COLOR_root}${COOLBASH_PROMPT_COLOR_bold}"
    _cl_sym="COOLBASH_PROMPT_SYM_$_cl_kind"
    _cl_out+="${_cl_out:+  }${_cl_col}${!_cl_sym:-$_cl_kind} ${_cl_val}${COOLBASH_PROMPT_COLOR_reset}"
  done
  printf -v "$1" '%s' "$_cl_out"
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
  printf '%s' '\[\a\e]777;notify;CoolBash;'"${cmd:-$(_coolbash_t 'Commande terminée')} · ${dur}"'\a\]'
}

# --- Construction du prompt --------------------------------------------------
_coolbash_prompt_build() {
  local ec=$?
  _coolbash_prompt_elapsed
  local who host chevron clock hicon hcolor ro="" git="" venv="" tools="" cloud="" dur="" jobs="" lvl="" err="" seg mark_a="" mark_b=""
  # FR : `${COOLBASH_PROMPT_SYM_x:+${COOLBASH_PROMPT_SYM_x} }` — icône suivie d'une espace, ou rien du tout
  #      (mode 0) : jamais d'espace orpheline. L'icône d'hôte (écran, prise,
  #      cube) déborde de sa cellule : deux espaces, sinon elle touche le nom.
  #      L'heure garde ses crochets seulement sans icône.
  clock='[\t]'
  [[ -n "${COOLBASH_PROMPT_SYM_clock}" ]] && clock="${COOLBASH_PROMPT_SYM_clock} \t"
  case "${COOLBASH_PROMPT_HOST_KIND:-local}" in
    ssh)
      hicon="${COOLBASH_PROMPT_SYM_ssh}"
      hcolor="${COOLBASH_PROMPT_COLOR_host_hash}"
      ;;
    container)
      hicon="${COOLBASH_PROMPT_SYM_container}"
      hcolor="${COOLBASH_PROMPT_COLOR_host_hash}"
      ;;
    *)
      hicon="${COOLBASH_PROMPT_SYM_host}"
      hcolor="${COOLBASH_PROMPT_COLOR_user_accent}"
      ;;
  esac
  if [[ $EUID -eq 0 ]]; then
    who="${COOLBASH_PROMPT_COLOR_root}${COOLBASH_PROMPT_COLOR_bold}${COOLBASH_PROMPT_SYM_root:+${COOLBASH_PROMPT_SYM_root} }root${COOLBASH_PROMPT_COLOR_reset}"
    [[ "${COOLBASH_PROMPT_HOST_KIND:-local}" == local ]] && hcolor="${COOLBASH_PROMPT_COLOR_root_accent}"
    chevron="${COOLBASH_PROMPT_COLOR_root}#${COOLBASH_PROMPT_COLOR_reset}"
  else
    who="${COOLBASH_PROMPT_COLOR_user}${COOLBASH_PROMPT_COLOR_bold}${COOLBASH_PROMPT_SYM_user:+${COOLBASH_PROMPT_SYM_user} }\u${COOLBASH_PROMPT_COLOR_reset}"
    # FR : chevron rouge après un échec — le repère le plus rapide.
    if ((ec == 0)); then chevron="${COOLBASH_PROMPT_COLOR_user}\$${COOLBASH_PROMPT_COLOR_reset}"; else chevron="${COOLBASH_PROMPT_COLOR_root}\$${COOLBASH_PROMPT_COLOR_reset}"; fi
  fi
  host="${hcolor} ${hicon:+${hicon}  }\h${COOLBASH_PROMPT_COLOR_reset}"
  [[ -w "$PWD" ]] || ro="${COOLBASH_PROMPT_SYM_ro:+${COOLBASH_PROMPT_SYM_ro} }"
  local wpath='\w'
  if [[ "${COOLBASH_PROMPT_PATH_FISH:-1}" != 0 ]]; then
    _coolbash_prompt_path_fish seg
    [[ -n "$seg" ]] && wpath="$seg"
  fi
  seg="$(_coolbash_prompt_git)"
  [[ -n "$seg" ]] && git=" ${COOLBASH_PROMPT_COLOR_git}${COOLBASH_PROMPT_SYM_branch:+${COOLBASH_PROMPT_SYM_branch} }${seg}${COOLBASH_PROMPT_COLOR_reset}"
  seg="$(_coolbash_prompt_venv)"
  [[ -n "$seg" ]] && venv=" ${COOLBASH_PROMPT_COLOR_info}${COOLBASH_PROMPT_SYM_venv:+${COOLBASH_PROMPT_SYM_venv} }${seg}${COOLBASH_PROMPT_COLOR_reset}"
  _coolbash_prompt_tools seg
  [[ -n "$seg" ]] && tools=" ${COOLBASH_PROMPT_COLOR_info}${seg}${COOLBASH_PROMPT_COLOR_reset}"
  _coolbash_prompt_cloud seg
  [[ -n "$seg" ]] && cloud=" ${seg}"
  seg="$(_coolbash_prompt_duration)"
  [[ -n "$seg" ]] && dur=" ${COOLBASH_PROMPT_COLOR_info}${COOLBASH_PROMPT_SYM_time:+${COOLBASH_PROMPT_SYM_time} }${seg}${COOLBASH_PROMPT_COLOR_reset}"
  seg="$(_coolbash_prompt_jobs)"
  [[ -n "$seg" ]] && jobs=" ${COOLBASH_PROMPT_COLOR_info}${seg}${COOLBASH_PROMPT_COLOR_reset}"
  seg="$(_coolbash_prompt_shlvl)"
  [[ -n "$seg" ]] && lvl=" ${COOLBASH_PROMPT_COLOR_info}${seg}${COOLBASH_PROMPT_COLOR_reset}"
  seg="$(_coolbash_prompt_status "$ec")"
  [[ -n "$seg" ]] && err=" ${COOLBASH_PROMPT_COLOR_err} ${seg} ${COOLBASH_PROMPT_COLOR_reset}"
  # FR : OSC 133 — D;code ferme la commande précédente, A ouvre le prompt, B le clôt.
  if _coolbash_prompt_osc133_wanted; then
    mark_a='\[\e]133;D;'"${ec}"'\a\e]133;A\a\]'
    mark_b='\[\e]133;B\a\]'
  fi
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
  PS1="${mark_a}${title}"$'\n'"${COOLBASH_PROMPT_EMOJI:+${COOLBASH_PROMPT_EMOJI} }${COOLBASH_PROMPT_COLOR_time}${clock}${COOLBASH_PROMPT_COLOR_reset} ${who} at ${host}${git}${venv}${tools}${cloud}${dur}${jobs}${lvl}${err}"$'\n'"${COOLBASH_PROMPT_COLOR_bold}${COOLBASH_PROMPT_COLOR_path}${ro}${COOLBASH_PROMPT_SYM_path:+${COOLBASH_PROMPT_SYM_path} }${wpath}${COOLBASH_PROMPT_COLOR_reset} ${chevron} ${mark_b}"
}

# --- Enregistrement dans PROMPT_COMMAND (helper commun de 00-core) -----------
_coolbash_prompt_command_add _coolbash_prompt_build
unset -f _coolbash_prompt_pick_emoji _coolbash_prompt_init_colors _coolbash_prompt_init_icons _coolbash_prompt_init_host _coolbash_prompt_rgb _coolbash_prompt_bgrgb _coolbash_prompt_ps0_build _coolbash_prompt_theme_palette
