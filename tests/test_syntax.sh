#!/usr/bin/env bash
# =============================================================================
#  Test : syntaxe bash de tous les scripts + shellcheck quand il est présent.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "${COOLBASH_TEST_ROOT}" || exit 1

for f in cli/coolbash install.sh modules/*.bash tests/*.sh; do
  assert_success "bash -n ${f}" bash -n "$f"
done

if command -v shellcheck >/dev/null 2>&1; then
  assert_success "shellcheck cli/coolbash install.sh tests/*.sh" shellcheck cli/coolbash install.sh tests/*.sh
  assert_success "shellcheck -S error modules/*.bash" shellcheck -S error modules/*.bash
else
  t_skip "shellcheck absent"
fi

t_done
