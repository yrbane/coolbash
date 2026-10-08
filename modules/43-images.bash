# shellcheck shell=bash
#  ██ ███    ███  ██████
#  ██ ████  ████ ██
#  ██ ██ ████ ██ ██   ███
#  ██ ██  ██  ██ ██    ██
#  ██ ██      ██  ██████   MODULE: IMAGES
# ─────────────────────────────────────────────────────────────────────────────
# FR: img [-w colonnes] <fichier…> — afficher une image dans le terminal, par
#     la meilleure méthode disponible :
#       kitty   protocole graphique de kitty (kitty, ghostty, konsole récent,
#               wezterm) — PNG envoyé en base64, le reste converti par magick,
#               ou `kitten icat` s'il est là ;
#       iterm   protocole iTerm2 (iTerm2, WezTerm, mintty) ;
#       sixel   foot, xterm, mlterm, contour — img2sixel ou magick ;
#       chafa   repli en caractères (chafa, sinon viu, sinon timg).
#     COOLBASH_IMG=kitty|iterm|sixel|chafa force la méthode. Sous tmux, les
#     séquences kitty/iTerm2 sont enveloppées (passthrough).
#     MOTD : ~/.coolbash/motd.png est affiché à l'ouverture s'il existe.

_coolbash_safe && return 0

unalias img 2>/dev/null

# FR : quelle méthode pour ce terminal ? $1 = variable de sortie.
_coolbash_img_backend() {
  local _ib_out="$1" _ib=""
  if [[ -n "${COOLBASH_IMG:-}" ]]; then
    _ib="$COOLBASH_IMG"
  elif [[ -n "${KITTY_WINDOW_ID:-}${GHOSTTY_RESOURCES_DIR:-}" || "${TERM:-}" == xterm-kitty || "${TERM:-}" == xterm-ghostty ]]; then
    _ib=kitty
  elif [[ -n "${ITERM_SESSION_ID:-}${WEZTERM_EXECUTABLE:-}" || "${TERM_PROGRAM:-}" == @(iTerm.app|WezTerm|mintty) ]]; then
    _ib=iterm
  elif [[ "${TERM:-}" == @(foot*|xterm*|mlterm*|contour*) && "${TERM:-}" != xterm-256color ]] && { command -v img2sixel >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; }; then
    _ib=sixel
  elif command -v chafa >/dev/null 2>&1 || command -v viu >/dev/null 2>&1 || command -v timg >/dev/null 2>&1; then
    _ib=chafa
  elif [[ "${TERM:-}" == xterm* ]] && { command -v img2sixel >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; }; then
    # FR : xterm-256color sans indice : le sixel marche sur foot, wezterm, xterm -ti.
    _ib=sixel
  fi
  printf -v "$_ib_out" '%s' "$_ib"
  [[ -n "$_ib" ]]
}

# FR : enveloppe tmux (passthrough) : ESC doublé, le tout dans \ePtmux; … \e\\.
_coolbash_img_emit() {
  if [[ -n "${TMUX:-}" ]]; then
    local s="$1"
    printf '\ePtmux;%s\e\\' "${s//$'\e'/$'\e\e'}"
  else
    printf '%s' "$1"
  fi
}

# FR : protocole kitty — PNG en base64 par morceaux de 4096 octets.
#      a=T transmettre et afficher, f=100 PNG, c=colonnes (optionnel).
_coolbash_img_kitty() {
  local file="$1" cols="${2:-}" b64 chunk pos=0 ctrl more
  if command -v kitten >/dev/null 2>&1 && [[ -z "${TMUX:-}" ]]; then
    kitten icat --stdin=no ${cols:+--place "${cols}x0@0x0" --scale-up} "$file" 2>/dev/null && return 0
  fi
  case "${file,,}" in
    *.png) b64="$(base64 -w0 "$file")" ;;
    *)
      command -v magick >/dev/null 2>&1 || return 1
      b64="$(magick "$file" png:- 2>/dev/null | base64 -w0)"
      ;;
  esac
  [[ -n "$b64" ]] || return 1
  ctrl="a=T,f=100,q=2${cols:+,c=$cols}"
  while ((pos < ${#b64})); do
    chunk="${b64:pos:4096}"
    pos=$((pos + 4096))
    ((pos < ${#b64})) && more=1 || more=0
    _coolbash_img_emit $'\e_G'"${ctrl},m=${more};${chunk}"$'\e\\'
    ctrl="m=${more}"
  done
  printf '\n'
}

# FR : protocole iTerm2 — un seul bloc base64, n'importe quel format.
_coolbash_img_iterm() {
  local file="$1" cols="${2:-}" b64 name
  b64="$(base64 -w0 "$file")" || return 1
  name="$(printf '%s' "${file##*/}" | base64 -w0)"
  _coolbash_img_emit $'\e]1337;File=inline=1;name='"${name};size=${#b64}${cols:+;width=$cols}:${b64}"$'\a'
  printf '\n'
}

_coolbash_img_sixel() {
  local file="$1" cols="${2:-}"
  if command -v img2sixel >/dev/null 2>&1; then
    img2sixel ${cols:+-w $((cols * 8))} "$file"
  elif command -v magick >/dev/null 2>&1; then
    magick "$file" ${cols:+-resize "$((cols * 8))x"} sixel:-
  else
    return 1
  fi
  printf '\n'
}

_coolbash_img_chafa() {
  local file="$1" cols="${2:-}"
  if command -v chafa >/dev/null 2>&1; then
    chafa ${cols:+--size "${cols}x"} "$file"
  elif command -v viu >/dev/null 2>&1; then
    viu ${cols:+-w "$cols"} "$file"
  elif command -v timg >/dev/null 2>&1; then
    timg ${cols:+-g "${cols}x"} "$file"
  else
    return 1
  fi
}

img() {
  local cols="" f backend rc=0
  if [[ "${1:-}" == -w ]]; then
    cols="${2:-}"
    shift 2
    [[ "$cols" =~ ^[0-9]+$ ]] || {
      echo "usage : img [-w colonnes] <fichier…>" >&2
      return 1
    }
  fi
  (($#)) || {
    echo "usage : img [-w colonnes] <fichier…>" >&2
    return 1
  }
  _coolbash_img_backend backend || {
    echo "img : aucune méthode d'affichage pour ce terminal — coolbash deps (chafa, libsixel, imagemagick)" >&2
    return 1
  }
  for f in "$@"; do
    [[ -r "$f" ]] || {
      echo "img : $f introuvable" >&2
      rc=1
      continue
    }
    "_coolbash_img_${backend}" "$f" "$cols" || {
      echo "img : échec avec la méthode ${backend} — COOLBASH_IMG=chafa pour forcer le repli" >&2
      rc=1
    }
  done
  return "$rc"
}
true
