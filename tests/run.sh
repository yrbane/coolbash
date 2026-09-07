#!/usr/bin/env bash
# =============================================================================
#  CoolBash — lanceur de tests (zéro dépendance : bash uniquement)
#  Usage : bash tests/run.sh [motif]   ex. bash tests/run.sh cli
# =============================================================================
set -u

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
(( fail == 0 ))
