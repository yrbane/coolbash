#!/usr/bin/env bash
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
echo 'COOLBASH_TEST_ORDER+="c"' > "${mods}/90-last.bash"
echo 'COOLBASH_TEST_ORDER+="a"' > "${mods}/00-first.bash"
echo 'COOLBASH_TEST_ORDER+="b"' > "${mods}/50-middle.bash"
echo 'COOLBASH_TEST_ORDER+="X"' > "${mods}/not-a-module.txt"
order="$(COOLBASH_MODULE_DIR="${mods}" bash --norc --noprofile -c 'source "$1" init; echo "${COOLBASH_TEST_ORDER}"' _ "${CLI}")"
assert_eq "init charge les modules *.bash dans l'ordre lexical, et rien d'autre" "abc" "${order}"

# --- init : un module qui échoue n'empêche pas les suivants ------------------
mkdir -p "${mods}2"
echo 'false' > "${mods}2/10-fails.bash"
echo 'COOLBASH_TEST_OK=1' > "${mods}2/20-next.bash"
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

t_done
