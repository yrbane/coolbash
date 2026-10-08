#!/usr/bin/env bash
# =============================================================================
#  CoolBash — lanceur de tests (zéro dépendance : bash uniquement)
#  Usage : bash tests/run.sh [motif]   ex. bash tests/run.sh cli
# =============================================================================
set -u
# FR : l'entrée standard n'est jamais un terminal pendant les tests : lancés
#      depuis un terminal, gsw ouvrirait fzf et setup poserait ses questions.
exec </dev/null
# FR : les réglages du shell de l'utilisateur (coolbash setup écrit des export :
#      COOLBASH_PROMPT_THEME, COOLBASH_INSTALL_MODE…) ne doivent pas entrer dans
#      les tests : chaque test pose ce dont il a besoin. Seules les variables de
#      la suite elle-même (COOLBASH_TEST_*) restent.
for v in $(compgen -A variable COOLBASH_); do
  [[ "$v" == COOLBASH_TEST_* ]] || unset "$v"
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pattern="${1:-}"
pass=0
fail=0

for t in "${ROOT}"/tests/test_*"${pattern}"*.sh; do
  [[ -f "$t" ]] || continue
  name="$(basename "$t" .sh)"
  printf '\e[1m▶ %s\e[0m\n' "${name}"
  if bash "$t"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done

printf '\n%d fichier(s) OK, %d en échec\n' "${pass}" "${fail}"
((fail == 0))
