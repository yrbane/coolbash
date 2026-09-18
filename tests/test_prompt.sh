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
with_prompt() { HOME="${COOLBASH_TEST_TMP}" COLORTERM='' bash --norc --noprofile -c 'source "$1"; source "$2"; shift 2; eval "$*"' _ "${CORE}" "${PROMPT}" "$@" 2>&1; }

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
assert_eq "code 130 : nom du signal (INT)" "✖ INT" "$(COOLBASH_PROMPT_ICONS=0 with_prompt '_coolbash_prompt_status 130')"
assert_eq "code 137 : KILL" "✖ KILL" "$(COOLBASH_PROMPT_ICONS=0 with_prompt '_coolbash_prompt_status 137')"
assert_eq "code 143 : TERM" "✖ TERM" "$(COOLBASH_PROMPT_ICONS=0 with_prompt '_coolbash_prompt_status 143')"
assert_eq "code 200 : signal inconnu, nombre conservé" "✖ 200" "$(COOLBASH_PROMPT_ICONS=0 with_prompt '_coolbash_prompt_status 200')"
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
echo c > "${repo}/c"; git -C "${repo}" stash push -q -u
assert_eq "stash : ≡1 (via --show-stash, toujours un seul appel)" "main↑1≡1" "$(git_seg "${repo}")"
git -C "${repo}" stash drop -q
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
  comm -13 "$3/pv" "$3/pv2" | grep -Ev "^(COOLBASH_|PS0$|PS1$|PROMPT_COMMAND$|PROMPT_DIRTRIM$|_$|PIPESTATUS$|BASH_REMATCH$)"
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
  "$(with_prompt 'for k in user host branch venv time path root clock err jobs ro ssh container php node; do [[ -n "${COOLBASH_PROMPT_SYM[$k]}" ]] || echo "$k"; done')"
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

# --- 8. Chemin tronqué, chevron, jobs, dossier en lecture seule --------------
assert_eq "PROMPT_DIRTRIM=3 par défaut" "3" "$(with_prompt 'echo "$PROMPT_DIRTRIM"')"
assert_eq "PROMPT_DIRTRIM déjà défini : respecté" "5" "$(PROMPT_DIRTRIM=5 with_prompt 'echo "$PROMPT_DIRTRIM"')"
assert_contains "chevron dans la couleur utilisateur après un succès" "$(with_prompt 'true; _coolbash_prompt_build; printf %s "$PS1"')" '\[\e[36m\]$'
assert_contains "chevron en rouge après un échec" "$(with_prompt 'false; _coolbash_prompt_build; printf %s "$PS1"')" '\[\e[31m\]$'
assert_contains "un job en arrière-plan : segment ⚙ 1" \
  "$(with_prompt 'sleep 3 & _coolbash_prompt_build; kill %1 2>/dev/null; printf %s "$PS1"')" $'\uf013 1'
assert_eq "aucun job : pas de segment" "0" "$(ps1_of | grep -c $'\uf013')"
ro="${COOLBASH_TEST_TMP}/ro"; mkdir -p "${ro}"; chmod 500 "${ro}"
if [[ -w "${ro}" ]]; then
  t_skip "dossier en lecture seule (root ou chmod inopérant)"
else
  assert_contains "dossier non inscriptible : cadenas devant le chemin" "$(cd "${ro}" && ps1_of)" $'\uf023 \uf07c \\w'
  assert_eq "dossier inscriptible : pas de cadenas" "0" "$(cd "${COOLBASH_TEST_TMP}" && ps1_of | grep -c $'\uf023')"
fi
chmod 700 "${ro}"

# --- 9. Hôte : SSH, conteneur, couleur par machine ---------------------------
assert_contains "en SSH : icône prise devant l'hôte" "$(SSH_CONNECTION='1 2 3 4' ps1_of)" $'\uf1e6  \\h'
assert_contains "en local : icône écran, couleur d'accent fixe" "$(ps1_of)" $'\\[\\e[35m\\] \uf108  \\h'
ssh_color() { local p; p="$(SSH_CONNECTION=x HOSTNAME="$1" ps1_of)"; [[ "$p" =~ \\e\[(3[1-6])m\\\]\ $'\uf1e6' ]] && printf %s "${BASH_REMATCH[1]}"; }
ssh_a="$(ssh_color alpha)"; ssh_b="$(ssh_color alpha)"

assert_eq "en SSH : couleur d'hôte dérivée du nom, stable" "${ssh_a}" "${ssh_b}"
assert_eq "…et parmi les 6 couleurs de base sans TrueColor" "1" "$(printf '%s\n' "${ssh_a}" | grep -cE '^3[1-6]$')"
marker="${COOLBASH_TEST_TMP}/dockerenv"; : > "${marker}"
assert_contains "conteneur détecté (marqueur) : icône cube" "$(COOLBASH_PROMPT_CONTAINER_MARKERS="${marker}" ps1_of)" $'\uf1b2  \\h'
assert_eq "sans marqueur : pas de cube" "0" "$(COOLBASH_PROMPT_CONTAINER_MARKERS="${marker}.absent" ps1_of | grep -c $'\uf1b2')"

# --- 10. Terminal : OSC 7 (dossier courant) et notification de fin ---------
mkdir -p "${COOLBASH_TEST_TMP}/a b"
osc7="$(cd "${COOLBASH_TEST_TMP}/a b" && TERM=xterm ps1_of)"
assert_contains "OSC 7 annonce le dossier courant en file://" "${osc7}" '\e]7;file://'
assert_contains "…chemin encodé (espace → %20)" "${osc7}" 'a%20b\a'
assert_eq "OSC 7 absent sur un terminal sans titre (dumb)" "0" "$(TERM=dumb ps1_of | grep -c ']7;')"
assert_eq "COOLBASH_PS1_OSC7=0 le désactive" "0" "$(TERM=xterm COOLBASH_PS1_OSC7=0 ps1_of | grep -c ']7;')"
long="$(TERM=xterm COOLBASH_PROMPT_BELL_MS=1000 with_prompt 'COOLBASH_PROMPT_T0=$(( ${EPOCHREALTIME//[.,]/} - 2000000 )); _coolbash_prompt_build; printf %s "$PS1"')"
assert_contains "commande longue : sonnerie" "${long}" '\a\]'
assert_contains "…et notification OSC 777 avec la durée" "${long}" ']777;notify;CoolBash;'
assert_eq "commande courte : ni sonnerie ni notification" "0" "$(TERM=xterm COOLBASH_PROMPT_BELL_MS=1000 ps1_of | grep -c '777;notify')"
assert_eq "COOLBASH_PROMPT_BELL_MS=0 désactive" "0" "$(TERM=xterm COOLBASH_PROMPT_BELL_MS=0 with_prompt 'COOLBASH_PROMPT_T0=$(( ${EPOCHREALTIME//[.,]/} - 2000000 )); _coolbash_prompt_build; printf %s "$PS1"' | grep -c '777;notify')"

# --- 11. Outils (php, node) : détection par fichier, version en cache -------
bin="${COOLBASH_TEST_TMP}/bin"; mkdir -p "${bin}" "${COOLBASH_TEST_TMP}/proj"
printf '#!/bin/sh\necho x >> "%s/php.calls"\nprintf 7.4\n' "${COOLBASH_TEST_TMP}" > "${bin}/php"
printf '#!/bin/sh\necho x >> "%s/node.calls"\nprintf v20.1.0\n' "${COOLBASH_TEST_TMP}" > "${bin}/node"
chmod +x "${bin}/php" "${bin}/node"
tools() { (cd "${COOLBASH_TEST_TMP}/proj" && PATH="${bin}:${PATH}" with_prompt "$@"); }
tools_seg() { tools '_coolbash_prompt_tools v; printf %s "$v"'; }
assert_eq "sans composer.json ni package.json : rien" "" "$(tools_seg)"
: > "${COOLBASH_TEST_TMP}/proj/composer.json"
assert_eq "composer.json : version php majeure.mineure" $'\ue73d 7.4' "$(tools_seg)"
: > "${COOLBASH_TEST_TMP}/proj/package.json"
assert_eq "package.json : version node sans le v" $'\ue73d 7.4  \ue718 20.1' "$(tools_seg)"
assert_eq "sans icône : nom de l'outil en préfixe" "php 7.4  node 20.1" "$(COOLBASH_PROMPT_ICONS=0 tools_seg)"
rm -f "${COOLBASH_TEST_TMP}/php.calls"
tools '_coolbash_prompt_tools v; _coolbash_prompt_tools v; _coolbash_prompt_tools v' >/dev/null
assert_eq "version mise en cache : un seul lancement de php pour trois prompts" "1" "$(wc -l < "${COOLBASH_TEST_TMP}/php.calls")"
assert_eq "COOLBASH_PROMPT_TOOLS=0 désactive" "" "$(COOLBASH_PROMPT_TOOLS=0 tools_seg)"
assert_eq "mode safe : désactivé" "" "$(COOLBASH_MODE=safe tools_seg)"
assert_eq "conda : CONDA_DEFAULT_ENV dans le segment venv" "ml" "$(CONDA_DEFAULT_ENV=ml with_prompt '_coolbash_prompt_venv')"

# --- 12. Repli automatique des icônes selon la police détectée à l'installation --
# FR : `make install` note dans <prefix>/.nerdfont le statut de la police
#      (0 présente, 1 absente, 2 indéterminé). Sans Nerd Font et hors SSH → basic.
pfx="${COOLBASH_TEST_TMP}/pfx"; mkdir -p "${pfx}"
icons() { env -u SSH_CONNECTION -u SSH_TTY -u SSH_CLIENT "$@" TERM=xterm COLORTERM='' HOME="${COOLBASH_TEST_TMP}" COOLBASH_PREFIX="${pfx}" bash --norc --noprofile -c 'source "$1"; source "$2"; echo "$COOLBASH_PROMPT_ICONS"' _ "${CORE}" "${PROMPT}" 2>&1; }
echo 1 >| "${pfx}/.nerdfont"
assert_eq "police absente, session locale : icônes basic" "basic" "$(icons)"
assert_eq "…mais un réglage explicite reste prioritaire" "nerd" "$(icons COOLBASH_PROMPT_ICONS=nerd)"
assert_eq "…et en SSH on garde nerd (la police est côté client)" "nerd" "$(icons SSH_CONNECTION=x)"
echo 0 >| "${pfx}/.nerdfont"
assert_eq "police présente : nerd" "nerd" "$(icons)"
echo 2 >| "${pfx}/.nerdfont"
assert_eq "statut indéterminé : nerd" "nerd" "$(icons)"
rm -f "${pfx}/.nerdfont"
assert_eq "pas de fichier d'état : nerd" "nerd" "$(icons)"

t_done
