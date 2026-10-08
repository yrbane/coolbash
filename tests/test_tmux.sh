#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 45-tmux — en SSH, avec COOLBASH_TMUX_SSH=1 et un terminal,
#         le shell s'attache à la session tmux ; jamais sinon.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
TM="${COOLBASH_TEST_ROOT}/modules/45-tmux.bash"
export MOTD_DISABLE=1
fb="${COOLBASH_TEST_TMP}/fbtmux"
mkdir -p "${fb}"
log="${COOLBASH_TEST_TMP}/tmux.log"
printf '#!/bin/bash\nprintf "tmux:%%s\\n" "$*" >> "%s"\n' "${log}" >|"${fb}/tmux"
chmod +x "${fb}/tmux"

# FR : tm [VAR=val…] — un shell interactif dans un pseudo-terminal (script) ;
#      sans `script`, sans tty : le module doit alors rester muet.
tm() {
  rm -f "${log}"
  if command -v script >/dev/null 2>&1; then
    env -u TMUX -u SSH_CONNECTION -u SSH_TTY "$@" HOME="${COOLBASH_TEST_TMP}" PATH="${fb}:${PATH}" TERM=xterm \
      script -qec "bash --norc --noprofile -ic 'source \"${CORE}\"; source \"${TM}\"; echo shell-still-here'" /dev/null 2>/dev/null | tr -d '\r'
  else
    env -u TMUX -u SSH_CONNECTION -u SSH_TTY "$@" HOME="${COOLBASH_TEST_TMP}" PATH="${fb}:${PATH}" TERM=xterm \
      bash --norc --noprofile -ic 'source "$1"; source "$2"; echo shell-still-here' _ "${CORE}" "${TM}" 2>/dev/null
  fi
}
if command -v script >/dev/null 2>&1; then
  out="$(tm SSH_CONNECTION='1 2 3 4' COOLBASH_TMUX_SSH=1)"
  assert_contains "SSH + COOLBASH_TMUX_SSH=1 + terminal : exec tmux new-session -A" "$(cat "${log}" 2>/dev/null)" "tmux:new-session -A -s main"
  assert_not_contains "…le shell est remplacé (exec)" "${out}" "shell-still-here"
  tm SSH_CONNECTION='1 2 3 4' COOLBASH_TMUX_SSH=1 COOLBASH_TMUX_SESSION=boulot >/dev/null
  assert_contains "COOLBASH_TMUX_SESSION nomme la session" "$(cat "${log}" 2>/dev/null)" "-s boulot"
  out="$(tm SSH_CONNECTION='1 2 3 4')"
  assert_no_path "sans COOLBASH_TMUX_SSH : rien (opt-in)" "${log}"
  assert_contains "…le shell continue" "${out}" "shell-still-here"
  tm COOLBASH_TMUX_SSH=1 >/dev/null
  assert_no_path "en local (pas de SSH) : rien" "${log}"
  tm SSH_CONNECTION='1 2 3 4' COOLBASH_TMUX_SSH=1 TMUX=/tmp/x >/dev/null
  assert_no_path "déjà dans tmux : rien" "${log}"
  tm SSH_CONNECTION='1 2 3 4' COOLBASH_TMUX_SSH=1 COOLBASH_MODE=safe >/dev/null
  assert_no_path "mode safe : rien" "${log}"
else
  t_skip "script absent : pas de pseudo-terminal pour tester tmux"
fi
rm -f "${log}"
out="$(env -u TMUX SSH_CONNECTION='1 2 3 4' COOLBASH_TMUX_SSH=1 HOME="${COOLBASH_TEST_TMP}" PATH="${fb}:${PATH}" TERM=xterm bash --norc --noprofile -c 'source "$1"; source "$2"; echo shell-still-here' _ "${CORE}" "${TM}" 2>/dev/null)"
assert_no_path "sans terminal (scp, rsync, commande distante) : rien" "${log}"
assert_contains "…et la commande s'exécute" "${out}" "shell-still-here"

t_done
