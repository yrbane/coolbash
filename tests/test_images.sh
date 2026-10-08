#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 43-images — img : choix de la méthode selon le terminal,
#         protocoles kitty et iTerm2 émis en pur bash, repli chafa, usage.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
IMG="${COOLBASH_TEST_ROOT}/modules/43-images.bash"
export MOTD_DISABLE=1

# FR : im [-u VAR] [VAR=val…] 'code' — options de env, puis le code après 00-core et 43-images.
im() {
  local code="${*: -1}"
  env "${@:1:$#-1}" HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; eval "$3"' _ "${CORE}" "${IMG}" "${code}" 2>&1
}

# FR : un PNG 1×1 (68 octets) décodé depuis base64 — zéro dépendance.
png="${COOLBASH_TEST_TMP}/pixel.png"
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d >"${png}"
b64="$(base64 -w0 "${png}")"
fb="${COOLBASH_TEST_TMP}/fbimg"
mkdir -p "${fb}"
for b in bash base64 env grep sed cat head tail tr cut wc; do ln -sf "$(command -v "$b")" "${fb}/$b"; done

# --- choix de la méthode -------------------------------------------------------
be() { im "$@" '_coolbash_img_backend b; echo "$b"'; }
assert_eq "kitty : KITTY_WINDOW_ID" "kitty" "$(be -u COOLBASH_IMG KITTY_WINDOW_ID=1 TERM=xterm-kitty)"
assert_eq "kitty : ghostty" "kitty" "$(be -u COOLBASH_IMG -u KITTY_WINDOW_ID GHOSTTY_RESOURCES_DIR=/x TERM=xterm-ghostty)"
assert_eq "iterm : WezTerm" "iterm" "$(be -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR WEZTERM_EXECUTABLE=/x TERM=wezterm)"
assert_eq "iterm : TERM_PROGRAM=iTerm.app" "iterm" "$(be -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR -u WEZTERM_EXECUTABLE TERM_PROGRAM=iTerm.app TERM=xterm-256color)"
assert_eq "sixel : foot avec img2sixel" "sixel" "$(
  printf '#!/bin/bash\n' >"${fb}/img2sixel"
  chmod +x "${fb}/img2sixel"
  be -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR -u WEZTERM_EXECUTABLE -u TERM_PROGRAM TERM=foot PATH="${fb}"
)"
rm -f "${fb}/img2sixel"
assert_eq "chafa : terminal inconnu, chafa présent" "chafa" "$(
  printf '#!/bin/bash\n' >"${fb}/chafa"
  chmod +x "${fb}/chafa"
  be -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR -u WEZTERM_EXECUTABLE -u TERM_PROGRAM TERM=dumb PATH="${fb}"
)"
rm -f "${fb}/chafa"
assert_eq "rien : terminal inconnu, aucun outil → vide, code 1" "1 " "$(im -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR -u WEZTERM_EXECUTABLE -u TERM_PROGRAM TERM=dumb PATH="${fb}" '_coolbash_img_backend b; echo "$? $b"')"
assert_eq "COOLBASH_IMG force la méthode" "sixel" "$(be COOLBASH_IMG=sixel TERM=dumb PATH="${fb}")"

# --- protocole kitty, émis en pur bash --------------------------------------------
k="$(im -u TMUX COOLBASH_IMG=kitty PATH="${fb}" "img '${png}'" | cat -v)"
assert_contains "kitty : séquence APC _G avec a=T,f=100" "${k}" '^[_Ga=T,f=100,q=2,m=0;'
assert_contains "kitty : le PNG en base64" "${k}" "${b64}"
assert_contains "kitty : terminée par ESC \\\\" "${k}" "^[\\"
assert_contains "kitty : -w 40 → c=40" "$(im -u TMUX COOLBASH_IMG=kitty PATH="${fb}" "img -w 40 '${png}'" | cat -v)" ',c=40,'
assert_contains "kitty sous tmux : enveloppe passthrough" "$(im COOLBASH_IMG=kitty TMUX=/tmp/x PATH="${fb}" "img '${png}'" | cat -v)" '^[Ptmux;^[^[_G'
big="${COOLBASH_TEST_TMP}/big.png"
head -c 5000 /dev/urandom >"${big}" # FR : > 4096 octets une fois en base64 ; seul le suffixe .png compte ici
n="$(im -u TMUX COOLBASH_IMG=kitty PATH="${fb}" "img '${big}'" | grep -ao 'm=1;' | wc -l)"
assert_eq "kitty : au-delà de 4096 octets, plusieurs morceaux (m=1 puis m=0)" "1" "$([[ "${n}" -ge 1 ]] && echo 1 || echo 0)"

# --- protocole iTerm2 --------------------------------------------------------------
it="$(im -u TMUX COOLBASH_IMG=iterm PATH="${fb}" "img '${png}'" | cat -v)"
assert_contains "iterm : OSC 1337 File=inline=1" "${it}" '^[]1337;File=inline=1;name='
assert_contains "iterm : taille et données" "${it}" ";size=${#b64}:${b64}^G"
assert_contains "iterm : -w 30 → width=30" "$(im -u TMUX COOLBASH_IMG=iterm PATH="${fb}" "img -w 30 '${png}'" | cat -v)" ';width=30:'

# --- repli chafa et sixel : les outils sont appelés avec le fichier --------------------
printf '#!/bin/bash\necho "chafa:$*"\n' >"${fb}/chafa"
chmod +x "${fb}/chafa"
assert_contains "chafa : appelé avec --size et le fichier" "$(im COOLBASH_IMG=chafa PATH="${fb}" "img -w 50 '${png}'")" "chafa:--size 50x ${png}"
rm -f "${fb}/chafa"
printf '#!/bin/bash\necho "viu:$*"\n' >"${fb}/viu"
chmod +x "${fb}/viu"
assert_contains "chafa absent : viu en repli" "$(im COOLBASH_IMG=chafa PATH="${fb}" "img '${png}'")" "viu:${png}"
rm -f "${fb}/viu"
printf '#!/bin/bash\necho "img2sixel:$*"\n' >"${fb}/img2sixel"
chmod +x "${fb}/img2sixel"
assert_contains "sixel : img2sixel, -w en pixels (colonnes × 8)" "$(im COOLBASH_IMG=sixel PATH="${fb}" "img -w 20 '${png}'")" "img2sixel:-w 160 ${png}"
rm -f "${fb}/img2sixel"

# --- usage et erreurs ----------------------------------------------------------------
assert_eq "img sans argument → usage, code 1" "1" "$(im 'img >/dev/null 2>&1; echo $?')"
assert_contains "img fichier absent → message" "$(im COOLBASH_IMG=iterm "img /nulle/part.png")" "introuvable"
assert_contains "aucune méthode → renvoie vers coolbash deps" "$(im -u COOLBASH_IMG -u KITTY_WINDOW_ID -u GHOSTTY_RESOURCES_DIR -u WEZTERM_EXECUTABLE -u TERM_PROGRAM TERM=dumb PATH="${fb}" "img '${png}'")" "coolbash deps"

# --- MOTD : ~/.coolbash/motd.png -------------------------------------------------------
mkdir -p "${COOLBASH_TEST_TMP}/.coolbash"
cp "${png}" "${COOLBASH_TEST_TMP}/.coolbash/motd.png"
m="$(HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/.coolbash" COOLBASH_IMG=iterm bash --norc --noprofile -c 'source "$1"; source "$2"; source "$3"; _coolbash_motd_image' _ "${CORE}" "${IMG}" "${COOLBASH_TEST_ROOT}/modules/70-motd.bash" 2>&1 | cat -v)"
assert_contains "MOTD : motd.png est affiché avec la méthode du terminal" "${m}" '^[]1337;File=inline=1'
rm -f "${COOLBASH_TEST_TMP}/.coolbash/motd.png"
assert_eq "MOTD : sans motd.png, rien" "" "$(HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/.coolbash" COOLBASH_IMG=iterm bash --norc --noprofile -c 'source "$1"; source "$2"; source "$3"; _coolbash_motd_image' _ "${CORE}" "${IMG}" "${COOLBASH_TEST_ROOT}/modules/70-motd.bash" 2>&1)"

t_done
