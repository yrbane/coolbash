#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : budget de démarrage — `init` complet doit rester rapide.
#  FR : « performant » se mesure. Seuil réglable : COOLBASH_TEST_INIT_BUDGET_MS.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"
budget="${COOLBASH_TEST_INIT_BUDGET_MS:-200}"
runs=5
total=0
for _ in $(seq 1 "${runs}"); do
  t0="${EPOCHREALTIME//[.,]/}"
  MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" \
    bash --norc --noprofile -c 'source "$1" init' _ "${CLI}" >/dev/null 2>&1
  t1="${EPOCHREALTIME//[.,]/}"
  total=$((total + (t1 - t0) / 1000))
done
avg=$((total / runs))
if ((avg <= budget)); then
  t_ok "init complet en ${avg} ms en moyenne (budget ${budget} ms)"
else
  t_fail "init complet trop lent : ${avg} ms en moyenne (budget ${budget} ms)"
fi

t_done
