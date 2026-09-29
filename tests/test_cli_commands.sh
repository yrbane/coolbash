#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : comportement des commandes de la CLI (help, version, init, erreurs).
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLI="${COOLBASH_TEST_ROOT}/cli/coolbash"

# --- help --------------------------------------------------------------------
assert_success "coolbash help renvoie 0" bash "${CLI}" help
assert_contains "coolbash help affiche l'usage" "$(bash "${CLI}" help)" "Usage: coolbash <command>"
assert_contains "coolbash sans argument affiche l'usage" "$(bash "${CLI}")" "Usage: coolbash <command>"
assert_failure "une commande inconnue renvoie un code d'erreur" bash "${CLI}" plop
assert_contains "une commande inconnue est nommée dans l'erreur" "$(bash "${CLI}" plop 2>&1)" "Unknown command: plop"

# --- version : une seule source de vérité, cohérente avec le CHANGELOG -------
version="$(bash "${CLI}" version)"
assert_eq "coolbash version affiche un numéro SemVer" "1" "$(echo "${version}" | grep -Ec '^[0-9]+\.[0-9]+\.[0-9]+$')"
changelog_version="$(grep -Eom1 '^## [0-9]+\.[0-9]+\.[0-9]+' "${COOLBASH_TEST_ROOT}/CHANGELOG.md" | cut -d' ' -f2)"
assert_eq "la version de la CLI est celle en tête du CHANGELOG" "${changelog_version}" "${version}"

# --- init : ordre de chargement des modules ----------------------------------
mods="${COOLBASH_TEST_TMP}/modules"
mkdir -p "${mods}"
# FR : créés dans le désordre pour vérifier que c'est le nom qui fait l'ordre.
echo 'COOLBASH_TEST_ORDER+="c"' >"${mods}/90-last.bash"
echo 'COOLBASH_TEST_ORDER+="a"' >"${mods}/00-first.bash"
echo 'COOLBASH_TEST_ORDER+="b"' >"${mods}/50-middle.bash"
echo 'COOLBASH_TEST_ORDER+="X"' >"${mods}/not-a-module.txt"
order="$(COOLBASH_MODULE_DIR="${mods}" bash --norc --noprofile -c 'source "$1" init; echo "${COOLBASH_TEST_ORDER}"' _ "${CLI}")"
assert_eq "init charge les modules *.bash dans l'ordre lexical, et rien d'autre" "abc" "${order}"

# --- init : un module qui échoue n'empêche pas les suivants ------------------
mkdir -p "${mods}2"
echo 'false' >"${mods}2/10-fails.bash"
echo 'COOLBASH_TEST_OK=1' >"${mods}2/20-next.bash"
res="$(COOLBASH_MODULE_DIR="${mods}2" bash --norc --noprofile -c 'source "$1" init 2>/dev/null; echo "rc=$? ok=${COOLBASH_TEST_OK-}"' _ "${CLI}")"
assert_eq "init continue après un module en échec et renvoie 0" "rc=0 ok=1" "${res}"

# --- init : répertoire de modules absent → pas d'erreur bruyante -------------
res="$(COOLBASH_MODULE_DIR="${COOLBASH_TEST_TMP}/nope" bash --norc --noprofile -c 'source "$1" init 2>&1; echo "rc=$?"' _ "${CLI}")"
assert_eq "init sans répertoire de modules reste silencieux" "rc=0" "${res}"

# --- init : la fonction shell `coolbash` est disponible ----------------------
res="$(COOLBASH_MODULE_DIR="${mods}" bash --norc --noprofile -c 'source "$1" init; coolbash help' _ "${CLI}")"
assert_contains "après init, la fonction coolbash relaie vers la CLI" "${res}" "Usage: coolbash <command>"

# --- commandes de gestion hors d'un clone → erreur explicite -----------------
fake="${COOLBASH_TEST_TMP}/fake/cli"
mkdir -p "${fake}" && cp "${CLI}" "${fake}/coolbash"
assert_failure "coolbash update hors d'un clone git échoue" env COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" update
assert_contains "…avec un message explicite" "$(COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" update 2>&1)" "Makefile"

# --- COOLBASH_REPO permet de désigner le clone -------------------------------
clone="${COOLBASH_TEST_TMP}/clone"
make_fake_clone "${clone}"
assert_success "coolbash verify via COOLBASH_REPO délègue au clone" \
  env COOLBASH_REPO="${clone}" COOLBASH_PREFIX="${COOLBASH_TEST_TMP}/fake" bash "${fake}/coolbash" verify

# --- doctor ------------------------------------------------------------------
home="${COOLBASH_TEST_TMP}/dhome"
mkdir -p "${home}"
make_fake_clone "${home}/clone"
make -s -C "${home}/clone" install PREFIX="${home}/.coolbash" BASHRC="${home}/.bashrc" >/dev/null
doc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" doctor 2>&1)"
rc=$?
assert_eq "coolbash doctor renvoie 0 sur une installation saine" "0" "${rc}"
assert_contains "doctor vérifie la version de bash" "${doc}" "bash"
assert_contains "doctor vérifie la ligne du .bashrc" "${doc}" ".bashrc"
assert_contains "doctor compte les modules" "${doc}" "modules"
assert_contains "doctor compte les thèmes de citations" "${doc}" "citations"
assert_eq "coolbash fortune affiche une citation" "1" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune 2>&1 | grep -c .)"
fc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune chuck 2>&1)"
assert_contains "coolbash fortune <thème> respecte le thème" "${fc,,}" "chuck norris"
assert_contains "coolbash help mentionne fortune" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "fortune"
# fortune --add : ajoute à un thème personnel (perso par défaut)
fa="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add "Ma première citation" 2>&1)"
assert_file "fortune --add crée ~/.coolbash/fortunes/perso.txt" "${home}/.coolbash/fortunes/perso.txt"
assert_contains "fortune --add annonce le fichier et le nombre" "${fa}" "perso.txt"
HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add "Une deuxième" boulot >/dev/null 2>&1
assert_eq "fortune --add <texte> <thème> écrit dans le thème demandé" "Une deuxième" "$(cat "${home}/.coolbash/fortunes/boulot.txt")"
assert_eq "fortune --add sans texte → erreur, code 1" "1" "$(
  HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune --add >/dev/null 2>&1
  echo $?
)"
assert_eq "…et le thème perso est tiré par coolbash fortune perso" "Ma première citation" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" fortune perso)"
# bench : N démarrages, moyenne, et le détail par module
bn="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" bench 2 2>&1)"
assert_contains "coolbash bench annonce la moyenne" "${bn}" "moyenne"
assert_eq "coolbash bench affiche des ms" "1" "$(printf '%s\n' "${bn}" | grep -cE 'moyenne[^0-9]*[0-9]+ ms')"
assert_contains "coolbash bench détaille les modules" "${bn}" "50-prompt"
assert_contains "coolbash help mentionne bench" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "bench"
cli_home() { HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" "$@" 2>&1; }
# theme
th="$(cli_home theme)"
for t in coolbash nord dracula solarized gruvbox mono; do assert_contains "coolbash theme liste ${t}" "${th}" "${t}"; done
assert_contains "coolbash theme montre un aperçu (utilisateur seb at machine)" "${th}" "seb"
assert_eq "coolbash theme <inconnu> → erreur, code 1" "1" "$(
  cli_home theme fuchsia >/dev/null 2>&1
  echo $?
)"
tp="$(cli_home theme --preview nord)"
assert_contains "theme --preview nord : le prompt d'exemple (utilisateur)" "${tp}" "seb"
assert_contains "theme --preview nord : le prompt d'exemple (hôte)" "${tp}" "machine"
assert_contains "…dans les couleurs nord" "${tp}" $'\e[38;2;163;190;140m'
assert_eq "theme --preview : une seule ligne" "1" "$(printf '%s\n' "${tp}" | grep -c .)"
assert_eq "theme --preview --full : les deux lignes du prompt" "2" "$(cli_home theme --preview dracula --full | grep -c .)"
assert_eq "theme --preview inconnu → erreur" "1" "$(
  cli_home theme --preview fuchsia >/dev/null 2>&1
  echo $?
)"
cli_home theme nord >/dev/null
assert_eq "coolbash theme nord écrit ~/.coolbash/theme" "nord" "$(cat "${home}/.coolbash/theme")"
assert_contains "…et la liste marque le thème actuel" "$(cli_home theme)" "nord       ●"
rm -f "${home}/.coolbash/theme"
# sync : rsync et ssh factices
fbs="${COOLBASH_TEST_TMP}/fbsync"
mkdir -p "${fbs}"
printf '#!/bin/bash\necho "rsync $*"\n' >|"${fbs}/rsync"
printf '#!/bin/bash\necho "ssh $*"\n' >|"${fbs}/ssh"
chmod +x "${fbs}/rsync" "${fbs}/ssh"
printf 'note\n' >|"${home}/.coolbash/motd.txt"
mkdir -p "${home}/.coolbash/fortunes"
printf 'nord\n' >|"${home}/.coolbash/theme"
rm -f "${home}/.coolbash/config.bash" # FR : écrit par le setup --defaults de make install ; sync l'embarquerait
sy="$(PATH="${fbs}:${PATH}" cli_home sync arthur@debian)"
assert_contains "sync : rsync des fortunes, motd.txt et theme vers hôte:.coolbash/" "${sy}" "rsync -az ${home}/.coolbash/fortunes ${home}/.coolbash/motd.txt ${home}/.coolbash/theme arthur@debian:.coolbash/"
assert_not_contains "sync : pas de 90-local-overrides sans --overrides" "${sy}" "90-local-overrides"
assert_not_contains "sync : pas de coolbash update sans --update" "${sy}" "ssh"
sy="$(PATH="${fbs}:${PATH}" cli_home sync --update --overrides arthur@debian seb@nas)"
assert_contains "sync --overrides : 90-local-overrides vers modules/" "${sy}" "90-local-overrides.bash arthur@debian:.coolbash/modules/"
assert_contains "sync --update : coolbash update lancé par ssh" "${sy}" "ssh arthur@debian bash ~/.coolbash/cli/coolbash update"
assert_contains "sync : plusieurs hôtes" "${sy}" "seb@nas:.coolbash/"
assert_eq "sync sans hôte → usage, code 1" "1" "$(
  cli_home sync >/dev/null 2>&1
  echo $?
)"
rm -f "${home}/.coolbash/motd.txt" "${home}/.coolbash/theme"
# vérification de mise à jour : due / pas due, puis détection sur un dépôt local
rm -f "${home}/.coolbash/.update-check"
assert_eq "update_due : sans horodatage → due" "0" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_UPDATE_CHECK=1 bash -c 'source "$1" version >/dev/null; _coolbash_update_due; echo $?' _ "${home}/.coolbash/cli/coolbash")"
printf '%s\n' "$EPOCHSECONDS" >|"${home}/.coolbash/.update-check"
assert_eq "update_due : horodatage frais → pas due" "1" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_UPDATE_CHECK=1 bash -c 'source "$1" version >/dev/null; _coolbash_update_due; echo $?' _ "${home}/.coolbash/cli/coolbash")"
assert_eq "update_due : COOLBASH_UPDATE_CHECK=0 → jamais" "1" "$(
  rm -f "${home}/.coolbash/.update-check"
  HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_UPDATE_CHECK=0 bash -c 'source "$1" version >/dev/null; _coolbash_update_due; echo $?' _ "${home}/.coolbash/cli/coolbash"
)"
# FR : un dépôt « distant » local dont origin/main annonce 99.0.0
up="${COOLBASH_TEST_TMP}/upd"
mkdir -p "${up}"
git -C "${home}/clone" init -q 2>/dev/null
git -C "${home}/clone" add -A >/dev/null 2>&1
git -C "${home}/clone" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1
git clone -q "${home}/clone" "${up}/remote" 2>/dev/null
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="99.0.0"/' "${up}/remote/cli/coolbash"
git -C "${up}/remote" -c user.email=t@t -c user.name=t commit -qam "99.0.0" >/dev/null 2>&1
git -C "${up}/remote" branch -M main >/dev/null 2>&1
git clone -q "${up}/remote" "${up}/local" 2>/dev/null
git -C "${up}/local" checkout -q HEAD~1 2>/dev/null
git -C "${up}/local" branch -f main >/dev/null 2>&1
HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_REPO="${up}/local" bash -c 'source "$1" version >/dev/null; _coolbash_update_check' _ "${home}/.coolbash/cli/coolbash"
assert_eq "update_check : origin/main plus récent → .update-available = 99.0.0" "99.0.0" "$(cat "${home}/.coolbash/.update-available" 2>/dev/null)"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="0.0.1"/' "${up}/remote/cli/coolbash"
git -C "${up}/remote" -c user.email=t@t -c user.name=t commit -qam "0.0.1" >/dev/null 2>&1
HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_REPO="${up}/local" bash -c 'source "$1" version >/dev/null; _coolbash_update_check' _ "${home}/.coolbash/cli/coolbash"
assert_no_path "update_check : version distante plus ancienne → pas d'alerte" "${home}/.coolbash/.update-available"
# doctor : analyse du ~/.bashrc
cat >|"${home}/.bashrc" <<'BRC'
# commentaire
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
. "$HOME/.cargo/env"
alias ll='ls -la'
export PATH="/opt/bin:$PATH"
source "$HOME/.coolbash/cli/coolbash" init
BRC
doc="$(cli_home doctor)"
assert_contains "doctor : repère nvm dans le .bashrc → 35-toolchains" "${doc}" "35-toolchains le charge paresseusement"
assert_contains "doctor : repère cargo" "${doc}" "cargo : 35-toolchains"
assert_contains "doctor : repère un alias → 90-local-overrides" "${doc}" "90-local-overrides"
assert_contains "doctor : repère export PATH → path_prepend" "${doc}" "path_prepend"
assert_eq "doctor : la ligne source de CoolBash et les commentaires ne sont pas signalés (5 lignes sur 7)" "5" "$(printf '%s\n' "${doc}" | sed 's/\x1b\[[0-9;]*m//g' | grep -c '– ligne')"
assert_contains "doctor : renvoie vers coolbash tidy" "${doc}" "coolbash tidy"
# tidy : aperçu, puis --apply avec sauvegarde
cat >|"${home}/.bashrc" <<'BRC'
# mon bashrc
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
alias ll='ls -la'
export PATH="/opt/bin:$PATH"
PATH="$PATH:/opt/tail"
mafonction() { echo coucou; }
source "$HOME/.coolbash/cli/coolbash" init
BRC
ty="$(cli_home tidy)"
assert_contains "tidy : aperçu — lignes retirées (nvm)" "${ty}" "Retirées"
assert_contains "tidy : aperçu — export PATH devient path_prepend" "${ty}" 'path_prepend "/opt/bin"'
assert_contains "tidy : aperçu — PATH=\$PATH:X devient path_append" "${ty}" 'path_append "/opt/tail"'
assert_contains "tidy : aperçu — l'alias est déplacé" "${ty}" "alias ll="
assert_eq "tidy : aperçu — le fichier n'est pas touché" "8" "$(wc -l <"${home}/.bashrc")"
cli_home tidy --apply >/dev/null
assert_eq "tidy --apply : il reste le commentaire et la ligne source" "# mon bashrc
source \"\$HOME/.coolbash/cli/coolbash\" init" "$(cat "${home}/.bashrc")"
assert_eq "tidy --apply : une sauvegarde avant-coolbash" "1" "$(
  set -- "${home}"/.bashrc.avant-coolbash-*
  [[ -f "$1" ]] && echo $#
)"
ovf="${home}/.coolbash/modules/90-local-overrides.bash"
assert_contains "tidy --apply : l'alias est dans 90-local-overrides" "$(cat "${ovf}")" "alias ll='ls -la'"
assert_contains "tidy --apply : la fonction aussi" "$(cat "${ovf}")" "mafonction() { echo coucou; }"
assert_contains "tidy --apply : path_prepend à la place d'export PATH" "$(cat "${ovf}")" 'path_prepend "/opt/bin"'
assert_contains "tidy --apply : les lignes retirées sont notées en commentaire" "$(cat "${ovf}")" "# Retirées"
assert_eq "tidy --apply : nvm.sh n'est plus nulle part hors commentaire" "0" "$(grep -c '^[^#]*nvm.sh' "${home}/.bashrc" "${ovf}" | awk -F: '{s+=$2} END {print s}')"
assert_success "tidy --apply : le 90-local-overrides produit est du bash valide" bash -n "${ovf}"
assert_contains "tidy : déjà rangé → rien à faire" "$(cli_home tidy)" "rien à faire"
rm -f "${home}"/.bashrc.avant-coolbash-*
printf 'source "$HOME/.coolbash/cli/coolbash" init\n' >|"${home}/.bashrc"
assert_contains "doctor : .bashrc propre → rien à déplacer" "$(cli_home doctor)" "rien à déplacer"
# help <commande> et complétion
assert_contains "coolbash help fortune : le détail (--add)" "$(cli_home help fortune)" "--add"
assert_eq "coolbash help inconnue → erreur, code 1" "1" "$(
  cli_home help zzz >/dev/null 2>&1
  echo $?
)"
comp() { HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash --norc --noprofile -c 'source "$1" init; COMP_WORDS=("${@:2}"); COMP_CWORD=$(( $# - 2 )); _coolbash_complete; printf "%s\n" "${COMPREPLY[@]}"' _ "${home}/.coolbash/cli/coolbash" "$@" 2>/dev/null; }
assert_eq "complétion : coolbash th<Tab> → theme" "theme" "$(comp coolbash th)"
assert_eq "complétion : coolbash theme n<Tab> → nord" "nord" "$(comp coolbash theme n)"
assert_contains "complétion : coolbash fortune ch<Tab> → chuck" "$(comp coolbash fortune ch)" "chuck"
assert_eq "complétion : coolbash tidy -<Tab> → --apply" "--apply" "$(comp coolbash tidy -)"
# setup : configuration interactive → ~/.coolbash/config.bash
rm -f "${home}/.coolbash/config.bash"
su="$(cli_home setup --defaults)"
assert_contains "setup --defaults : tout par défaut, seule la version est notée" "${su}" "seule la version"
assert_eq "…config.bash ne contient que l'en-tête (avec la version)" "0" "$(grep -c '^export' "${home}/.coolbash/config.bash")"
assert_contains "…qui permet la reprise dès la prochaine fois" "$(cli_home setup --defaults)" "reprise telle quelle"
rm -f "${home}/.coolbash/config.bash"
# setup : aperçu des palettes dans la question, et « v N » pour voir une palette en entier
rm -f "${home}/.coolbash/config.bash"
sv="$(printf 'v 3\n2\n' | cli_home setup)"
assert_eq "setup : la question de la palette montre un aperçu par thème (6)" "6" "$(printf '%s\n' "${sv}" | grep -c '12:34:56.*seb.*machine.*~/Dev/coolbash')"
assert_contains "setup : « v 3 » affiche la palette 3 (dracula) en entier" "${sv}" "— dracula —"
assert_contains "…avec ses couleurs" "${sv}" $'\e[38;2;189;147;249m'
assert_contains "…puis la réponse 2 est prise : nord" "$(cat "${home}/.coolbash/config.bash")" "COOLBASH_PROMPT_THEME:-nord"
rm -f "${home}/.coolbash/config.bash"
# FR : réponses : thème 2 (nord), icônes Entrée, emoji 2 (aucun), git n, tools Entrée, cloud Entrée,
#      fish Entrée, transient Entrée, min_ms 500, bell Entrée, stamp Entrée ; MOTD o, hide « 5 9 »,
#      fortune « 1 12 », startup 2 (verbose) ; update n, puis Entrée jusqu'au bout.
su="$(printf '2\n\n2\nn\n\n\n\n\n500\n\n\n\n5 9\n1 12\n2\nn\n' | cli_home setup)"
assert_contains "setup : annonce le fichier écrit" "${su}" "config.bash"
cfg="$(cat "${home}/.coolbash/config.bash")"
assert_contains "setup : thème nord (choix 2)" "${cfg}" 'export COOLBASH_PROMPT_THEME="${COOLBASH_PROMPT_THEME:-nord}"'
assert_contains "setup : emoji aucun → variable vide" "${cfg}" 'export COOLBASH_PROMPT_EMOJI="${COOLBASH_PROMPT_EMOJI:-}"'
assert_contains "setup : git désactivé (n)" "${cfg}" 'COOLBASH_PROMPT_GIT="${COOLBASH_PROMPT_GIT:-0}"'
assert_contains "setup : durée minimale 500" "${cfg}" 'COOLBASH_PROMPT_MIN_MS:-500'
assert_contains "setup : lignes MOTD à taire (5 9 → battery note)" "${cfg}" 'COOLBASH_MOTD_HIDE:-battery note'
assert_contains "setup : thèmes de citations (1 12 → dev chuck)" "${cfg}" 'COOLBASH_FORTUNE:-dev chuck'
assert_contains "setup : temps de démarrage verbose" "${cfg}" 'COOLBASH_STARTUP_TIME:-verbose'
assert_contains "setup : vérification de mise à jour coupée" "${cfg}" 'COOLBASH_UPDATE_CHECK:-0'
assert_eq "setup : les valeurs par défaut ne sont pas écrites (icônes nerd)" "0" "$(grep -c 'COOLBASH_PROMPT_ICONS' "${home}/.coolbash/config.bash")"
assert_success "setup : config.bash est du bash valide" bash -n "${home}/.coolbash/config.bash"
assert_eq "init source config.bash avant les modules" "nord" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash --norc --noprofile -c 'source "$1" init; echo "$COOLBASH_PROMPT_THEME"' _ "${home}/.coolbash/cli/coolbash" 2>/dev/null)"
assert_eq "…mais une variable posée avant garde la priorité" "dracula" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" COOLBASH_PROMPT_THEME=dracula bash --norc --noprofile -c 'source "$1" init; echo "$COOLBASH_PROMPT_THEME"' _ "${home}/.coolbash/cli/coolbash" 2>/dev/null)"
assert_contains "coolbash config voit le réglage comme défini" "$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash --norc --noprofile -c 'source "$1" init; coolbash config' _ "${home}/.coolbash/cli/coolbash" 2>/dev/null | grep COOLBASH_PROMPT_THEME)" "défini"
su="$(printf '2\n' | cli_home setup)"
assert_contains "setup relancé (tout revoir) : les choix précédents sont proposés (← actuel)" "$(printf '%s' "${su}" | sed 's/\x1b\[[0-9;]*m//g')" "nord  ← actuel"
assert_contains "setup relancé avec Entrée partout : le fichier est conservé" "$(cat "${home}/.coolbash/config.bash")" "nord"
assert_contains "coolbash help setup" "$(cli_home help setup)" "config.bash"
rm -f "${home}/.coolbash/config.bash"
# compile : un ~/.bashrc autonome
cb="$(cli_home compile)"
assert_contains "compile : marqueur de version" "${cb}" "# COOLBASH-COMPILED $(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" version)"
assert_eq "compile : chaque module inliné dans une fonction" "$(
  set -- "${home}"/.coolbash/modules/*.bash
  echo $#
)" "$(printf '%s\n' "${cb}" | grep -c '^_coolbash_mod_')"
assert_contains "compile : la fonction coolbash et la complétion sont embarquées" "${cb}" "_coolbash_shell_function ()"
assert_contains "compile : le temps de démarrage aussi" "${cb}" "_coolbash_startup_report"
printf '%s\n' "${cb}" >|"${home}/compiled.bash"
assert_success "compile : le résultat est du bash valide" bash -n "${home}/compiled.bash"
run_compiled() {
  local code="${*: -1}"
  env "${@:1:$#-1}" MOTD_DISABLE=1 HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash --norc --noprofile -ic "source '${home}/compiled.bash'; ${code}" 2>/dev/null
}
rc_out="$(run_compiled 'COOLBASH_STARTUP_TIME=0' '_coolbash_prompt_build; echo "PS1=$PS1"; type -t mkcd j gsw todo copy coolbash | tr "\n" " "; echo; echo "compiled=$COOLBASH_COMPILED"')"
assert_eq "compilé : le prompt CoolBash se construit (user at host)" "1" "$(printf '%s\n' "${rc_out}" | tr -d '\n' | grep -c 'PS1=.* at ')"
assert_contains "compilé : toutes les fonctions des modules" "${rc_out}" "function function function function function function"
assert_contains "compilé : COOLBASH_COMPILED=1" "${rc_out}" "compiled=1"
assert_eq "compilé en mode safe : le return d'un module n'interrompt pas le fichier (prompt chargé, j absent)" "function" "$(run_compiled COOLBASH_MODE=safe COOLBASH_STARTUP_TIME=0 'type -t j _coolbash_prompt_build | tr "\n" " "' | sed 's/ *$//')"
printf 'export COOLBASH_PROMPT_THEME="${COOLBASH_PROMPT_THEME:-nord}"\n' >|"${home}/.coolbash/config.bash"
assert_contains "compile : config.bash est inliné" "$(cli_home compile)" 'COOLBASH_PROMPT_THEME:-nord'
rm -f "${home}/.coolbash/config.bash"
printf '# mon bashrc\nsource "$HOME/.coolbash/cli/coolbash" init\n' >|"${home}/.bashrc"
rm -f "${home}"/.bashrc.avant-coolbash-*
cli_home compile --write >/dev/null
assert_contains "compile --write : ~/.bashrc devient le fichier compilé" "$(head -4 "${home}/.bashrc")" "# COOLBASH-COMPILED"
assert_eq "compile --write : sauvegarde avant-coolbash créée" "1" "$(
  set -- "${home}"/.bashrc.avant-coolbash-*
  [[ -f "$1" ]] && echo $#
)"
assert_contains "doctor : reconnaît un .bashrc compilé à jour" "$(cli_home doctor)" "autonome (compilé"
assert_eq "tidy : refuse un .bashrc compilé" "1" "$(
  cli_home tidy >/dev/null 2>&1
  echo $?
)"
sed -i 's/^# COOLBASH-COMPILED .*/# COOLBASH-COMPILED 0.1.0/' "${home}/.bashrc"
assert_contains "doctor : un compilé d'une autre version demande une recompilation" "$(cli_home doctor)" "recompile"
# setup : mode compiled → compile --write ; retour au mode source → une ligne
# FR : 24 questions avant celle du mode (la 25e) — pas de configuration existante ici.
su="$({
  printf '\n%.0s' {1..24}
  printf '2\n'
} | cli_home setup)"
assert_contains "setup : mode compiled → ~/.bashrc compilé" "$(head -4 "${home}/.bashrc")" "# COOLBASH-COMPILED $(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" version)"
assert_contains "setup : COOLBASH_INSTALL_MODE=compiled dans config.bash" "$(cat "${home}/.coolbash/config.bash")" "COOLBASH_INSTALL_MODE:-compiled"
# reprise : seules les questions nouvelles — config d'une vieille version
printf '# CoolBash 0.19.0 — réglages\nexport COOLBASH_PROMPT_THEME="${COOLBASH_PROMPT_THEME:-nord}"\n' >|"${home}/.coolbash/config.bash"
su="$(printf '1\n\n\n\n\n\n\n\n\n' | cli_home setup)"
assert_contains "setup : propose de reprendre la configuration existante" "${su}" "Une configuration existe (CoolBash 0.19.0"
assert_not_contains "setup reprise : les questions déjà connues en 0.19.0 ne sont pas reposées (palette)" "${su}" "Palette du prompt"
assert_contains "setup reprise : les questions apparues depuis le sont (hooks, 0.22.0)" "${su}" "Hooks de projet"
assert_contains "setup reprise : le réglage repris est conservé" "$(cat "${home}/.coolbash/config.bash")" "COOLBASH_PROMPT_THEME:-nord"
assert_contains "setup reprise : la version du fichier est mise à jour" "$(head -1 "${home}/.coolbash/config.bash")" "# CoolBash $(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" version)"
su="$(cli_home setup --defaults)"
assert_contains "setup --defaults sur une config à jour : reprise telle quelle" "${su}" "reprise telle quelle"
assert_contains "setup : retour au mode source → une ligne source" "$(
  # FR : une configuration existe → « 2 » (tout revoir), 24 Entrée, puis « 1 » (source).
  {
    printf '2\n'
    printf '\n%.0s' {1..24}
    printf '1\n'
  } | cli_home setup 2>&1
  cat "${home}/.bashrc"
)" 'source "'"${home}"'/.coolbash/cli/coolbash" init'
rm -f "${home}/.coolbash/config.bash" "${home}"/.bashrc.compile-* "${home}"/.bashrc.avant-coolbash-*
printf 'source "$HOME/.coolbash/cli/coolbash" init\n' >|"${home}/.bashrc"
assert_contains "doctor vérifie la locale" "${doc}" "locale"
: >"${home}/.bashrc"
doc="$(HOME="${home}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" doctor 2>&1)"
rc=$?
assert_eq "doctor échoue si le .bashrc ne charge pas CoolBash" "1" "${rc}"
assert_contains "…et le dit" "${doc}" "✘"

# --- config : réglages effectifs ---------------------------------------------
cfg="$(COOLBASH_PROMPT_MIN_MS=250 bash "${COOLBASH_TEST_ROOT}/cli/coolbash" config 2>&1)"
assert_contains "config liste les réglages" "${cfg}" "COOLBASH_PROMPT_ICONS"
assert_contains "config montre une valeur définie" "${cfg}" "250"
assert_contains "config montre la valeur par défaut des autres" "${cfg}" "30000"
# shellcheck disable=SC2016
inshell="$(HOME="${COOLBASH_TEST_TMP}" MOTD_DISABLE=1 COOLBASH_MODULE_DIR="${COOLBASH_TEST_ROOT}/modules" bash --norc --noprofile -c 'source "$1" init; COOLBASH_PS0_STAMP=0; coolbash config' _ "${COOLBASH_TEST_ROOT}/cli/coolbash" 2>&1)"
assert_eq "coolbash config voit les variables non exportées du shell courant" "1" "$(printf '%s\n' "${inshell}" | grep -E 'COOLBASH_PS0_STAMP +0 ' | grep -c 'défini')"
while read -r v; do
  assert_contains "config connaît ${v} (documentée dans le README)" "${cfg}" "${v}"
done < <(grep -oE '\| `COOLBASH_[A-Z0-9_]+' "${COOLBASH_TEST_ROOT}/README.md" | grep -oE 'COOLBASH_[A-Z0-9_]+' | sort -u)
assert_contains "coolbash help mentionne config" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "config"

t_done
