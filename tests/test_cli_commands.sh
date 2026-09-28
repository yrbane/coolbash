#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : comportement des commandes de la CLI (help, version, init, erreurs).
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"

# --- help --------------------------------------------------------------------
assert_success "coolbash help renvoie 0" bash "${CLI}" help
assert_contains "coolbash help affiche l'usage" "$(bash "${CLI}" help)" "Usage: coolbash <command>"
assert_contains "coolbash sans argument affiche l'usage" "$(bash "${CLI}")" "Usage: coolbash <command>"
assert_failure "une commande inconnue renvoie un code d'erreur" bash "${CLI}" plop
assert_contains "une commande inconnue est nommée dans l'erreur" "$(bash "${CLI}" plop 2>&1)" "Unknown command: plop"

# --- version : une seule source de vérité, cohérente avec le CHANGELOG -------
version="$(bash "${CLI}" version)"
assert_eq "coolbash version affiche un numéro SemVer" "1" "$(echo "${version}" | grep -Ec '^[0-9]+\.[0-9]+\.[0-9]+$')"
changelog_version="$(grep -Eom1 '^## [0-9]+\.[0-9]+\.[0-9]+' "${COOLBASH_TEST_ROOT}/CHANGELOG.md" | cut -d' ' -f2)"
assert_eq "la version de la CLI est celle en tête du CHANGELOG" "${changelog_version}" "${version}"

# --- init : ordre de chargement des modules ----------------------------------
mods="${COOLBASH_TEST_TMP}/modules"
mkdir -p "${mods}"
# FR : créés dans le désordre pour vérifier que c'est le nom qui fait l'ordre.
echo 'COOLBASH_TEST_ORDER+="c"' >"${mods}/90-last.bash"
echo 'COOLBASH_TEST_ORDER+="a"' >"${mods}/00-first.bash"
echo 'COOLBASH_TEST_ORDER+="b"' >"${mods}/50-middle.bash"
echo 'COOLBASH_TEST_ORDER+="X"' >"${mods}/not-a-module.txt"
order="$(COOLBASH_MODULE_DIR="${mods}" bash --norc --noprofile -c 'source "$1" init; echo "${COOLBASH_TEST_ORDER}"' _ "${CLI}")"
assert_eq "init charge les modules *.bash dans l'ordre lexical, et rien d'autre" "abc" "${order}"

# --- init : un module qui échoue n'empêche pas les suivants ------------------
mkdir -p "${mods}2"
echo 'false' >"${mods}2/10-fails.bash"
echo 'COOLBASH_TEST_OK=1' >"${mods}2/20-next.bash"
res="$(COOLBASH_MODULE_DIR="${mods}2" bash --norc --noprofile -c 'source "$1" init 2>/dev/null; echo "rc=$? ok=${COOLBASH_TEST_OK-}"' _ "${CLI}")"
assert_eq "init continue après un module en échec et renvoie 0" "rc=0 ok=1" "${res}"

# --- init : répertoire de modules absent → pas d'erreur bruyante -------------
res="$(COOLBASH_MODULE_DIR="${COOLBASH_TEST_TMP}/nope" bash --norc --noprofile -c 'source "$1" init 2>&1; echo "rc=$?"' _ "${CLI}")"
assert_eq "init sans répertoire de modules reste silencieux" "rc=0" "${res}"

# --- init : la fonction shell `coolbash` est disponible ----------------------
res="$(COOLBASH_MODULE_DIR="${mods}" bash --norc --noprofile -c 'source "$1" init; coolbash help' _ "${CLI}")"
assert_contains "après init, la fonction coolbash relaie vers la CLI" "${res}" "Usage: coolbash <command>"

# --- commandes de gestion hors d'un clone → erreur explicite -----------------
fake="${COOLBASH_TEST_TMP}/fake/cli"
mkdir -p "${fake}" && cp "${CLI}" "${fake}/coolbash"
assert_failure "coolbash update hors d'un clone git échoue" env COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" update
assert_contains "…avec un message explicite" "$(COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" update 2>&1)" "Makefile"

# --- COOLBASH_REPO permet de désigner le clone -------------------------------
clone="${COOLBASH_TEST_TMP}/clone"
make_fake_clone "${clone}"
assert_success "coolbash verify via COOLBASH_REPO délègue au clone" \
  env COOLBASH_REPO="${clone}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" verify

# --- doctor ------------------------------------------------------------------
home="${COOLBASH_TEST_TMP}/dhome"
mkdir -p "${home}"
make_fake_clone "${home}/clone"
make -s -C "${home}/clone" install PREFIX="${home}/.coolbash" BASHRC="${home}/.bashrc" >/dev/null
doc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" doctor 2>&1)"
rc=$?
assert_eq "coolbash doctor renvoie 0 sur une installation saine" "0" "${rc}"
assert_contains "doctor vérifie la version de bash" "${doc}" "bash"
assert_contains "doctor vérifie la ligne du .bashrc" "${doc}" ".bashrc"
assert_contains "doctor compte les modules" "${doc}" "modules"
assert_contains "doctor compte les thèmes de citations" "${doc}" "citations"
assert_eq "coolbash fortune affiche une citation" "1" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune 2>&1 | grep -c .)"
fc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune chuck 2>&1)"
assert_contains "coolbash fortune <thème> respecte le thème" "${fc,,}" "chuck norris"
assert_contains "coolbash help mentionne fortune" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "fortune"
# fortune --add : ajoute à un thème personnel (perso par défaut)
fa="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add "Ma première citation" 2>&1)"
assert_file "fortune --add crée ~/.coolbash/fortunes/perso.txt" "${home}/.coolbash/fortunes/perso.txt"
assert_contains "fortune --add annonce le fichier et le nombre" "${fa}" "perso.txt"
HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add "Une deuxième" boulot >/dev/null 2>&1
assert_eq "fortune --add <texte> <thème> écrit dans le thème demandé" "Une deuxième" "$(cat "${home}/.coolbash/fortunes/boulot.txt")"
assert_eq "fortune --add sans texte → erreur, code 1" "1" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add >/dev/null 2>&1; echo $?)"
assert_eq "…et le thème perso est tiré par coolbash fortune perso" "Ma première citation" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune perso)"
# bench : N démarrages, moyenne, et le détail par module
bn="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" bench 2 2>&1)"
assert_contains "coolbash bench annonce la moyenne" "${bn}" "moyenne"
assert_eq "coolbash bench affiche des ms" "1" "$(printf '%s\n' "${bn}" | grep -cE 'moyenne[^0-9]*[0-9]+ ms')"
assert_contains "coolbash bench détaille les modules" "${bn}" "50-prompt"
assert_contains "coolbash help mentionne bench" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "bench"
assert_contains "doctor vérifie la locale" "${doc}" "locale"
: >"${home}/.bashrc"
doc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" doctor 2>&1)"
rc=$?
assert_eq "doctor échoue si le .bashrc ne charge pas CoolBash" "1" "${rc}"
assert_contains "…et le dit" "${doc}" "✘"

# --- config : réglages effectifs ---------------------------------------------
cfg="$(COOLBASH_PROMPT_MIN_MS=250 bash "${COOLBASH_TEST_ROOT}/cli/coolbash" config 2>&1)"
assert_contains "config liste les réglages" "${cfg}" "COOLBASH_PROMPT_ICONS"
assert_contains "config montre une valeur définie" "${cfg}" "250"
assert_contains "config montre la valeur par défaut des autres" "${cfg}" "30000"
# shellcheck disable=SC2016
inshell="$(HOME="${COOLBASH_TEST_TMP}" MOTD_DISABLE=1 COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" bash --norc --noprofile -c 'source "$1" init; COOLBASH_PS0_STAMP=0; coolbash config' _ "${COOLBASH_TEST_ROOT}/cli/coolbash" 2>&1)"
assert_eq "coolbash config voit les variables non exportées du shell courant" "1" "$(printf '%s\n' "${inshell}" | grep -E 'COOLBASH_PS0_STAMP +0 ' | grep -c 'défini')"
while read -r v; do
  assert_contains "config connaît ${v} (documentée dans le README)" "${cfg}" "${v}"
done < <(grep -oE '\| `COOLBASH_[A-Z0-9_]+' "${COOLBASH_TEST_ROOT}/README.md" | grep -oE 'COOLBASH_[A-Z0-9_]+' | sort -u)
assert_contains "coolbash help mentionne config" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "config"

t_done
