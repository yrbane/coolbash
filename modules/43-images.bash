# shellcheck shell=bash
#  ██ ███    ███  ██████
#  ██ ████  ████ ██
#  ██ ██ ████ ██ ██   ███
#  ██ ██  ██  ██ ██    ██
#  ██ ██      ██  ██████   MODULE: IMAGES
# ─────────────────────────────────────────────────────────────────────────────
# FR: img [-w colonnes] [-h lignes] <fichier…> — afficher une image dans le
#     terminal, par la meilleure méthode disponible :
#       kitty   protocole graphique de kitty (kitty, ghostty, konsole ≥ 22.04,
#               wezterm) — PNG envoyé en base64, le reste converti par magick,
#               ou `kitten icat` s'il est là ;
#       iterm   protocole iTerm2 (iTerm2, WezTerm, mintty, VS Code) ;
#       sixel   foot, xterm, mlterm, contour, Windows Terminal — img2sixel ou magick ;
#       chafa   repli en caractères (chafa, sinon viu, sinon timg) : alacritty,
#               VS Code quand chafa est là, console, tout le reste.
#     Sans -w ni -h : la largeur du terminal (COLUMNS − 2), sans agrandir un PNG
#     plus petit (sa largeur est lue dans l'en-tête). COOLBASH_IMG=kitty|iterm|
#     sixel|chafa force la méthode. Sous tmux, les séquences kitty/iTerm2 sont
#     enveloppées (passthrough).
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
  elif [[ "${KONSOLE_VERSION:-}" =~ ^[0-9]+$ ]] && ((KONSOLE_VERSION >= 220400)); then
    # FR : konsole parle le protocole kitty depuis 22.04.
    _ib=kitty
  elif [[ "${TERM_PROGRAM:-}" == vscode ]] && { command -v chafa >/dev/null 2>&1 || command -v viu >/dev/null 2>&1 || command -v timg >/dev/null 2>&1; }; then
    # FR : VS Code n'affiche les images qu'avec terminal.integrated.enableImages :
    #      en caractères si on peut, sinon iTerm2 (qu'il comprend une fois réglé).
    _ib=chafa
  elif [[ -n "${ITERM_SESSION_ID:-}${WEZTERM_EXECUTABLE:-}" || "${TERM_PROGRAM:-}" == @(iTerm.app|WezTerm|mintty|vscode) ]]; then
    _ib=iterm
  elif [[ -n "${WT_SESSION:-}" || ("${TERM:-}" == @(foot*|xterm*|mlterm*|contour*) && "${TERM:-}" != xterm-256color) ]] && { command -v img2sixel >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; }; then
    # FR : Windows Terminal (WT_SESSION) sait le sixel depuis la 1.22.
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
  local file="$1" cols="${2:-}" rows="${3:-}" b64 chunk pos=0 ctrl more
  if command -v kitten >/dev/null 2>&1 && [[ -z "${TMUX:-}" ]]; then
    kitten icat --stdin=no ${cols:+--place "${cols}x${rows:-0}@0x0" --scale-up} "$file" 2>/dev/null && return 0
  fi
  case "${file,,}" in
    *.png) b64="$(base64 -w0 "$file")" ;;
    *)
      command -v magick >/dev/null 2>&1 || return 1
      b64="$(magick "$file" png:- 2>/dev/null | base64 -w0)"
      ;;
  esac
  [[ -n "$b64" ]] || return 1
  ctrl="a=T,f=100,q=2${cols:+,c=$cols}${rows:+,r=$rows}"
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
  local file="$1" cols="${2:-}" rows="${3:-}" b64 name
  b64="$(base64 -w0 "$file")" || return 1
  name="$(printf '%s' "${file##*/}" | base64 -w0)"
  _coolbash_img_emit $'\e]1337;File=inline=1;name='"${name};size=${#b64}${cols:+;width=$cols}${rows:+;height=$rows}:${b64}"$'\a'
  printf '\n'
}

_coolbash_img_sixel() {
  local file="$1" cols="${2:-}" rows="${3:-}"
  if command -v img2sixel >/dev/null 2>&1; then
    img2sixel ${cols:+-w $((cols * 8))} ${rows:+-h $((rows * 16))} "$file"
  elif command -v magick >/dev/null 2>&1; then
    magick "$file" ${cols:+-resize "$((cols * 8))x"} ${rows:+-resize "x$((rows * 16))"} sixel:-
  else
    return 1
  fi
  printf '\n'
}

_coolbash_img_chafa() {
  local file="$1" cols="${2:-}" rows="${3:-}"
  local size=""
  [[ -n "$cols$rows" ]] && size="${cols}x${rows}"
  if command -v chafa >/dev/null 2>&1; then
    chafa ${size:+--size "$size"} "$file"
  elif command -v viu >/dev/null 2>&1; then
    viu ${cols:+-w "$cols"} ${rows:+-h "$rows"} "$file"
  elif command -v timg >/dev/null 2>&1; then
    timg ${size:+-g "$size"} "$file"
  else
    return 1
  fi
}

# FR : largeur en pixels d'un PNG (IHDR, octets 16-19, big-endian) — pour ne pas
#      agrandir une petite image à la largeur du terminal. $1 = fichier, $2 = variable.
_coolbash_img_png_width() {
  local -a b
  # shellcheck disable=SC2207
  b=($(od -An -tu1 -j16 -N4 "$1" 2>/dev/null)) || return 1
  ((${#b[@]} == 4)) || return 1
  printf -v "$2" '%d' $((b[0] * 16777216 + b[1] * 65536 + b[2] * 256 + b[3]))
}

# FR : complétion : les images (et les dossiers pour y descendre).
complete -o filenames -o plusdirs -f -X '!*.@(png|PNG|jpg|JPG|jpeg|JPEG|gif|GIF|webp|WEBP|bmp|BMP|svg|SVG)' img

img() {
  # FR : -h est aussi l'option hauteur : seul, ou --help, c'est l'aide.
  if [[ "${1:-}" == --help ]] || [[ "${1:-}" == -h && $# -eq 1 ]]; then
    _coolbash_fn_help img --help
    return
  fi
  local cols="" rows="" f backend rc=0 auto=0 px
  while [[ "${1:-}" == -w || "${1:-}" == -h ]]; do
    if [[ "$1" == -w ]]; then cols="${2:-}"; else rows="${2:-}"; fi
    [[ "${2:-}" =~ ^[0-9]+$ ]] || {
      _coolbash_say 'usage : img [-w colonnes] [-h lignes] <fichier…>\n' >&2
      return 1
    }
    shift 2
  done
  (($#)) || {
    _coolbash_say 'usage : img [-w colonnes] [-h lignes] <fichier…>\n' >&2
    return 1
  }
  # FR : sans taille : la largeur du terminal, moins une marge.
  if [[ -z "$cols$rows" && "${COLUMNS:-0}" -gt 10 ]]; then
    cols=$((COLUMNS - 2))
    auto=1
  fi
  _coolbash_img_backend backend || {
    _coolbash_say "img : aucune méthode d'affichage pour ce terminal — coolbash deps (chafa, libsixel, imagemagick)\n" >&2
    return 1
  }
  for f in "$@"; do
    [[ -r "$f" ]] || {
      _coolbash_say 'img : %s introuvable\n' "$f" >&2
      rc=1
      continue
    }
    # FR : largeur automatique : jamais plus large que le PNG lui-même (≈ 8 px par colonne).
    if ((auto)) && [[ "${f,,}" == *.png ]] && _coolbash_img_png_width "$f" px && ((px / 8 < cols)); then
      "_coolbash_img_${backend}" "$f" "$((px / 8 > 0 ? px / 8 : 1))" "$rows"
    else
      "_coolbash_img_${backend}" "$f" "$cols" "$rows"
    fi || {
      _coolbash_say 'img : échec avec la méthode %s — COOLBASH_IMG=chafa pour forcer le repli\n' "$backend" >&2
      rc=1
    }
  done
  return "$rc"
}
true
