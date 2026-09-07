# shellcheck shell=bash
#  ██████  ██████   █████  ███    ███ ██████  ███████
#  ██   ██ ██   ██ ██   ██ ████  ████ ██   ██    █
#  ██████  ██████  ██   ██ ██ ████ ██ ██████     █
#  ██      ██   ██ ██   ██ ██  ██  ██ ██         █
#  ██      ██   ██  █████  ██      ██ ██         █      MODULE: PROMPT
# ─────────────────────────────────────────────────────────────────────────────
# FR: Prompt dynamique (git, venv, durée, code retour, emoji), trap DEBUG sûr.

# --- Color helpers -----------------------------------------------------------
rgb()   { printf "\e[38;2;%s;%s;%sm" "$1" "$2" "$3"; }
bgrgb() { printf "\e[48;2;%s;%s;%sm" "$1" "$2" "$3"; }
reset="\[\e[0m\]"
bold="\[\e[1m\]"
blue="\[\e[1;34m\]"
yellow="\[\e[1;33m\]"

_supports_truecolor() { [[ "${COLORTERM:-}" =~ (24bit|truecolor) ]]; }

if _supports_truecolor; then
  user_fg="\[$(rgb 110 210 65)\]"
  user_accent="\[$(rgb 200 120 255)\]"
  git_fg="\[$(rgb 255 210 110)\]"
  time_fg="\[$(rgb 160 170 255)\]"
  err_bg="\[$(bgrgb 60 0 20)\]\[\e[97m\]"
  root_fg="\[$(rgb 255 110 110)\]"
  root_accent="\[$(rgb 255 170 80)\]"
else
  user_fg="\[\e[36m\]"
  user_accent="\[\e[35m\]"
  git_fg="\[\e[33m\]"
  time_fg="\[\e[34m\]"
  err_bg="\[\e[41m\]\[\e[97m\]"
  root_fg="\[\e[31m\]"
  root_accent="\[\e[91m\]"
fi

# --- Symbols -----------------------------------------------------------------
sym_branch=""
sym_time=""
sym_venv=""
sym_host=""
sym_user=""
sym_root="󰌾"

# --- Emojis ------------------------------------------------------------------
__EMOJIS_USER=(🐶 🐱 🐹 🐻 🦊 🐼 🐸 🦄 🐝 🦋 🐙 🐬 🐧 🦖 🐢 🐍 🌿 🌼 🌻 🌈 🚀)
__EMOJIS_ROOT=(👹 💀 🤖 🔧 🧯 🧱 🔥 🏴‍☠️ ⚙️ 🧪 🛠️ 🧰)
__choose_emoji() {
  if [[ $EUID -eq 0 ]]; then
    printf "%s" "${__EMOJIS_ROOT[RANDOM % ${#__EMOJIS_ROOT[@]}]}"
  else
    printf "%s" "${__EMOJIS_USER[RANDOM % ${#__EMOJIS_USER[@]}]}"
  fi
}
__BASHRC_EMOJI="$(__choose_emoji)"

# --- Git branch safe ---------------------------------------------------------
_git_branch() {
  command -v git >/dev/null 2>&1 || return
  git rev-parse --is-inside-work-tree &>/dev/null || return
  local b dirty=""
  b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  git diff --no-ext-diff --quiet --ignore-submodules --cached || dirty="*"
  git diff --no-ext-diff --quiet --ignore-submodules || dirty="${dirty}+"
  printf "%s%s" "$b" "$dirty"
}

# --- Safe venv name ----------------------------------------------------------
_venv_name() {
  local venv="${VIRTUAL_ENV:-}"
  [[ -n "$venv" ]] && basename "$venv"
}

# --- Exit code display -------------------------------------------------------
_last_status_segment() {
  local ec="${1:-0}"
  [[ "$ec" =~ ^[0-9]+$ ]] || ec=0
  (( ec == 0 )) && return
  printf "✖ %d" "$ec"
}

# --- Execution timer (safe, non-blocking) ------------------------------------
__TIMER_START=0

_start_timer() {
  # Ce trap ne relance pas _prompt_build lui-même (empêche la boucle infinie)
  [[ $BASH_COMMAND != "$PROMPT_COMMAND" ]] && __TIMER_START=$SECONDS
}

trap '_start_timer' DEBUG

_last_cmd_duration() {
  local dur=$(( SECONDS - __TIMER_START ))
  (( dur > 1 )) && printf "%ss" "$dur"
}

# --- Prompt builder ----------------------------------------------------------
_prompt_build() {
  local exit_code=$?
  local userpart hostpart git venv vn dur err
  userpart=""; hostpart=""; git=""; venv=""; vn=""; dur=""; err=""

  if [[ $EUID -eq 0 ]]; then
    userpart="${root_fg}${bold}${sym_root} root${reset}"
    hostpart="${root_accent}${yellow} ${sym_host} \h${reset}"
  else
    userpart="${user_fg}${bold}${sym_user} \u${reset}"
    hostpart="${user_accent}${yellow} ${sym_host} \h${reset}"
  fi

  local gb; gb=$(_git_branch 2>/dev/null)
  [[ -n "$gb" ]] && git=" ${git_fg}${sym_branch} ${gb}${reset}"

  vn=$(_venv_name 2>/dev/null)
  [[ -n "$vn" ]] && venv=" ${time_fg}${sym_venv} ${vn}${reset}"

  local d; d=$(_last_cmd_duration 2>/dev/null)
  [[ -n "$d" ]] && dur=" ${time_fg}${sym_time} ${d}${reset}"

  local st; st=$(_last_status_segment "$exit_code" 2>/dev/null)
  [[ -n "$st" ]] && err=" ${err_bg} ${st} ${reset}"

  local line1="${userpart} at ${hostpart}${git}${venv}${dur}${err}\n"
  local pathpart="${bold}${blue}\w${reset}"
  local chevron
  if [[ $EUID -eq 0 ]]; then chevron="${root_fg}#${reset}"; else chevron="${user_fg}\$${reset}"; fi

  PS1=$'\n'"${__BASHRC_EMOJI} \[\e[0;36m\][\t]\[\e[0;m\] ${line1}${pathpart} ${chevron} "
}

# --- Append safely to PROMPT_COMMAND ----------------------------------------
__append_prompt_command() {
  local fn="$1"
  if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
    local item
    for item in "${PROMPT_COMMAND[@]}"; do [[ "$item" == "$fn" ]] && return; done
    PROMPT_COMMAND+=("$fn")
  else
    [[ ":$PROMPT_COMMAND:" == *":$fn:"* ]] && return
    if [[ -n "${PROMPT_COMMAND:-}" ]]; then
      PROMPT_COMMAND="$fn; $PROMPT_COMMAND"
    else
      PROMPT_COMMAND="$fn"
    fi
  fi
}

__append_prompt_command "_prompt_build"
unset -f __append_prompt_command __choose_emoji
