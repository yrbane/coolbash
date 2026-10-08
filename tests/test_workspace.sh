#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 42-workspace — hooks de dossier, todo, remind, retry, copy/paste.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
WS="${COOLBASH_TEST_ROOT}/modules/42-workspace.bash"
CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"
export MOTD_DISABLE=1
PFX="${COOLBASH_TEST_TMP}/.coolbash"
mkdir -p "${PFX}"

# FR : ws [-u VAR] [VAR=val…] 'code' — les options sont celles de env.
ws() {
  local code="${*: -1}"
  env "${@:1:$#-1}" HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash --norc --noprofile -c 'source "$1"; source "$2"; eval "$3"' _ "${CORE}" "${WS}" "${code}" 2>&1
}

# --- hooks de dossier ----------------------------------------------------------
proj="${COOLBASH_TEST_TMP}/proj"
mkdir -p "${proj}/src/deep"
cat >|"${proj}/.coolbash.bash" <<'HOOK'
export PROJ_TOKEN="secret"
coolbash_hook_unload() { unset PROJ_TOKEN; }
HOOK
out="$(cd "${proj}" && ws '_coolbash_hook_check; echo "T=${PROJ_TOKEN-}"')"
assert_contains "hook non autorisé : un avertissement, une fois" "${out}" "non autorisé"
assert_contains "…et rien n'est chargé" "${out}" "T="
assert_eq "…l'avertissement n'est affiché qu'une fois par session" "1" "$(cd "${proj}" && ws '_coolbash_hook_check; _coolbash_hook_check' | grep -c 'non autorisé')"
assert_eq "_coolbash_hook_check est dans PROMPT_COMMAND" "1" "$(ws 'printf %s "${PROMPT_COMMAND[*]}"' | grep -c _coolbash_hook_check)"
(cd "${proj}" && HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash "${CLI}" allow >/dev/null 2>&1)
assert_file "coolbash allow écrit ~/.coolbash/allowed" "${PFX}/allowed"
assert_eq "hook autorisé : chargé à l'entrée (depuis un sous-dossier aussi)" "T=secret" "$(cd "${proj}/src/deep" && ws '_coolbash_hook_check; echo "T=${PROJ_TOKEN-}"')"
assert_eq "…et défait à la sortie (coolbash_hook_unload)" "T=secret|T=" "$(cd "${proj}" && ws '_coolbash_hook_check; printf "T=%s|" "${PROJ_TOKEN-}"; cd /; _coolbash_hook_check; echo "T=${PROJ_TOKEN-}"')"
printf 'export PROJ_TOKEN="modifié"\n' >>"${proj}/.coolbash.bash"
assert_contains "hook modifié : à réautoriser" "$(cd "${proj}" && ws '_coolbash_hook_check; echo "T=${PROJ_TOKEN-}"')" "non autorisé"
(cd "${proj}" && HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash "${CLI}" deny >/dev/null 2>&1)
assert_eq "coolbash deny retire l'autorisation" "0" "$(
  x="$(grep -c "${proj}" "${PFX}/allowed" 2>/dev/null)"
  echo "${x:-0}"
)"
assert_eq "COOLBASH_HOOKS=0 : rien, pas même l'avertissement" "" "$(cd "${proj}" && ws COOLBASH_HOOKS=0 '_coolbash_hook_check')"
assert_eq "coolbash allow hors d'un projet → erreur" "1" "$(
  cd / && HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash "${CLI}" allow >/dev/null 2>&1
  echo $?
)"

# --- todo ------------------------------------------------------------------------
rm -f "${PFX}/todo.txt" "${PFX}/todo.done"
assert_contains "todo vide : rien à faire" "$(ws 'todo')" "rien à faire"
ws 'todo add "Renouveler le certificat"; todo add "Relire la PR"' >/dev/null
assert_eq "todo add : deux tâches numérotées" "2" "$(ws 'todo' | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^ +[0-9]+  ')"
assert_contains "todo : la première en 1" "$(ws 'todo' | sed 's/\x1b\[[0-9;]*m//g' | head -1)" "1  Renouveler"
assert_eq "complétion de todo : sous-commandes" "add done rm list" "$(ws 'COMP_WORDS=(todo ""); COMP_CWORD=1; _coolbash_todo_complete; echo "${COMPREPLY[*]}"')"
assert_eq "complétion de todo done : les numéros des tâches" "1 2" "$(ws 'COMP_WORDS=(todo done ""); COMP_CWORD=2; _coolbash_todo_complete; echo "${COMPREPLY[*]}"')"
assert_eq "complétion de todo add : rien" "" "$(ws 'COMP_WORDS=(todo add ""); COMP_CWORD=2; _coolbash_todo_complete; echo "${COMPREPLY[*]}"')"
ws 'todo done 1' >/dev/null
assert_eq "todo done 1 : il reste la seconde, renumérotée" "   1  Relire la PR" "$(ws 'todo' | sed 's/\x1b\[[0-9;]*m//g' | head -1)"
assert_contains "todo done : archivée avec la date" "$(cat "${PFX}/todo.done")" "Renouveler le certificat"
assert_eq "todo done 9 : hors limites, code 1" "1" "$(ws 'todo done 9 >/dev/null 2>&1; echo $?')"
assert_contains "MOTD : les tâches ouvertes sous la note" "$(HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash --norc --noprofile -c 'source "$1"; source "$2"; PATH=/nonexistent; _coolbash_motd_sysinfo' _ "${CORE}" "${COOLBASH_TEST_ROOT}/modules/70-motd.bash" | sed 's/\x1b\[[0-9;]*m//g')" "Relire la PR"
ws 'todo rm 1' >/dev/null
assert_no_path "todo rm de la dernière : le fichier disparaît" "${PFX}/todo.txt"

# --- remind ---------------------------------------------------------------------
fb="${COOLBASH_TEST_TMP}/fbws"
mkdir -p "${fb}"
printf '#!/bin/bash\nprintf "%%s|%%s\\n" "$1" "$2" > "%s/notified"\n' "${fb}" >|"${fb}/notify-send"
chmod +x "${fb}/notify-send"
assert_contains "remind : annonce le délai en secondes" "$(ws PATH="${fb}:${PATH}" 'remind 1s "sortir le pain"')" "dans 1s"
sleep 2
assert_contains "remind : notify-send appelé à l'échéance, en arrière-plan" "$(cat "${fb}/notified" 2>/dev/null)" "sortir le pain"
assert_eq "remind 2m = 120 s" "1" "$(ws 'remind 2m x' | grep -c 'dans 120s')"
assert_eq "remind sans délai valide → usage, code 1" "1" "$(ws 'remind bientôt x >/dev/null 2>&1; echo $?')"

# --- retry ------------------------------------------------------------------------
cnt="${COOLBASH_TEST_TMP}/retry-count"
rm -f "${cnt}"
printf '#!/bin/bash\nn=$(cat "%s" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "%s"; [[ $n -ge 3 ]]\n' "${cnt}" "${cnt}" >|"${fb}/flaky"
chmod +x "${fb}/flaky"
assert_eq "retry : réussit au troisième essai, code 0" "0" "$(ws "retry 5 ${fb}/flaky >/dev/null 2>&1; echo \$?")"
assert_eq "…après exactement trois appels" "3" "$(cat "${cnt}")"
rm -f "${cnt}"
assert_eq "retry : abandonne après N essais, code de la commande" "1" "$(ws "retry 2 ${fb}/flaky >/dev/null 2>&1; echo \$?")"
assert_eq "retry sans commande → usage" "1" "$(ws 'retry 3 >/dev/null 2>&1; echo $?')"

# --- copy / paste / copypath ------------------------------------------------------------
printf '#!/bin/bash\ncat > "%s/clip"\n' "${fb}" >|"${fb}/wl-copy"
printf '#!/bin/bash\ncat "%s/clip"\n' "${fb}" >|"${fb}/wl-paste"
chmod +x "${fb}/wl-copy" "${fb}/wl-paste"
assert_eq "copy texte → wl-copy sous Wayland" "bonjour" "$(
  ws -u SSH_CONNECTION -u SSH_TTY WAYLAND_DISPLAY=w PATH="${fb}:${PATH}" 'copy bonjour'
  cat "${fb}/clip"
)"
assert_eq "copy depuis stdin" "depuis stdin" "$(
  ws -u SSH_CONNECTION -u SSH_TTY WAYLAND_DISPLAY=w PATH="${fb}:${PATH}" 'printf "depuis stdin" | copy'
  cat "${fb}/clip"
)"
assert_eq "paste relit" "depuis stdin" "$(ws -u SSH_CONNECTION -u SSH_TTY WAYLAND_DISPLAY=w PATH="${fb}:${PATH}" 'paste')"
assert_eq "en SSH : OSC 52 avec le texte en base64" "$(printf '\e]52;c;%s\a' "$(printf 'x' | base64)")" "$(ws SSH_CONNECTION=1 WAYLAND_DISPLAY=w PATH="${fb}:${PATH}" 'copy x')"
assert_contains "sans aucun outil : OSC 52 aussi" "$(ws -u SSH_CONNECTION -u SSH_TTY -u WAYLAND_DISPLAY -u DISPLAY 'copy x' | cat -v)" "^[]52;c;"
assert_eq "copypath : chemin absolu dans le presse-papiers et affiché" "${proj}/.coolbash.bash" "$(cd "${proj}" && ws -u SSH_CONNECTION -u SSH_TTY WAYLAND_DISPLAY=w PATH="${fb}:${PATH}" 'copypath .coolbash.bash')"
assert_eq "copypath fichier absent → erreur" "1" "$(ws 'copypath /nulle/part >/dev/null 2>&1; echo $?')"

# --- --help (0.35.0) ------------------------------------------------------------------
assert_contains "todo --help : l'aide du CLI" "$(ws COOLBASH_ROOT="${COOLBASH_TEST_ROOT}" 'todo --help')" "todo.done"
assert_contains "remind -h" "$(ws COOLBASH_ROOT="${COOLBASH_TEST_ROOT}" 'remind -h')" "notify-send"
assert_contains "retry --help" "$(ws COOLBASH_ROOT="${COOLBASH_TEST_ROOT}" 'retry --help')" "retry <N>"
assert_contains "copy --help" "$(ws COOLBASH_ROOT="${COOLBASH_TEST_ROOT}" 'copy --help')" "OSC 52"
assert_contains "copypath --help" "$(ws COOLBASH_ROOT="${COOLBASH_TEST_ROOT}" 'copypath --help')" "copypath [fichier]"

t_done
