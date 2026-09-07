#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : COOLBASH_MODE=safe (root par défaut) → shell minimal :
#         pas d'emoji, pas de git dans le prompt, pas de MOTD, pas de completion
#         différée. COOLBASH_DISABLE désactive des modules à la demande.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"
MODS="${COOLBASH_TEST_ROOT}/modules"
run() { HOME="${COOLBASH_TEST_TMP}" COOLBASH_MODULE_DIR="${MODS}" bash --norc --noprofile -c 'source "$1" init; shift; eval "$*"' _ "${CLI}" "$@" 2>&1; }

# --- mode par défaut ---------------------------------------------------------
assert_eq "utilisateur normal : COOLBASH_MODE=normal" "normal" "$(run 'echo "$COOLBASH_MODE"')"
assert_eq "COOLBASH_MODE est respecté s'il est déjà défini" "safe" "$(COOLBASH_MODE=safe run 'echo "$COOLBASH_MODE"')"

# --- mode safe ---------------------------------------------------------------
assert_eq "safe : pas d'emoji dans le prompt" "" "$(COOLBASH_MODE=safe run 'echo "$COOLBASH_PROMPT_EMOJI"')"
assert_eq "normal : un emoji de session" "1" "$(run '[[ -n "$COOLBASH_PROMPT_EMOJI" ]] && echo 1')"
assert_eq "safe : segment git désactivé même dans un dépôt" "" "$(cd "${COOLBASH_TEST_ROOT}" && COOLBASH_MODE=safe run '_coolbash_prompt_git')"
assert_eq "safe : MOTD désactivé" "off" "$(MOTD_DISABLE='' COOLBASH_MODE=safe run '_coolbash_motd_enabled && echo on || echo off')"
assert_eq "normal : MOTD activé" "on" "$(MOTD_DISABLE='' run '_coolbash_motd_enabled && echo on || echo off')"
assert_eq "MOTD_DISABLE reste honoré" "off" "$(MOTD_DISABLE=1 run '_coolbash_motd_enabled && echo on || echo off')"
assert_eq "safe : pas de chargeur de completion différé" "" "$(COOLBASH_MODE=safe run 'complete -p -D 2>/dev/null')"
assert_contains "normal : chargeur de completion différé en place" "$(run 'complete -p -D 2>/dev/null')" "_coolbash_completion_lazy"

# --- COOLBASH_DISABLE --------------------------------------------------------
assert_eq "COOLBASH_DISABLE=70-motd : le module n'est pas chargé" "" "$(COOLBASH_DISABLE="70-motd" run 'declare -F _coolbash_motd')"
assert_eq "COOLBASH_DISABLE accepte le numéro seul" "" "$(COOLBASH_DISABLE="70" run 'declare -F _coolbash_motd')"
assert_eq "COOLBASH_DISABLE accepte le nom seul" "" "$(COOLBASH_DISABLE="motd" run 'declare -F _coolbash_motd')"
assert_eq "COOLBASH_DISABLE : plusieurs modules, les autres restent chargés" "_coolbash_prompt_build" \
  "$(COOLBASH_DISABLE="70-motd 33-devtools" run 'declare -F _coolbash_motd; alias fix 2>/dev/null; declare -F _coolbash_prompt_build')"

t_done
