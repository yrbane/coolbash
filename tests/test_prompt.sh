#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 50-prompt — durée sans trap DEBUG (PS0 + EPOCHREALTIME),
#         segment git en un seul appel, code retour, isolation des noms.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
PROMPT="${COOLBASH_TEST_ROOT}/modules/50-prompt.bash"
export MOTD_DISABLE=1

# FR : exécute du bash après chargement de 00-core puis 50-prompt.
with_prompt() { HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; shift 2; eval "$*"' _ "${CORE}" "${PROMPT}" "$@" 2>&1; }

# --- 1. Plus aucun trap DEBUG, la durée passe par PS0 -----------------------
assert_empty "aucun trap DEBUG après chargement" "$(with_prompt 'trap -p DEBUG')"
assert_contains "PS0 mesure le départ via EPOCHREALTIME" "$(with_prompt 'printf %s "$PS0"')" "EPOCHREALTIME"
assert_contains "PS0 muet si horodatage et titre désactivés" "$(COOLBASH_PS0_STAMP=0 COOLBASH_PS0_TITLE=0 with_prompt 'printf "[%s]" "${PS0@P}"')" "[]"
stamp="$(TERM=dumb with_prompt 'printf "%s" "${PS0@P}"')"
assert_contains "PS0 affiche l'heure de départ (⏱)" "${stamp}" "⏱"
assert_eq "…au format HH:MM:SS, en gris, suivi d'un retour à la ligne" "1" "$(printf '%s' "${stamp}" | grep -cE $'\e\[2m  ⏱ [0-9]{2}:[0-9]{2}:[0-9]{2}\e\[0m$')"
assert_contains "PS0 met la commande dans le titre du terminal (xterm)" "$(TERM=xterm-256color with_prompt 'printf %s "$PS0"')" "_coolbash_prompt_ps0_title"
assert_eq "…mais pas sur un terminal sans titre (dumb)" "0" "$(TERM=dumb with_prompt 'printf %s "$PS0"' | grep -c ps0_title)"
assert_eq "…sauf si PROMPT_COMMAND pose déjà un titre (Arch)" "0" "$(TERM=xterm with_prompt 'PROMPT_COMMAND="printf \"\\033]0;x\\007\"; $PROMPT_COMMAND"; _coolbash_prompt_build; printf %s "$PS1"' | grep -c ']0;')"
assert_contains "PS1 remet le titre à user@host: dossier" "$(TERM=xterm with_prompt '_coolbash_prompt_build; printf %s "$PS1"')" '\e]0;\u@\h: \w\a'
assert_contains "COOLBASH_PS0_EXTRA est conservé en fin de PS0" "$(COOLBASH_PS0_EXTRA='MON-PS0' with_prompt 'printf %s "$PS0"')" "MON-PS0"
assert_eq "aucun \\[ \\] dans PS0 (bash les imprimerait)" "0" "$(with_prompt 'printf %s "$PS0"' | grep -cF '\[')"
title="$(printf 'source "%s"; source "%s"\ntrue\n' "${CORE}" "${PROMPT}" \
        | TERM=xterm HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -i 2>&1 | grep -c $'\e]0;true\a')"
assert_eq "en shell interactif, le titre reçoit la commande saisie" "1" "${title}"
assert_contains "_coolbash_prompt_build est dans PROMPT_COMMAND" "$(with_prompt 'printf %s "${PROMPT_COMMAND[*]}"')" "_coolbash_prompt_build"

# --- 2. Durée mesurée en shell interactif (PS0 réel) ------------------------
ms="$(printf 'source "%s"; source "%s"\nsleep 0.6\necho "ms=$COOLBASH_PROMPT_LAST_MS"\n' "${CORE}" "${PROMPT}" \
      | HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -i 2>/dev/null | grep -o 'ms=[0-9]*' | cut -d= -f2)"
if [[ "${ms:-0}" -ge 550 && "${ms:-0}" -lt 5000 ]]; then
  t_ok "la durée de « sleep 0.6 » est mesurée en ms (${ms} ms)"
else
  t_fail "durée mesurée incohérente : « ${ms} » ms"
fi

# --- 3. Formatage de la durée ------------------------------------------------
assert_eq "durée < seuil : segment vide" "" "$(with_prompt 'COOLBASH_PROMPT_LAST_MS=500 _coolbash_prompt_duration')"
assert_eq "1234 ms → 1.23s" "1.23s" "$(with_prompt 'COOLBASH_PROMPT_LAST_MS=1234 _coolbash_prompt_duration')"
assert_eq "65000 ms → 1m05s" "1m05s" "$(with_prompt 'COOLBASH_PROMPT_LAST_MS=65000 _coolbash_prompt_duration')"
assert_eq "seuil réglable (COOLBASH_PROMPT_MIN_MS)" "0.50s" "$(with_prompt 'COOLBASH_PROMPT_MIN_MS=100 COOLBASH_PROMPT_LAST_MS=500 _coolbash_prompt_duration')"

# --- 4. Code retour ----------------------------------------------------------
assert_eq "code 0 : rien" "" "$(with_prompt '_coolbash_prompt_status 0')"
assert_eq "code 3, sans icône : ✖ 3" "✖ 3" "$(COOLBASH_PROMPT_ICONS=0 with_prompt '_coolbash_prompt_status 3')"
assert_eq "code 3, icônes nerd : glyphe + 3" $'\uf057 3' "$(COOLBASH_PROMPT_ICONS=nerd with_prompt '_coolbash_prompt_status 3')"

# --- 5. Segment git : un seul appel, sans verrou -----------------------------
git_seg() { (cd "$1" && with_prompt '_coolbash_prompt_git'); }
repo="${COOLBASH_TEST_TMP}/repo"
bare="${COOLBASH_TEST_TMP}/bare.git"
git init -q --bare -b main "${bare}"
git clone -q "${bare}" "${repo}" 2>/dev/null
git -C "${repo}" config user.email t@t; git -C "${repo}" config user.name t
git -C "${repo}" checkout -q -b main 2>/dev/null
echo a > "${repo}/a"; git -C "${repo}" add a; git -C "${repo}" commit -qm a; git -C "${repo}" push -q -u origin main 2>/dev/null
assert_eq "dépôt propre : nom de branche seul" "main" "$(git_seg "${repo}")"
echo b > "${repo}/b"
assert_eq "fichier non suivi : ?" "main?" "$(git_seg "${repo}")"
git -C "${repo}" add b
assert_eq "fichier indexé : *" "main*" "$(git_seg "${repo}")"
echo aa > "${repo}/a"
assert_eq "indexé + modifié : *+" "main*+" "$(git_seg "${repo}")"
git -C "${repo}" commit -qam c
assert_eq "commit local non poussé : ↑1" "main↑1" "$(git_seg "${repo}")"
git -C "${repo}" checkout -q --detach HEAD~1
seg="$(git_seg "${repo}")"
assert_eq "HEAD détachée : sha court (7) + ↓1" "7" "${#seg}"
assert_eq "hors dépôt : vide" "" "$(git_seg "${COOLBASH_TEST_TMP}")"
assert_eq "COOLBASH_PROMPT_GIT=0 désactive le segment" "" "$(cd "${repo}" && with_prompt 'COOLBASH_PROMPT_GIT=0 _coolbash_prompt_git')"
assert_contains "le seul appel git est un status v2 sans verrou" "$(grep -c 'GIT_OPTIONAL_LOCKS=0 git status' "${PROMPT}")" "1"
assert_eq "aucun autre appel git dans le module (hors commentaires)" "1" "$(grep -cE '^[^#]*\bgit [a-z]' "${PROMPT}")"

# --- 6. Isolation : rien de générique ne fuit du prompt ----------------------
leaks="$(HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  source "$1"
  compgen -v | sort > "$3/pv"; compgen -A function | sort > "$3/pf"
  source "$2"
  compgen -v | sort > "$3/pv2"; compgen -A function | sort > "$3/pf2"
  comm -13 "$3/pv" "$3/pv2" | grep -Ev "^(COOLBASH_|PS0$|PS1$|PROMPT_COMMAND$|_$|PIPESTATUS$|BASH_REMATCH$)"
  comm -13 "$3/pf" "$3/pf2" | grep -Ev "^_coolbash_"
' _ "${CORE}" "${PROMPT}" "${COOLBASH_TEST_TMP}")"
assert_empty "50-prompt ne définit que COOLBASH_*, PS0/PS1/PROMPT_COMMAND et _coolbash_*" "${leaks}"

# --- 7. Icônes : Nerd Font par défaut, repli « basic », désactivables --------
# FR : les glyphes Nerd Font vivent dans les zones privées Unicode (PUA) ;
#      un prompt sans icône Nerd Font n'en contient donc aucun.
ps1_of() { with_prompt '_coolbash_prompt_build; printf %s "$PS1"'; }
pua_count() { LC_ALL=C.UTF-8 grep -cP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]'; }
assert_eq "mode résolu par défaut : nerd" "nerd" "$(TERM=xterm-256color with_prompt 'echo "$COOLBASH_PROMPT_ICONS"')"
assert_empty "nerd : toutes les icônes sont définies" \
  "$(with_prompt 'for k in user host branch venv time path root clock err; do [[ -n "${COOLBASH_PROMPT_SYM[$k]}" ]] || echo "$k"; done')"
assert_contains "nerd : icône utilisateur devant \\u" "$(ps1_of)" $'\uf007 \\u'
assert_contains "nerd : icône écran + deux espaces devant \\h (glyphe large)" "$(ps1_of)" $'\uf108  \\h'
assert_contains "nerd : icône horloge devant l'heure, sans crochets" "$(ps1_of)" $'\uf017 \\t'
assert_contains "sans icône : heure entre crochets" "$(COOLBASH_PROMPT_ICONS=0 ps1_of)" '[\t]'
assert_contains "nerd : icône dossier devant \\w" "$(ps1_of)" $'\uf07c \\w'
assert_contains "nerd : icône branche devant le segment git" "$(cd "${COOLBASH_TEST_ROOT}" && ps1_of)" $'\ue725 '
assert_contains "nerd : icône venv devant le nom du venv" "$(VIRTUAL_ENV=/x/.venv ps1_of)" $'\ue73c .venv'
assert_contains "nerd : icône sablier devant la durée" \
  "$(with_prompt 'COOLBASH_PROMPT_T0=$(( ${EPOCHREALTIME//[.,]/} - 2000000 )); _coolbash_prompt_build; printf %s "$PS1"')" $'\uf252 2.0'
assert_eq "COOLBASH_PROMPT_ICONS=0 : aucun glyphe zone privée" "0" "$(COOLBASH_PROMPT_ICONS=0 ps1_of | pua_count)"
assert_eq "…ni symbole ⎇" "0" "$(COOLBASH_PROMPT_ICONS=0 ps1_of | grep -c '⎇')"
assert_contains "…et pas d'espace orphelin devant \\u" "$(COOLBASH_PROMPT_ICONS=0 ps1_of)" '\[\e[1m\]\u'
assert_contains "…ni devant \\w" "$(COOLBASH_PROMPT_ICONS=0 ps1_of)" '\[\e[1;34m\]\w'
assert_eq "COOLBASH_PROMPT_ICONS=basic : ⎇ pour la branche" "⎇" "$(COOLBASH_PROMPT_ICONS=basic with_prompt 'printf %s "${COOLBASH_PROMPT_SYM[branch]}"')"
assert_eq "basic : aucun glyphe zone privée" "0" "$(cd "${COOLBASH_TEST_ROOT}" && COOLBASH_PROMPT_ICONS=basic ps1_of | pua_count)"
assert_eq "TERM=linux (console) : icônes désactivées" "0" "$(TERM=linux with_prompt 'echo "$COOLBASH_PROMPT_ICONS"')"
assert_eq "…sauf réglage explicite" "nerd" "$(TERM=linux COOLBASH_PROMPT_ICONS=nerd with_prompt 'echo "$COOLBASH_PROMPT_ICONS"')"
assert_eq "valeur inconnue : repli sur basic" "basic" "$(COOLBASH_PROMPT_ICONS=foo with_prompt 'echo "$COOLBASH_PROMPT_ICONS"')"

t_done
