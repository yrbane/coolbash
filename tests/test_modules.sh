#!/usr/bin/env bash
# =============================================================================
#  Test : chaque module se charge (après 00-core, la base commune dont les
#         autres peuvent dépendre : path_append, have…), sans erreur ni bruit
#         sur stderr, et renvoie 0 (piège classique : `[[ -f x ]] && . x` en
#         dernière ligne renvoie 1 quand le fichier manque).
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for m in "${COOLBASH_TEST_ROOT}"/modules/*.bash; do
  name="$(basename "$m")"
  out="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1" && source "$2"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "$m" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 && -z "${out}" ]]; then
    t_ok "${name} se charge après 00-core, renvoie 0, sans sortie"
  else
    t_fail "${name} — code ${rc}, sortie :"$'\n'"${out}"
  fi
done

out="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  for m in "$1"/modules/*.bash; do source "$m" || echo "échec: $m"; done' _ "${COOLBASH_TEST_ROOT}" 2>&1)"
assert_empty "tous les modules se chargent en séquence sans erreur" "${out}"

t_done
