# shellcheck shell=bash
# =============================================================================
#  CoolBash — mini-bibliothèque d'assertions pour les tests (zéro dépendance)
#  FR : chaque fichier tests/test_*.sh la source, enchaîne des assert_* puis
#       appelle t_done, qui fixe le code de retour du fichier.
# =============================================================================

COOLBASH_TEST_FAILS=0
COOLBASH_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# FR : chemin physique — sous macOS, mktemp rend /var/folders/… qui est un lien
#      vers /private/var/… : make (abspath) et `pwd -P` verraient un autre chemin.
COOLBASH_TEST_TMP="$(cd "$(mktemp -d)" && pwd -P)"
# FR : le `bash` des tests est celui qui les lance. Sous macOS, /bin/bash est un
#      3.2 : un `bash` résolu ailleurs dans le PATH ne testerait pas le même shell.
case ":${PATH}:" in
  ":${BASH%/*}:"*) ;;
  *) export PATH="${BASH%/*}:${PATH}" ;;
esac
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
# FR : idem pour le terminal : lancés depuis iTerm2, les tests d'images voyaient
#      tous « iterm ».
unset ITERM_SESSION_ID
# FR : le /bin/bash de macOS, en interactif, conseille de passer à zsh : pas dans les sorties testées.
export BASH_SILENCE_DEPRECATION_WARNING=1
export COOLBASH_PROMPT_CONTAINER_MARKERS=/nonexistent/coolbash-test
case "${LC_ALL:-${LANG:-}}" in
  *[Uu][Tt][Ff]*) ;;
  *)
    # FR : macOS (avant la 15) n'a pas de locale C.UTF-8.
    if [[ "${OSTYPE:-}" == darwin* ]]; then export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; else export LANG=C.UTF-8 LC_ALL=C.UTF-8; fi
    ;;
esac

# --- portabilité GNU / BSD (macOS) ----------------------------------------------
# FR : sed_i <expression> <fichier> — `sed -i` n'a pas la même syntaxe chez GNU et BSD.
sed_i() {
  sed "$1" "$2" >"$2.sed-tmp" && cat "$2.sed-tmp" >|"$2" && rm -f "$2.sed-tmp"
}
# FR : t_count — `wc -l` sans les espaces que BSD met devant le nombre.
t_count() { wc -l | tr -d ' '; }
# FR : t_inode <fichier> — `stat -c %i` est GNU, `ls -i` est partout.
t_inode() {
  local out
  out="$(ls -i "$1")" || return 1
  out="${out#"${out%%[![:space:]]*}"}"
  printf '%s\n' "${out%% *}"
}
# FR : "${T_TTY}" <commande> — la commande sous un vrai tty. `script -qec`
#      (util-linux) ou `script -q /dev/null …` (BSD, macOS). Un exécutable plutôt
#      qu'une fonction : il passe derrière `env VAR=… PATH=…`.
t_has_tty() { command -v script >/dev/null 2>&1; }
T_TTY="${COOLBASH_TEST_TMP}/t_tty"
# shellcheck disable=SC2016  # FR : le $1 est celui du script généré
if script -qec true /dev/null >/dev/null 2>&1; then
  printf '#!%s\nexec script -qec "$1" /dev/null\n' "${BASH}" >"${T_TTY}"
else
  printf '#!%s\nexec script -q /dev/null "%s" -c "$1"\n' "${BASH}" "${BASH}" >"${T_TTY}"
fi
chmod +x "${T_TTY}"
# FR : t_timeout <secondes> <commande…> — timeout(1) n'existe pas sous macOS.
t_timeout() {
  local s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"; else "$@"; fi
}
# FR : t_bash_ge 404 — le bash des tests est-il au moins un 4.4 ? Certaines
#      assertions portent sur ce que bash 3.2 (macOS) n'a pas : PS0, complete -D,
#      command_not_found_handle. Elles sont alors marquées « ignoré ».
t_bash_ge() { ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= $1)); }
t_linux() { [[ -r /proc/uptime ]]; }
t_darwin() { [[ "${OSTYPE:-}" == darwin* ]]; }

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
    "${COOLBASH_TEST_ROOT}/.editorconfig" "${COOLBASH_TEST_ROOT}/CHANGELOG.md" \
    "${COOLBASH_TEST_ROOT}/packaging" "${COOLBASH_TEST_ROOT}/scripts" "${dest}/"
}

t_done() {
  if ((COOLBASH_TEST_FAILS > 0)); then
    printf '  → %d assertion(s) en échec\n' "${COOLBASH_TEST_FAILS}"
    exit 1
  fi
  exit 0
}
