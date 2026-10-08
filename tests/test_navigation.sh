#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 41-navigation — j (saut par fréquence), bd, h, hstats,
#         command_not_found_handle.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
NAV="${COOLBASH_TEST_ROOT}/modules/41-navigation.bash"
export MOTD_DISABLE=1
PFX="${COOLBASH_TEST_TMP}/.coolbash"
mkdir -p "${PFX}"

# FR : exécute du bash après chargement de 00-core puis 41-navigation.
nav() { HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash --norc --noprofile -c 'source "$1"; source "$2"; shift 2; eval "$*"' _ "${CORE}" "${NAV}" "$@" 2>&1; }

# --- j : saut de dossier par fréquence -----------------------------------------
mkdir -p "${COOLBASH_TEST_TMP}/Dev/coolbash" "${COOLBASH_TEST_TMP}/Dev/cooking" "${COOLBASH_TEST_TMP}/Musique"
nav 'cd "$HOME/Dev/coolbash"; _coolbash_dirs_track; cd "$HOME/Musique"; _coolbash_dirs_track; cd "$HOME/Dev/coolbash"; _coolbash_dirs_track; cd "$HOME/Dev/cooking"; _coolbash_dirs_track' >/dev/null
assert_file "les cd sont notés dans ~/.coolbash/dirs" "${PFX}/dirs"
assert_eq "un même dossier n'est pas noté deux fois de suite sans changement" "1" "$(nav 'cd "$HOME/Musique"; _coolbash_dirs_track; _coolbash_dirs_track; _coolbash_dirs_track; grep -c "Musique" "$COOLBASH_PREFIX/dirs"' | tail -1 | awk '{print ($1>=2 && $1<=2)?1:0}')"
assert_eq "j coolb → le dossier le plus fréquent qui correspond" "${COOLBASH_TEST_TMP}/Dev/coolbash" "$(nav 'j coolb >/dev/null; pwd')"
assert_eq "j cook → l'autre" "${COOLBASH_TEST_TMP}/Dev/cooking" "$(nav 'j cook >/dev/null; pwd')"
assert_eq "j MUS (casse ignorée)" "${COOLBASH_TEST_TMP}/Musique" "$(nav 'j MUS >/dev/null; pwd')"
assert_eq "j motif-inconnu → erreur, code 1, on ne bouge pas" "1 ${COOLBASH_TEST_TMP}" "$(cd "${COOLBASH_TEST_TMP}" && nav 'j zzzz >/dev/null 2>&1; echo "$? $(pwd)"')"
jl="$(nav 'j')"
assert_contains "j sans argument liste les dossiers connus (coolbash)" "${jl}" "coolbash"
assert_contains "…et Musique" "${jl}" "Musique"
assert_eq "…le plus récent parmi les plus visités en tête" "${COOLBASH_TEST_TMP}/Musique" "$(printf '%s\n' "${jl}" | head -1)"
rm -rf "${COOLBASH_TEST_TMP}/Dev/cooking"
assert_eq "un dossier disparu est ignoré (et n'est plus proposé)" "1" "$(nav 'j cook >/dev/null 2>&1; echo $?')"
assert_eq "_coolbash_dirs_track est dans PROMPT_COMMAND" "1" "$(nav 'printf %s "${PROMPT_COMMAND[*]}"' | grep -c _coolbash_dirs_track)"
assert_eq "COOLBASH_J=0 : rien n'est noté" "0" "$(
  rm -f "${PFX}/dirs"
  COOLBASH_J=0 nav 'cd "$HOME/Musique"; _coolbash_dirs_track; test -f "$COOLBASH_PREFIX/dirs" && echo 1 || echo 0'
)"
assert_contains "complétion : j <Tab> propose les dossiers connus" "$(nav 'cd "$HOME/Dev/coolbash"; _coolbash_dirs_track; COMP_WORDS=(j coo); COMP_CWORD=1; _coolbash_j_complete; printf "%s\n" "${COMPREPLY[@]}"')" "coolbash"

# --- bd : remonter jusqu'au parent nommé --------------------------------------------
deep="${COOLBASH_TEST_TMP}/Dev/coolbash/modules/prompt"
mkdir -p "${deep}"
assert_eq "bd coolbash remonte au parent exact" "${COOLBASH_TEST_TMP}/Dev/coolbash" "$(cd "${deep}" && nav 'bd coolbash >/dev/null; pwd')"
assert_eq "bd D : préfixe accepté (Dev)" "${COOLBASH_TEST_TMP}/Dev" "$(cd "${deep}" && nav 'bd D >/dev/null; pwd')"
assert_eq "bd inconnu → erreur, on ne bouge pas" "1 ${deep}" "$(cd "${deep}" && nav 'bd nulle-part >/dev/null 2>&1; echo "$? $(pwd)"')"
assert_eq "bd sans argument → usage, code 1" "1" "$(nav 'bd >/dev/null 2>&1; echo $?')"

# --- h / hstats : recherche et statistiques d'historique -----------------------------
hf="${COOLBASH_TEST_TMP}/histfile"
printf '#1700000000\ngit status\n#1700000010\ngit commit -m x\n#1700000020\nls -la\n#1700000030\ngit push\n#1700000040\nmake test\n' >|"${hf}"
assert_contains "h motif : les commandes qui correspondent" "$(HISTTIMEFORMAT='%F %T  ' HISTFILE="${hf}" nav 'set -o history; history -r; h commit')" "git commit -m x"
assert_eq "h motif : rien d'autre" "0" "$(HISTTIMEFORMAT='%F %T  ' HISTFILE="${hf}" nav 'set -o history; history -r; h commit' | grep -c 'ls -la')"
assert_contains "h motif : la date est affichée" "$(HISTTIMEFORMAT='%F %T  ' nav 'set -o history; history -s "git commit -m maintenant"; h commit')" "$(date +%F)"
st="$(HISTFILE="${hf}" nav 'hstats 3')"
assert_contains "hstats : la commande la plus fréquente d'abord (git ×3)" "$(printf '%s\n' "${st}" | grep -m1 -E '^ *[0-9]')" "git"
assert_contains "hstats : avec son pourcentage" "${st}" "60"
assert_eq "hstats N : N lignes" "3" "$(printf '%s\n' "${st}" | grep -cE '^ *[0-9]+ ')"

# --- command_not_found_handle : suggestion de paquet -----------------------------------
fb="${COOLBASH_TEST_TMP}/fbnav"
mkdir -p "${fb}"
printf '#!/bin/bash\n[[ "$1" == -Fq ]] && echo "extra/foobar-tools"\n' >|"${fb}/pacman"
chmod +x "${fb}/pacman"
cnf="$(printf 'source "%s"; source "%s"\nfoobar --version\necho "rc=$?"\n' "${CORE}" "${NAV}" | env PATH="${fb}:/usr/bin:/bin" HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${PFX}" bash --norc --noprofile -i 2>&1)"
assert_contains "commande introuvable : message" "${cnf}" "foobar"
assert_contains "…et le paquet qui la fournit (pacman -F)" "${cnf}" "extra/foobar-tools"
assert_contains "…code retour 127, comme bash" "${cnf}" "rc=127"
assert_eq "shell non interactif : pas de handler (scripts inchangés)" "0" "$(nav 'declare -F command_not_found_handle >/dev/null && echo 1 || echo 0')"
assert_eq "COOLBASH_CNF=0 : pas de handler" "0" "$(printf 'source "%s"; source "%s"\ndeclare -F command_not_found_handle >/dev/null && echo 1 || echo 0\n' "${CORE}" "${NAV}" | COOLBASH_CNF=0 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -i 2>/dev/null | tail -1)"

# --- 0.31.0 : complétion de bd — les dossiers parents --------------------------------
mkdir -p "${COOLBASH_TEST_TMP}/alpha/beta/gamma"
assert_eq "complétion de bd : les parents, du plus proche au plus lointain" "beta alpha" "$(cd "${COOLBASH_TEST_TMP}/alpha/beta/gamma" && nav 'COMP_WORDS=(bd ""); COMP_CWORD=1; _coolbash_bd_complete; echo "${COMPREPLY[0]} ${COMPREPLY[1]}"')"
assert_eq "…filtrés par le préfixe" "alpha" "$(cd "${COOLBASH_TEST_TMP}/alpha/beta/gamma" && nav 'COMP_WORDS=(bd al); COMP_CWORD=1; _coolbash_bd_complete; echo "${COMPREPLY[*]}"')"

t_done
