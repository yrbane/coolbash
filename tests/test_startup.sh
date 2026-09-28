#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : temps de démarrage affiché à l'ouverture d'un shell interactif.
#  FR : « le bash est lent à lancer » — la première réponse est un chiffre.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"

# FR : un shell interactif complet (sans tty), stdout seulement.
startup_i() {
  printf 'source "%s" init\n' "${CLI}" \
    | env "$@" MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
      bash --norc --noprofile -i 2>/dev/null
}

# --- affichage par défaut ------------------------------------------------------
out="$(startup_i)"
assert_contains "un shell interactif affiche son temps de démarrage" "${out}" "démarrage"
assert_eq "le temps total est un nombre de ms" "1" "$(printf '%s\n' "${out}" | grep -cE 'démarrage .*[0-9]+ ms')"
assert_eq "la part de CoolBash est indiquée à côté" "1" "$(printf '%s\n' "${out}" | grep -cE 'CoolBash [0-9]+ ms')"

# --- shell non interactif : muet -----------------------------------------------
out="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
  bash --norc --noprofile -c 'source "$1" init' _ "${CLI}" 2>&1)"
assert_not_contains "un shell non interactif (script) n'affiche rien" "${out}" "démarrage"

# --- COOLBASH_STARTUP_TIME=0 : muet ---------------------------------------------
out="$(startup_i COOLBASH_STARTUP_TIME=0)"
assert_not_contains "COOLBASH_STARTUP_TIME=0 coupe l'affichage" "${out}" "démarrage"

# --- verbose : détail par module ------------------------------------------------
out="$(startup_i COOLBASH_STARTUP_TIME=verbose)"
assert_eq "verbose liste le temps de chaque module" "1" "$(printf '%s\n' "${out}" | grep -cE '^ +50-prompt +[0-9]+ ms')"
assert_contains "verbose garde la ligne de total" "${out}" "démarrage"

# --- re-source dans un shell déjà ouvert -----------------------------------------
out="$(printf 'source "%s" init\nsource "%s" init\n' "${CLI}" "${CLI}" \
  | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
    bash --norc --noprofile -i 2>/dev/null | grep -c 'démarrage')"
assert_eq "un second source ~/.bashrc ré-affiche le temps (sans l'âge du processus)" "2" "${out}"
out="$(printf 'source "%s" init\nsleep 1\nsource "%s" init\n' "${CLI}" "${CLI}" \
  | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
    bash --norc --noprofile -i 2>/dev/null | grep 'démarrage' | tail -1 | grep -oE '[0-9]+ ms' | head -1 | grep -oE '[0-9]+')"
if [[ "${out}" =~ ^[0-9]+$ ]] && (( out < 1000 )); then
  t_ok "le second affichage ne compte pas le temps écoulé depuis l'ouverture du shell (${out} ms)"
else
  t_fail "le second affichage compte l'âge du shell : ${out} ms"
fi

# --- âge du processus : mesure Linux ---------------------------------------------
out="$(printf 'sleep 1\nsource "%s" init\n' "${CLI}" \
  | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
    bash --norc --noprofile -i 2>/dev/null | grep 'démarrage' | grep -oE '[0-9]+ ms' | head -1 | grep -oE '[0-9]+')"
if [[ "${out}" =~ ^[0-9]+$ ]] && (( out >= 1000 )); then
  t_ok "le total inclut ce qui précède la ligne source (${out} ms après un sleep 1)"
else
  t_fail "le total ignore ce qui précède la ligne source : ${out} ms après un sleep 1"
fi
assert_contains "quand CoolBash n'est pas en cause, l'affichage le dit" \
  "$(printf 'sleep 1\nsource "%s" init\n' "${CLI}" \
    | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
      bash --norc --noprofile -i 2>/dev/null)" "vient d'ailleurs"

# --- config ---------------------------------------------------------------------
assert_contains "config connaît COOLBASH_STARTUP_TIME" "$(bash "${CLI}" config 2>&1)" "COOLBASH_STARTUP_TIME"

t_done
