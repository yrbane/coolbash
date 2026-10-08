# shellcheck shell=bash
# =============================================================================
#  CoolBash — mini-bibliothèque d'assertions pour les tests (zéro dépendance)
#  FR : chaque fichier tests/test_*.sh la source, enchaîne des assert_* puis
#       appelle t_done, qui fixe le code de retour du fichier.
# =============================================================================

COOLBASH_TEST_FAILS=0
COOLBASH_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COOLBASH_TEST_TMP="$(mktemp -d)"
trap 'rm -rf "${COOLBASH_TEST_TMP}"' EXIT
# FR : AUCUN test ne voit le vrai HOME. En 0.9.0-0.9.2, test_make lançait
#      `make uninstall` avec le HOME de l'utilisateur : la police installée dans
#      ~/.local/share/fonts/coolbash-nerd était supprimée à chaque `make test`,
#      donc à chaque `coolbash update`.
export HOME="${COOLBASH_TEST_TMP}/home"
mkdir -p "${HOME}"
unset XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME
# FR : variables de SDK héritées du shell qui lance les tests (35-toolchains les respecte).
unset NVM_DIR NVM_BIN NVM_INC PNPM_HOME ANDROID_HOME
# FR : aucun test ne télécharge de police ; test_font.sh la réactive avec une
#      archive locale.
export COOLBASH_FONT=0
# FR : jamais de git fetch en arrière-plan pendant les tests (les shells interactifs de bench le déclencheraient).
export COOLBASH_UPDATE_CHECK=0
# FR : le setup lancé par make install ne pose jamais de question pendant les tests.
export COOLBASH_SETUP_DEFAULTS=1
# FR : sans locale UTF-8 (conteneur Debian nu, `su -c`), bash laisse les
#      `$'\uXXXX'` des tests tels quels et toutes les assertions d'icônes
#      échouent alors que le module est correct. Vu en CI Debian 13.
# FR : les tests ne dépendent pas de l'endroit d'où on les lance. Depuis une
#      session SSH ou un conteneur, le prompt change (à raison) d'icône d'hôte
#      et deux assertions tombaient : `coolbash update` refusait alors
#      d'installer. Chaque test qui veut SSH ou un conteneur le dit lui-même.
unset SSH_CONNECTION SSH_TTY SSH_CLIENT
export COOLBASH_PROMPT_CONTAINER_MARKERS=/nonexistent/coolbash-test
case "${LC_ALL:-${LANG:-}}" in
  *[Uu][Tt][Ff]*) ;;
  *) export LANG=C.UTF-8 LC_ALL=C.UTF-8 ;;
esac

t_ok() { printf '  \e[32m✔\e[0m %s\n' "$1"; }
t_fail() {
  printf '  \e[31m✘\e[0m %s\n' "$1"
  COOLBASH_TEST_FAILS=$((COOLBASH_TEST_FAILS + 1))
}
t_skip() { printf '  \e[33m–\e[0m %s (ignoré)\n' "$1"; }

# assert_eq <description> <attendu> <obtenu>
assert_eq() {
  if [[ "$2" == "$3" ]]; then t_ok "$1"; else t_fail "$1 — attendu « $2 », obtenu « $3 »"; fi
}

# assert_empty <description> <valeur>
assert_empty() {
  if [[ -z "$2" ]]; then t_ok "$1"; else t_fail "$1 — obtenu :"$'\n'"$2"; fi
}

# assert_contains <description> <texte> <fragment>
assert_contains() {
  if [[ "$2" == *"$3"* ]]; then t_ok "$1"; else t_fail "$1 — « $3 » absent de :"$'\n'"$2"; fi
}

# assert_not_contains <description> <texte> <fragment>
assert_not_contains() {
  if [[ "$2" != *"$3"* ]]; then t_ok "$1"; else t_fail "$1 — « $3 » présent dans :"$'\n'"$2"; fi
}

# assert_success <description> <commande...>
assert_success() {
  local desc="$1" out rc
  shift
  out="$("$@" 2>&1)"
  rc=$?
  if ((rc == 0)); then t_ok "$desc"; else t_fail "$desc — code $rc :"$'\n'"$out"; fi
}

# assert_failure <description> <commande...>
assert_failure() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then t_fail "$desc — la commande a réussi alors qu'un échec était attendu"; else t_ok "$desc"; fi
}

assert_file() { if [[ -f "$2" ]]; then t_ok "$1"; else t_fail "$1 — fichier absent : $2"; fi; }
assert_no_path() { if [[ ! -e "$2" ]]; then t_ok "$1"; else t_fail "$1 — chemin encore présent : $2"; fi; }

# FR : copie jetable du dépôt (Makefile, cli, modules) pour les tests qui
#      manipulent un clone — on ne joue JAMAIS install/uninstall sur le vrai.
make_fake_clone() {
  local dest="$1"
  mkdir -p "${dest}"
  cp -r "${COOLBASH_TEST_ROOT}/Makefile" "${COOLBASH_TEST_ROOT}/install.sh" "${COOLBASH_TEST_ROOT}/cli" \
    "${COOLBASH_TEST_ROOT}/modules" "${COOLBASH_TEST_ROOT}/tests" "${COOLBASH_TEST_ROOT}/share" \
    "${COOLBASH_TEST_ROOT}/.editorconfig" "${COOLBASH_TEST_ROOT}/CHANGELOG.md" "${dest}/"
}

t_done() {
  if ((COOLBASH_TEST_FAILS > 0)); then
    printf '  → %d assertion(s) en échec\n' "${COOLBASH_TEST_FAILS}"
    exit 1
  fi
  exit 0
}
