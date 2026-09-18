#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : la CLI sourcée ne pollue pas le shell de l'utilisateur.
#  FR : ~/.bashrc fait `source cli/coolbash init`. Tout ce que le script
#       définit reste donc dans le shell. Une variable générique `PREFIX`
#       a déjà cassé nvm (« nvm is not compatible with the PREFIX environment
#       variable »). Ce test verrouille l'isolation : seules des variables
#       COOLBASH_* et des fonctions coolbash*/_coolbash_* peuvent apparaître.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"
EMPTY_MODULES="${COOLBASH_TEST_TMP}/no-modules"
mkdir -p "${EMPTY_MODULES}"

# FR : variables que bash lui-même fait apparaître après une commande.
BASH_NOISE='^(_|PIPESTATUS|OLDPWD|BASH_REMATCH|FUNCNAME|BASH_ARGV|BASH_ARGC|BASH_LINENO|BASH_SOURCE|COMP_WORDBREAKS|COLUMNS|LINES)$'

# --- 1. CLI seule (répertoire de modules vide) : diff avant/après ------------
leaked_vars="$(
  COOLBASH_MODULE_DIR="${EMPTY_MODULES}" bash --norc --noprofile -c '
    compgen -v | sort > "$1/before"
    source "$2" init
    compgen -v | sort > "$1/after"
    comm -13 "$1/before" "$1/after" | grep -Ev "$3" | grep -v "^COOLBASH_"
  ' _ "${COOLBASH_TEST_TMP}" "${CLI}" "${BASH_NOISE}"
)"
assert_empty "aucune variable non préfixée COOLBASH_ ne fuit de la CLI" "${leaked_vars}"

leaked_funcs="$(
  COOLBASH_MODULE_DIR="${EMPTY_MODULES}" bash --norc --noprofile -c '
    compgen -A function | sort > "$1/fbefore"
    source "$2" init
    compgen -A function | sort > "$1/fafter"
    comm -13 "$1/fbefore" "$1/fafter" | grep -Ev "^_?coolbash"
  ' _ "${COOLBASH_TEST_TMP}" "${CLI}"
)"
assert_empty "aucune fonction non préfixée coolbash ne fuit de la CLI" "${leaked_funcs}"

# --- 2. Reproduction exacte du garde-fou de nvm.sh ---------------------------
nvm_guard="$(
  COOLBASH_MODULE_DIR="${EMPTY_MODULES}" bash --norc --noprofile -c '
    source "$1" init
    if [ -n "${PREFIX-}" ] || [ -n "${NPM_CONFIG_PREFIX-}" ]; then
      echo "nvm is not compatible with the \"PREFIX\" environment variable"
    fi
  ' _ "${CLI}"
)"
assert_empty "nvm accepterait de se charger après l'init (PREFIX / NPM_CONFIG_PREFIX vides)" "${nvm_guard}"

# --- 3. Init complet avec les vrais modules : liste noire explicite ----------
blacklist="$(
  MOTD_DISABLE=1 COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" bash --norc --noprofile -c '
    source "$1" init
    for v in PREFIX NPM_CONFIG_PREFIX VERSION MODULE_DIR BASHRC; do
      [ -n "${!v-}" ] && echo "variable: $v=${!v}"
    done
    # FR : log/error sont des helpers utilisateur légitimes (40-functions),
    #      la fuite de ceux de la CLI est couverte par le test 1.
    for f in cmd_init cmd_help cmd_install cmd_update cmd_verify cmd_uninstall; do
      declare -F "$f" >/dev/null && echo "fonction: $f"
    done
    exit 0
  ' _ "${CLI}"
)"
assert_empty "init complet : ni PREFIX/VERSION/MODULE_DIR/BASHRC, ni cmd_*" "${blacklist}"

# --- 4. Le script ne doit pas contenir de `set -e` (fatal quand sourcé) ------
assert_failure "cli/coolbash ne contient pas de set -e (tuerait le shell de l'utilisateur)" \
  grep -Eq '^\s*set\s+-[a-zA-Z]*e' "${CLI}"

t_done
