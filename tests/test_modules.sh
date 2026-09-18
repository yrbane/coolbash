#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : chaque module se charge (après 00-core, la base commune dont les
#         autres peuvent dépendre : path_append, have…), sans erreur ni bruit
#         sur stderr, et renvoie 0 (piège classique : `[[ -f x ]] && . x` en
#         dernière ligne renvoie 1 quand le fichier manque).
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for m in "${COOLBASH_TEST_ROOT}"/modules/*.bash; do
  name="$(basename "$m")"
  out="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1" && source "$2"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "$m" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 && -z "${out}" ]]; then
    t_ok "${name} se charge après 00-core, renvoie 0, sans sortie"
  else
    t_fail "${name} — code ${rc}, sortie :"$'\n'"${out}"
  fi
done

out="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  for m in "$1"/modules/*.bash; do source "$m" || echo "échec: $m"; done' _ "${COOLBASH_TEST_ROOT}" 2>&1)"
assert_empty "tous les modules se chargent en séquence sans erreur" "${out}"

# --- 00-core ne doit jamais imposer une locale absente de la machine ---------
# FR : bug vu en CI (Ubuntu sans fr_FR) : « setlocale: LC_ALL: cannot change locale ».
# shellcheck disable=SC2016  # FR : script inline volontairement en simple quotes
chosen="$(env -u LANG -u LC_ALL bash --norc --noprofile -c 'source "$1" 2>&1; echo "${LC_ALL}"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" | tail -1)"
normalized="$(echo "${chosen}" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
if locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qx "${normalized}"; then
  t_ok "00-core choisit une locale présente sur la machine (${chosen})"
else
  t_fail "00-core impose une locale absente : ${chosen}"
fi
# shellcheck disable=SC2016
out="$(env -u LANG -u LC_ALL MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  for m in "$1"/modules/*.bash; do source "$m"; done; ls / >/dev/null' _ "${COOLBASH_TEST_ROOT}" 2>&1)"
assert_empty "sans LANG/LC_ALL, le chargement complet n'émet aucun avertissement setlocale" "${out}"

# --- 10-history : synchro enregistrée ET fonctionnelle (bug : jamais branchée) --
assert_contains "_coolbash_history_sync est dans PROMPT_COMMAND" \
  "$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; echo "${PROMPT_COMMAND[*]}"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/10-history.bash")" \
  "_coolbash_history_sync"
hist="${COOLBASH_TEST_TMP}/hist"
seen="$(printf 'source "%s"; source "%s"\necho coolbash-marker\ncat "$HISTFILE"\n' "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/10-history.bash" \
        | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" HISTFILE="${hist}" bash --norc --noprofile -i 2>/dev/null | grep -c "echo coolbash-marker")"
assert_eq "une commande est écrite dans HISTFILE dès le prompt suivant" "1" "${seen}"

# --- 60-completion : chargement différé au premier Tab (bug : jamais appelé) --
lazy="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  source "$1"; source "$2"
  complete -p -D 2>/dev/null | grep -q _coolbash_completion_lazy || { echo "pas de chargeur -D"; exit 0; }
  _coolbash_completion_lazy; rc=$?
  echo "rc=$rc"
  complete -p -D 2>/dev/null | grep -q _coolbash_completion_lazy && echo "chargeur encore en place"
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    declare -F _init_completion >/dev/null || declare -F _comp_initialize >/dev/null || echo "bash-completion non chargé"
  fi
' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/60-completion.bash" 2>&1)"
assert_eq "le chargeur différé charge puis se retire (retour 124 = réessayer la completion)" "rc=124" "${lazy}"

# --- 0.8.1 : correctifs des modules -----------------------------------------
# shellcheck disable=SC2016
mod() { MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; m="$2"; shift 2; source "$m"; eval "$*"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/$1" "${@:2}" 2>&1; }

# FR : `alias please='sudo !!'` ne marchait pas — pas d'expansion d'historique dans un alias.
assert_eq "please est une fonction, plus un alias" "function" "$(mod 30-aliases.bash 'type -t please')"
fakebin="${COOLBASH_TEST_TMP}/fakebin"; mkdir -p "${fakebin}"
printf '#!/bin/sh\necho "SUDO:$*"\n' > "${fakebin}/sudo"; chmod +x "${fakebin}/sudo"
got="$(printf 'source "%s"; source "%s"\necho bonjour le monde\nplease\n' "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/30-aliases.bash" \
      | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" PATH="${fakebin}:${PATH}" bash --norc --noprofile -i 2>/dev/null | grep '^SUDO:')"
assert_contains "please relance la dernière commande avec sudo" "${got}" "echo bonjour le monde"

# FR : le chemin des gems Ruby était figé (3.4.0) et ajouté même absent.
assert_eq "PATH : aucun dossier de gems inexistant" "0" "$(PATH=/usr/bin:/bin mod 20-path-and-colors.bash 'echo "$PATH"' | tr ':' '\n' | grep -c 'gem/ruby')"
mkdir -p "${COOLBASH_TEST_TMP}/.local/share/gem/ruby/9.9.0/bin"
assert_contains "PATH : dossier de gems détecté quelle que soit la version" "$(mod 20-path-and-colors.bash 'echo "$PATH"')" "gem/ruby/9.9.0/bin"

# FR : un module de shell ne modifie pas ~/.gitconfig.
assert_eq "31-git n'écrit plus dans la config git globale" "0" "$(grep -cE '^[^#]*git config --global [a-z.]+ [^>-]' "${COOLBASH_TEST_ROOT}/modules/31-git.bash")"
mod 31-git.bash true >/dev/null
assert_no_path "…aucun ~/.gitconfig créé au chargement" "${COOLBASH_TEST_TMP}/.gitconfig"

assert_contains "MOTD : fastfetch d'abord (neofetch est abandonné)" "$(cat "${COOLBASH_TEST_ROOT}/modules/70-motd.bash")" "fastfetch"
assert_contains "doctor liste fastfetch" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" doctor 2>&1)" "fastfetch"

assert_eq "up ne laisse pas fuiter sa variable de boucle" "" "$(cd "${COOLBASH_TEST_TMP}" && mod 40-functions.bash 'up 1; echo "${i-}"')"
assert_eq "timer mesure en millisecondes" "1" "$(mod 40-functions.bash 'timer sleep 0.2' | grep -cE '0\.2[0-9]{2}s')"
assert_contains "workon sans .venv : message clair" "$(cd "${COOLBASH_TEST_TMP}" && mod 34-python-venv.bash 'workon')" "No .venv"
mkdir -p "${COOLBASH_TEST_TMP}/proj/.venv/bin"; echo 'return 3' > "${COOLBASH_TEST_TMP}/proj/.venv/bin/activate"
assert_eq "workon : une activation en échec n'affiche pas « No .venv »" "0" "$(cd "${COOLBASH_TEST_TMP}/proj" && mod 34-python-venv.bash 'workon' | grep -c 'No .venv')"

t_done
