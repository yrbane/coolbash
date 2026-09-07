#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
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

# --- 00-core ne doit jamais imposer une locale absente de la machine ---------
# FR : bug vu en CI (Ubuntu sans fr_FR) : « setlocale: LC_ALL: cannot change locale ».
# shellcheck disable=SC2016  # FR : script inline volontairement en simple quotes
chosen="$(env -u LANG -u LC_ALL bash --norc --noprofile -c 'source "$1" 2>&1; echo "${LC_ALL}"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" | tail -1)"
normalized="$(echo "${chosen}" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
if locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qx "${normalized}"; then
  t_ok "00-core choisit une locale présente sur la machine (${chosen})"
else
  t_fail "00-core impose une locale absente : ${chosen}"
fi
# shellcheck disable=SC2016
out="$(env -u LANG -u LC_ALL MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  for m in "$1"/modules/*.bash; do source "$m"; done; ls / >/dev/null' _ "${COOLBASH_TEST_ROOT}" 2>&1)"
assert_empty "sans LANG/LC_ALL, le chargement complet n'émet aucun avertissement setlocale" "${out}"

t_done
