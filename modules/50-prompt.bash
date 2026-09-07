# shellcheck shell=bash
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
#     Réglages : COOLBASH_PROMPT_MIN_MS (défaut 1000), COOLBASH_PROMPT_GIT=0,
#                COOLBASH_PROMPT_GIT_UNTRACKED=0, COOLBASH_PS0_STAMP=0,
#                COOLBASH_PS0_TITLE=0, COOLBASH_PS0_EXTRA="…",
#                COOLBASH_PROMPT_ICONS=nerd|basic|0.

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
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
#      Défaut : 0 sur la console (TERM=linux), basic en mode safe, nerd sinon.
#      Une valeur explicite de COOLBASH_PROMPT_ICONS est toujours respectée ;
#      une valeur inconnue retombe sur basic.
_coolbash_prompt_init_icons() {
  local -n s=COOLBASH_PROMPT_SYM
  if [[ -z "${COOLBASH_PROMPT_ICONS:-}" ]]; then
    if [[ "${TERM:-}" == linux ]]; then COOLBASH_PROMPT_ICONS=0
    elif _coolbash_safe; then COOLBASH_PROMPT_ICONS=basic
    else COOLBASH_PROMPT_ICONS=nerd
    fi
  fi
  case "${COOLBASH_PROMPT_ICONS}" in
    nerd)
      # FR : nf-fa-user, nf-fa-desktop, nf-dev-git_branch, nf-dev-python,
      #      nf-fa-hourglass_half, nf-fa-folder_open, nf-md-lock.
      s=([user]=$'\uf007' [host]=$'\uf108' [branch]=$'\ue725' [venv]=$'\ue73c'
         [time]=$'\uf252' [path]=$'\uf07c' [root]=$'\U000f033e') ;;
    0)
      s=([user]="" [host]="" [branch]="" [venv]="" [time]="" [path]="" [root]="") ;;
    *)
      COOLBASH_PROMPT_ICONS=basic
      s=([user]="" [host]="" [branch]="⎇" [venv]="⚗" [time]="⧗" [path]="" [root]="⚠") ;;
  esac
}
_coolbash_prompt_init_icons

_coolbash_prompt_rgb()   { printf '\[\e[38;2;%s;%s;%sm\]' "$1" "$2" "$3"; }
_coolbash_prompt_bgrgb() { printf '\[\e[48;2;%s;%s;%sm\]' "$1" "$2" "$3"; }

_coolbash_prompt_init_colors() {
  local -n c=COOLBASH_PROMPT_COLOR
  c[reset]='\[\e[0m\]'; c[bold]='\[\e[1m\]'; c[path]='\[\e[1;34m\]'; c[time]='\[\e[0;36m\]'
  if [[ "${COLORTERM:-}" =~ (24bit|truecolor) ]]; then
    c[user]="$(_coolbash_prompt_rgb 110 210 65)"
    c[user_accent]="$(_coolbash_prompt_rgb 200 120 255)"
    c[git]="$(_coolbash_prompt_rgb 255 210 110)"
    c[info]="$(_coolbash_prompt_rgb 160 170 255)"
    c[err]="$(_coolbash_prompt_bgrgb 60 0 20)\[\e[97m\]"
    c[root]="$(_coolbash_prompt_rgb 255 110 110)"
    c[root_accent]="$(_coolbash_prompt_rgb 255 170 80)"
  else
    c[user]='\[\e[36m\]'; c[user_accent]='\[\e[35m\]'; c[git]='\[\e[33m\]'; c[info]='\[\e[34m\]'
    c[err]='\[\e[41m\]\[\e[97m\]'; c[root]='\[\e[31m\]'; c[root_accent]='\[\e[91m\]'
  fi
}
_coolbash_prompt_init_colors

# --- Emoji de session --------------------------------------------------------
_coolbash_prompt_pick_emoji() {
  local -a pool
  if [[ $EUID -eq 0 ]]; then pool=(👹 💀 🤖 🔧 🧯 🧱 🔥 🏴‍☠️ ⚙️ 🧪 🛠️ 🧰)
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
  read -r n cmd <<< "$(HISTTIMEFORMAT='' builtin history 1)"
  [[ -n "${cmd:-}" ]] || return 0
  printf '\e]0;%s\a' "${cmd:0:70}"
}

_coolbash_prompt_ps0_build() {
  # shellcheck disable=SC2016
  local ps0='${COOLBASH_PROMPT_PS0_SINK[$((COOLBASH_PROMPT_T0 = ${EPOCHREALTIME//[.,]/}))]:+}'
  if [[ "${COOLBASH_PS0_TITLE:-1}" != 0 ]] && _coolbash_prompt_term_has_title; then
    # shellcheck disable=SC2016
    ps0+='$(_coolbash_prompt_ps0_title)'
  fi
  [[ "${COOLBASH_PS0_STAMP:-1}" != 0 ]] && ps0+='\e[2m  ⏱ \t\e[0m\n'
  PS0="${ps0}${COOLBASH_PS0_EXTRA:-}"
}

_coolbash_prompt_term_has_title() {
  case "${TERM:-}" in
    xterm*|rxvt*|tmux*|screen*|alacritty*|foot*|kitty*|wezterm*|contour*) return 0 ;;
    *) return 1 ;;
  esac
}
_coolbash_prompt_ps0_build

_coolbash_prompt_elapsed() {
  local now="${EPOCHREALTIME//[.,]/}"
  if (( COOLBASH_PROMPT_T0 > 0 )); then
    COOLBASH_PROMPT_LAST_MS=$(( (now - COOLBASH_PROMPT_T0) / 1000 ))
  else
    COOLBASH_PROMPT_LAST_MS=0
  fi
  COOLBASH_PROMPT_T0=0
}

_coolbash_prompt_duration() {
  local ms="${COOLBASH_PROMPT_LAST_MS:-0}" min="${COOLBASH_PROMPT_MIN_MS:-1000}"
  (( ms >= min )) || return 0
  if (( ms >= 60000 )); then
    printf '%dm%02ds' $(( ms / 60000 )) $(( ms % 60000 / 1000 ))
  else
    printf '%d.%02ds' $(( ms / 1000 )) $(( ms % 1000 / 10 ))
  fi
}

# --- Git : un seul appel, jamais de verrou -----------------------------------
_coolbash_prompt_git() {
  [[ "${COOLBASH_PROMPT_GIT:-1}" == 0 ]] && return 0
  command -v git >/dev/null 2>&1 || return 0
  local -a opts=(--porcelain=v2 --branch)
  [[ "${COOLBASH_PROMPT_GIT_UNTRACKED:-1}" == 0 ]] && opts+=(-uno)
  local line head="" oid="" ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflict=0
  while IFS= read -r line; do
    case "$line" in
      "# branch.head "*) head="${line#"# branch.head "}" ;;
      "# branch.oid "*)  oid="${line#"# branch.oid "}" ;;
      "# branch.ab "*)   line="${line#"# branch.ab +"}"; ahead="${line%% *}"; behind="${line##*-}" ;;
      "1 "*|"2 "*)       [[ "${line:2:1}" != "." ]] && staged=1
                         [[ "${line:3:1}" != "." ]] && unstaged=1 ;;
      "? "*)             untracked=1 ;;
      "u "*)             conflict=1 ;;
    esac
  done < <(GIT_OPTIONAL_LOCKS=0 git status "${opts[@]}" 2>/dev/null)
  [[ -n "$head" ]] || return 0
  [[ "$head" == "(detached)" ]] && head="${oid:0:7}"
  local flags=""
  (( staged ))    && flags+="*"
  (( unstaged ))  && flags+="+"
  (( untracked )) && flags+="?"
  (( conflict ))  && flags+="!"
  (( ahead ))     && flags+="↑${ahead}"
  (( behind ))    && flags+="↓${behind}"
  printf '%s%s' "$head" "$flags"
}

# --- Segments simples --------------------------------------------------------
_coolbash_prompt_status() {
  local ec="${1:-0}"
  [[ "$ec" =~ ^[0-9]+$ ]] || return 0
  (( ec == 0 )) && return 0
  printf '✖ %d' "$ec"
}

_coolbash_prompt_venv() { [[ -n "${VIRTUAL_ENV:-}" ]] && printf '%s' "${VIRTUAL_ENV##*/}"; return 0; }

# --- Construction du prompt --------------------------------------------------
_coolbash_prompt_build() {
  local ec=$?
  _coolbash_prompt_elapsed
  local -n c=COOLBASH_PROMPT_COLOR s=COOLBASH_PROMPT_SYM
  local who host chevron git="" venv="" dur="" err="" seg
  # FR : `${s[x]:+${s[x]} }` — icône suivie d'une espace, ou rien du tout
  #      (mode 0) : jamais d'espace orpheline.
  if [[ $EUID -eq 0 ]]; then
    who="${c[root]}${c[bold]}${s[root]:+${s[root]} }root${c[reset]}"
    host="${c[root_accent]} ${s[host]:+${s[host]} }\h${c[reset]}"
    chevron="${c[root]}#${c[reset]}"
  else
    who="${c[user]}${c[bold]}${s[user]:+${s[user]} }\u${c[reset]}"
    host="${c[user_accent]} ${s[host]:+${s[host]} }\h${c[reset]}"
    chevron="${c[user]}\$${c[reset]}"
  fi
  seg="$(_coolbash_prompt_git)";       [[ -n "$seg" ]] && git=" ${c[git]}${s[branch]:+${s[branch]} }${seg}${c[reset]}"
  seg="$(_coolbash_prompt_venv)";      [[ -n "$seg" ]] && venv=" ${c[info]}${s[venv]:+${s[venv]} }${seg}${c[reset]}"
  seg="$(_coolbash_prompt_duration)";  [[ -n "$seg" ]] && dur=" ${c[info]}${s[time]:+${s[time]} }${seg}${c[reset]}"
  seg="$(_coolbash_prompt_status "$ec")"; [[ -n "$seg" ]] && err=" ${c[err]} ${seg} ${c[reset]}"
  # FR : titre remis par PS1, sauf si la distribution le fait déjà dans
  #      PROMPT_COMMAND (Arch : /etc/bash.bashrc écrit \033]0;…).
  local title=""
  if [[ "${COOLBASH_PS0_TITLE:-1}" != 0 && "${PROMPT_COMMAND[*]}" != *']0;'* ]] && _coolbash_prompt_term_has_title; then
    title='\[\e]0;\u@\h: \w\a\]'
  fi
  PS1="${title}"$'\n'"${COOLBASH_PROMPT_EMOJI:+${COOLBASH_PROMPT_EMOJI} }${c[time]}[\t]${c[reset]} ${who} at ${host}${git}${venv}${dur}${err}"$'\n'"${c[bold]}${c[path]}${s[path]:+${s[path]} }\w${c[reset]} ${chevron} "
}

# --- Enregistrement dans PROMPT_COMMAND (helper commun de 00-core) -----------
_coolbash_prompt_command_add _coolbash_prompt_build
unset -f _coolbash_prompt_pick_emoji _coolbash_prompt_init_colors _coolbash_prompt_init_icons _coolbash_prompt_rgb _coolbash_prompt_bgrgb _coolbash_prompt_ps0_build
