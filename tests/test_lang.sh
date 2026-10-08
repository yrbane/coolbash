#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : messages traduits (share/lang) — français par défaut, anglais quand la
#         langue de l'utilisateur n'est pas le français ; la table ne rouille pas.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
WS="${COOLBASH_TEST_ROOT}/modules/42-workspace.bash"
CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"
export MOTD_DISABLE=1

# FR : lg [VAR=val…] 'code' — options de env, puis le code après 00-core et 42-workspace.
lg() {
  local code="${*: -1}"
  env -u COOLBASH_LANG -u LC_ALL -u LC_MESSAGES -u LANG "${@:1:$#-1}" HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; eval "$3"' _ "${CORE}" "${WS}" "${code}" 2>&1
}

# --- la table ne rouille pas : chaque clé existe encore dans le source ------------------
missing="$(bash --norc --noprofile -c '
  declare -gA COOLBASH_MSG; source "$1/share/lang/en.bash"
  for k in "${!COOLBASH_MSG[@]}"; do
    grep -rqF -- "$k" "$1/cli" "$1/modules" && continue
    grep -rqF -- "${k//\"/\\\"}" "$1/cli" "$1/modules" && continue
    printf "%s\n" "$k"
  done' _ "${COOLBASH_TEST_ROOT}")"
assert_empty "en.bash : chaque clé est un texte encore présent dans cli/ ou modules/" "${missing}"
n_keys="$(bash --norc --noprofile -c 'declare -gA COOLBASH_MSG; source "$1"; echo "${#COOLBASH_MSG[@]}"' _ "${COOLBASH_TEST_ROOT}/share/lang/en.bash")"
assert_eq "en.bash : plus de 300 messages traduits" "1" "$([[ "${n_keys}" -gt 300 ]] && echo 1 || echo 0)"
assert_empty "en.bash : aucune traduction vide" "$(bash --norc --noprofile -c 'declare -gA COOLBASH_MSG; source "$1"; for k in "${!COOLBASH_MSG[@]}"; do [[ -n "${COOLBASH_MSG[$k]}" ]] || echo "$k"; done' _ "${COOLBASH_TEST_ROOT}/share/lang/en.bash")"

# --- détection de la langue --------------------------------------------------------------
assert_eq "sans rien : français" "fr|todo : pas de tâche n° 9" "$(lg 'printf "%s|" "$COOLBASH_LANG"; todo done 9')"
assert_eq "LANG=C.UTF-8 : français" "fr" "$(lg LANG=C.UTF-8 'echo "$COOLBASH_LANG"')"
assert_eq "LANG=fr_FR.UTF-8 : français" "fr" "$(lg LANG=fr_FR.UTF-8 'echo "$COOLBASH_LANG"')"
assert_eq "LANG=en_US.UTF-8 : anglais" "en|todo: no task #9" "$(lg LANG=en_US.UTF-8 'printf "%s|" "$COOLBASH_LANG"; todo done 9')"
assert_eq "LC_ALL=de_DE.UTF-8 : langue de, table anglaise en repli" "de|todo: no task #9" "$(lg LANG=fr_FR.UTF-8 LC_ALL=de_DE.UTF-8 'printf "%s|" "$COOLBASH_LANG"; todo done 9' 2>/dev/null | grep -v setlocale)"
assert_eq "LC_MESSAGES prime sur LANG" "en" "$(lg LANG=fr_FR.UTF-8 LC_MESSAGES=en_GB.UTF-8 'echo "$COOLBASH_LANG"')"
assert_eq "COOLBASH_LANG=en force l'anglais" "todo: no task #9" "$(lg COOLBASH_LANG=en LANG=fr_FR.UTF-8 'todo done 9')"
assert_eq "COOLBASH_LANG=fr force le français" "todo : pas de tâche n° 9" "$(lg COOLBASH_LANG=fr LANG=en_US.UTF-8 'todo done 9')"
assert_eq "un LANG choisi (en_US) n'est plus écrasé par un LC_ALL français" "en_US.UTF-8|" "$(lg LANG=en_US.UTF-8 'printf "%s|%s" "$LANG" "${LC_ALL:-}"')"
assert_eq "_coolbash_say traduit le format et garde les arguments" "retry: giving up after 3 attempts" "$(lg COOLBASH_LANG=en '_coolbash_say "retry : abandon après %s essais\n" 3')"
assert_eq "un texte absent de la table reste tel quel" "texte inconnu %s" "$(lg COOLBASH_LANG=en '_coolbash_t "texte inconnu %s"')"

# --- CLI et setup --------------------------------------------------------------------------
cl() { env -u LC_ALL -u LC_MESSAGES "$@" HOME="${COOLBASH_TEST_TMP}" bash "${CLI}" 2>&1; }
cli_en() { env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=en HOME="${COOLBASH_TEST_TMP}" bash "${CLI}" "$@" 2>&1; }
cli_fr() { env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=fr HOME="${COOLBASH_TEST_TMP}" bash "${CLI}" "$@" 2>&1; }
assert_contains "help en anglais : sections et lignes" "$(cli_en help)" "Everyday"
assert_contains "…et le slogan" "$(cli_en help)" "a modern, fast and documented bash"
assert_contains "help en français inchangé" "$(cli_fr help)" "Au quotidien"
assert_contains "help <commande> en anglais" "$(cli_en help quiet)" "presentation mode"
assert_contains "config : descriptions en anglais" "$(cli_en config)" "minimal shell"
assert_contains "config : COOLBASH_LANG est un réglage connu" "$(cli_fr config)" "COOLBASH_LANG"
assert_contains "doctor en anglais" "$(cli_en doctor)" "Required:"
assert_contains "deps en anglais : rôles traduits" "$(cli_en deps)" "git segment of the prompt"
assert_contains "erreur en anglais (fortune --search sans mot)" "$(cli_en fortune --search)" "usage: coolbash fortune --search"
assert_contains "setup --defaults en anglais" "$(env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=en HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/lang-pfx" bash "${COOLBASH_TEST_ROOT}/cli/coolbash-setup" --defaults 2>&1)" "interactive configuration"
assert_contains "…questions traduites" "$(env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=en HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/lang-pfx2" bash "${COOLBASH_TEST_ROOT}/cli/coolbash-setup" --defaults 2>&1)" "Git segment"
assert_contains "setup en français inchangé" "$(env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=fr HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/lang-pfx3" bash "${COOLBASH_TEST_ROOT}/cli/coolbash-setup" --defaults 2>&1)" "configuration interactive"

# --- installation et ~/.bashrc compilé ----------------------------------------------------
lh="${COOLBASH_TEST_TMP}/lhome"
mkdir -p "${lh}"
make_fake_clone "${lh}/clone"
make -s -C "${lh}/clone" install PREFIX="${lh}/.coolbash" BASHRC="${lh}/.bashrc" >/dev/null
assert_file "make install copie share/lang/en.bash" "${lh}/.coolbash/share/lang/en.bash"
assert_contains "init en anglais : le temps de démarrage" "$(env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=en HOME="${lh}" COOLBASH_PREFIX="${lh}/.coolbash" bash --norc --noprofile -ic 'source "$1" init' _ "${lh}/.coolbash/cli/coolbash" 2>/dev/null)" "⚡ startup"
HOME="${lh}" COOLBASH_PREFIX="${lh}/.coolbash" bash "${lh}/.coolbash/cli/coolbash" compile "${lh}/compiled.bashrc" >/dev/null 2>&1
assert_contains "compile inline la table et l'initialise" "$(cat "${lh}/compiled.bashrc")" '_coolbash_lang_init "${COOLBASH_PREFIX}/share/lang"'
# shellcheck disable=SC2088  # FR : le tilde est dans un libellé
assert_eq "bashrc compilé : anglais quand la langue l'est" "todo: no task #9" "$(env -u LC_ALL -u LC_MESSAGES COOLBASH_LANG=en HOME="${lh}" COOLBASH_PREFIX="${lh}/.coolbash" COOLBASH_STARTUP_TIME=0 bash --norc --noprofile -ic 'source "$1"; todo done 9' _ "${lh}/compiled.bashrc" 2>&1 | tail -1)"
assert_eq "bashrc compilé : français sinon" "todo : pas de tâche n° 9" "$(env -u LC_ALL -u LC_MESSAGES -u COOLBASH_LANG LANG=C.UTF-8 HOME="${lh}" COOLBASH_PREFIX="${lh}/.coolbash" COOLBASH_STARTUP_TIME=0 bash --norc --noprofile -ic 'source "$1"; todo done 9' _ "${lh}/compiled.bashrc" 2>&1 | tail -1)"

t_done
