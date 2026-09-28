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

# --- 10-history : synchro enregistrée ET fonctionnelle (bug : jamais branchée) --
assert_contains "_coolbash_history_sync est dans PROMPT_COMMAND" \
  "$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; echo "${PROMPT_COMMAND[*]}"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/10-history.bash")" \
  "_coolbash_history_sync"
hist="${COOLBASH_TEST_TMP}/hist"
seen="$(printf 'source "%s"; source "%s"\necho coolbash-marker\ncat "$HISTFILE"\n' "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/10-history.bash" \
        | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" HISTFILE="${hist}" bash --norc --noprofile -i 2>/dev/null | grep -c "echo coolbash-marker")"
assert_eq "une commande est écrite dans HISTFILE dès le prompt suivant" "1" "${seen}"

# --- 60-completion : chargement différé au premier Tab (bug : jamais appelé) --
lazy="$(MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c '
  source "$1"; source "$2"
  complete -p -D 2>/dev/null | grep -q _coolbash_completion_lazy || { echo "pas de chargeur -D"; exit 0; }
  _coolbash_completion_lazy; rc=$?
  echo "rc=$rc"
  complete -p -D 2>/dev/null | grep -q _coolbash_completion_lazy && echo "chargeur encore en place"
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    declare -F _init_completion >/dev/null || declare -F _comp_initialize >/dev/null || echo "bash-completion non chargé"
  fi
' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/60-completion.bash" 2>&1)"
assert_eq "le chargeur différé charge puis se retire (retour 124 = réessayer la completion)" "rc=124" "${lazy}"

# --- 0.8.1 : correctifs des modules -----------------------------------------
# shellcheck disable=SC2016
mod() { COOLBASH_T_ROOT="${COOLBASH_TEST_ROOT}" MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; m="$2"; shift 2; source "$m"; eval "$*"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/$1" "${@:2}" 2>&1; }

# FR : `alias please='sudo !!'` ne marchait pas — pas d'expansion d'historique dans un alias.
assert_eq "please est une fonction, plus un alias" "function" "$(mod 30-aliases.bash 'type -t please')"
fakebin="${COOLBASH_TEST_TMP}/fakebin"; mkdir -p "${fakebin}"
printf '#!/bin/sh\necho "SUDO:$*"\n' > "${fakebin}/sudo"; chmod +x "${fakebin}/sudo"
got="$(printf 'source "%s"; source "%s"\necho bonjour le monde\nplease\n' "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/30-aliases.bash" \
      | MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" PATH="${fakebin}:${PATH}" bash --norc --noprofile -i 2>/dev/null | grep '^SUDO:')"
assert_contains "please relance la dernière commande avec sudo" "${got}" "echo bonjour le monde"

# FR : vu en 0.9.3 — `source ~/.bashrc` dans un shell où `please` est encore l'alias d'une
#      ancienne version : l'alias est développé à la lecture de `please() {` → erreur de syntaxe.
out="$(mod 00-core.bash 'shopt -s expand_aliases; alias please="sudo !!"; alias mkcd="echo x"; alias up="echo y"
  for m in "$COOLBASH_T_ROOT"/modules/*.bash; do source "$m" || echo "échec: $m"; done; type -t please mkcd up' 2>&1)"
assert_eq "recharger par-dessus d'anciens alias homonymes : aucune erreur, fonctions en place" "function function function" "$(printf '%s' "${out}" | tr '\n' ' ')"

# FR : le chemin des gems Ruby était figé (3.4.0) et ajouté même absent.
assert_eq "PATH : aucun dossier de gems inexistant" "0" "$(PATH=/usr/bin:/bin mod 20-path-and-colors.bash 'echo "$PATH"' | tr ':' '\n' | grep -c 'gem/ruby')"
mkdir -p "${COOLBASH_TEST_TMP}/.local/share/gem/ruby/9.9.0/bin"
assert_contains "PATH : dossier de gems détecté quelle que soit la version" "$(mod 20-path-and-colors.bash 'echo "$PATH"')" "gem/ruby/9.9.0/bin"

# FR : un module de shell ne modifie pas ~/.gitconfig.
assert_eq "31-git n'écrit plus dans la config git globale" "0" "$(grep -cE '^[^#]*git config --global [a-z.]+ [^>-]' "${COOLBASH_TEST_ROOT}/modules/31-git.bash")"
mod 31-git.bash true >/dev/null
assert_no_path "…aucun ~/.gitconfig créé au chargement" "${COOLBASH_TEST_TMP}/.gitconfig"

# FR : neofetch calculait tout (GPU, thème, police…) pour 6 lignes : jusqu'à 2,7 s.
#      Les infos système sont lues dans /proc, /sys et /etc/os-release : zéro processus.
sysinfo="$(mod 70-motd.bash 'PATH=/nonexistent; _coolbash_motd_sysinfo')"
assert_contains "MOTD : titre user@host sans aucun processus" "${sysinfo}" "${USER:-$(id -un)}@${HOSTNAME}"
assert_contains "MOTD : ligne OS depuis /etc/os-release" "${sysinfo}" "OS: $(. /etc/os-release; echo "$PRETTY_NAME")"
assert_contains "MOTD : noyau depuis /proc" "${sysinfo}" "Kernel: $(uname -r)"
assert_eq "MOTD : uptime formaté (days/hours/mins)" "1" "$(printf '%s\n' "${sysinfo}" | grep -cE '^Uptime: ([0-9]+ days?, )?([0-9]+ hours?, )?[0-9]+ mins?$')"
assert_contains "MOTD : la date du jour, par le printf intégré à bash" "${sysinfo}" "Date: $(date +%Y-%m-%d)"
assert_not_contains "MOTD : sans df, pas de ligne disque (et pas d'erreur)" "${sysinfo}" "Disk"
sysinfo_df="$(mod 70-motd.bash '_coolbash_motd_sysinfo')"
assert_eq "MOTD : espace disque de / (df -h), utilisé / taille (pourcentage)" "1" "$(printf '%s\n' "${sysinfo_df}" | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^Disk \(/\): [0-9.,]+[KMGTP]? used of [0-9.,]+[KMGTP]? \([0-9]+%\)')"
assert_eq "MOTD : le module ne lance ni neofetch ni fastfetch" "0" "$(grep -cE '^[^#]*(neofetch|fastfetch)' "${COOLBASH_TEST_ROOT}/modules/70-motd.bash")"
assert_eq "MOTD : cowsay reçoit -e @@ -T U (Neo-cowsay perd la langue avec -p)" "0" "$(grep -cE '^[^#]*cowsay[^|]* -p' "${COOLBASH_TEST_ROOT}/modules/70-motd.bash")"
# FR : lignes d'état du MOTD — sans processus (/proc, /sys) ou un seul appel bon marché,
#      et une ligne n'apparaît que si elle a quelque chose à dire. COOLBASH_MOTD_HIDE les coupe.
strip_colors() { sed 's/\x1b\[[0-9;]*m//g'; }
pure="$(mod 70-motd.bash 'PATH=/nonexistent; _coolbash_motd_sysinfo' | strip_colors)"
assert_eq "MOTD : mémoire depuis /proc/meminfo, utilisée / totale (pourcentage)" "1" "$(printf '%s\n' "${pure}" | grep -cE '^Mem: [0-9]+\.[0-9][KMGT] used of [0-9]+\.[0-9][KMGT] \([0-9]+%\)$')"
assert_eq "MOTD : charge depuis /proc/loadavg avec le nombre de cœurs" "1" "$(printf '%s\n' "${pure}" | grep -cE '^Load: [0-9]+\.[0-9]+ [0-9]+\.[0-9]+ [0-9]+\.[0-9]+ \([0-9]+ cores?\)$')"
if compgen -G '/sys/class/power_supply/BAT*/capacity' >/dev/null; then
  assert_eq "MOTD : batterie depuis /sys (cette machine en a une)" "1" "$(printf '%s\n' "${pure}" | grep -cE '^Battery: [0-9]+% \([A-Za-z ]+\)$')"
else
  assert_not_contains "MOTD : pas de batterie ici, pas de ligne" "${pure}" "Battery"
fi
hidden="$(mod 70-motd.bash 'PATH=/nonexistent COOLBASH_MOTD_HIDE="mem load date"; _coolbash_motd_sysinfo')"
assert_not_contains "COOLBASH_MOTD_HIDE=mem coupe la ligne mémoire" "${hidden}" "Mem:"
assert_not_contains "COOLBASH_MOTD_HIDE=load coupe la ligne de charge" "${hidden}" "Load:"
assert_not_contains "COOLBASH_MOTD_HIDE=date coupe la date" "${hidden}" "Date:"
assert_contains "…mais garde le reste" "${hidden}" "Kernel:"
# redémarrage requis : modules du noyau courant disparus (Arch) ou fichier drapeau (Debian)
rb="${COOLBASH_TEST_TMP}/reboot"; mkdir -p "${rb}/modules/$(uname -r)" "${rb}/modules/9.9.9-other"
assert_empty "reboot : modules du noyau courant présents, rien à dire" "$(mod 70-motd.bash "_coolbash_motd_reboot '${rb}/modules' '${rb}/absent'")"
rm -r "${rb}/modules/$(uname -r)"
assert_contains "reboot : les modules du noyau qui tourne ont disparu → Reboot required" "$(mod 70-motd.bash "_coolbash_motd_reboot '${rb}/modules' '${rb}/absent'" | strip_colors)" "Reboot required"
: > "${rb}/flag"
assert_contains "reboot : fichier /var/run/reboot-required → Reboot required" "$(mod 70-motd.bash "_coolbash_motd_reboot '${rb}/nomodules' '${rb}/flag'" | strip_colors)" "Reboot required"
assert_empty "reboot : sans dossier de modules ni drapeau (conteneur), rien" "$(mod 70-motd.bash "_coolbash_motd_reboot '${rb}/nomodules' '${rb}/absent'")"
# unités systemd en échec : un seul systemctl, affiché seulement si > 0
printf '#!/bin/bash\nprintf "nginx.service loaded failed failed Web\\ncups.service loaded failed failed Print\\n"\n' >| "${fakebin}/systemctl"; chmod +x "${fakebin}/systemctl"
assert_contains "failed : deux unités en échec, comptées et nommées" "$(mod 70-motd.bash "PATH='${fakebin}'; _coolbash_motd_failed" | strip_colors)" "Failed units: 2 (nginx.service, cups.service)"
printf '#!/bin/bash\nexit 0\n' >| "${fakebin}/systemctl"
assert_empty "failed : aucune unité en échec, pas de ligne" "$(mod 70-motd.bash "PATH='${fakebin}'; _coolbash_motd_failed")"
assert_empty "failed : sans systemctl, rien" "$(mod 70-motd.bash "PATH=/nonexistent; _coolbash_motd_failed")"
# disques : / toujours, les autres seulement à partir de 80 %, jamais tmpfs ni loop
cat >| "${fakebin}/df" <<'FAKEDF'
#!/bin/bash
# FR : PATH réduit au fakebin — seulement des builtins ici.
printf '%s\n' 'Filesystem Size Used Avail Use% Mounted on' \
  'dev 16G 0 16G 0% /dev' \
  '/dev/nvme0n1p2 535G 462G 73G 87% /' \
  '/dev/sda1 100G 95G 5G 95% /data' \
  '/dev/sdb1 2T 1T 1T 50% /mnt/photos' \
  '/dev/loop3 64M 64M 0 100% /snap/core' \
  'tmpfs 16G 1M 16G 1% /run'
FAKEDF
chmod +x "${fakebin}/df"
disks="$(mod 70-motd.bash "PATH='${fakebin}'; _coolbash_motd_disk" | strip_colors)"
assert_contains "disk : / toujours affiché" "${disks}" "Disk (/): 462G used of 535G (87%)"
assert_contains "disk : une autre partition à 95 % est affichée" "${disks}" "Disk (/data): 95G used of 100G (95%)"
assert_not_contains "disk : une partition à 50 % ne l'est pas" "${disks}" "/mnt/photos"
assert_not_contains "disk : les loop (snap) sont ignorés" "${disks}" "snap"
assert_not_contains "disk : tmpfs ignoré" "${disks}" "/run"
# note personnelle
mkdir -p "${COOLBASH_TEST_TMP}/.coolbash"
printf 'Penser au dentiste\nRenouveler le certificat\n' >| "${COOLBASH_TEST_TMP}/.coolbash/motd.txt"
noted="$(mod 70-motd.bash 'PATH=/nonexistent; _coolbash_motd_sysinfo')"
assert_contains "note : ~/.coolbash/motd.txt est affiché" "${noted}" "Penser au dentiste"
assert_contains "note : toutes les lignes" "${noted}" "Renouveler le certificat"
assert_not_contains "note : COOLBASH_MOTD_HIDE=note la coupe" "$(mod 70-motd.bash 'PATH=/nonexistent COOLBASH_MOTD_HIDE=note; _coolbash_motd_sysinfo')" "dentiste"
rm "${COOLBASH_TEST_TMP}/.coolbash/motd.txt"

# FR : citations françaises embarquées (share/fortunes/<thème>.txt), tirées en pur bash.
fort() { mod 70-motd.bash "COOLBASH_ROOT='${COOLBASH_TEST_ROOT}' PATH=/nonexistent; $1 _coolbash_fortune t && printf '%s' \"\$t\""; }
assert_eq "fortune embarquée : une citation sans aucun processus" "1" "$(fort '' | grep -c .)"
for _ in 1 2 3; do assert_contains "COOLBASH_FORTUNE=chuck ne tire que des facts Chuck Norris" "$(fort 'COOLBASH_FORTUNE=chuck')" "Chuck Norris"; done
assert_eq "un thème inconnu retombe sur tous les thèmes" "1" "$(fort 'COOLBASH_FORTUNE=inexistant' | grep -c .)"
mkdir -p "${COOLBASH_TEST_TMP}/.coolbash/fortunes"; printf 'ma citation perso\n' >| "${COOLBASH_TEST_TMP}/.coolbash/fortunes/perso.txt"
assert_eq "les fichiers de ~/.coolbash/fortunes/ sont des thèmes" "ma citation perso" "$(fort 'COOLBASH_FORTUNE=perso')"
for f in "${COOLBASH_TEST_ROOT}"/share/fortunes/*.txt; do
  n="$(grep -c . "$f")"; th="$(basename "$f" .txt)"
  if (( n >= 25 )); then t_ok "thème ${th} : ${n} citations"; else t_fail "thème ${th} : ${n} citations (minimum 25)"; fi
  assert_eq "thème ${th} : pas d'espace en fin de ligne ni de ligne vide" "0" "$(grep -cE ' $|^$' "$f")"
done
# FR : chaque thème a la même probabilité, quelle que soit sa taille (1 ligne contre 1000).
printf 'A\n' >| "${COOLBASH_TEST_TMP}/.coolbash/fortunes/petit.txt"
yes B | head -1000 >| "${COOLBASH_TEST_TMP}/.coolbash/fortunes/gros.txt"
n_petit="$(mod 70-motd.bash 'COOLBASH_ROOT=/nonexistent COOLBASH_FORTUNE="petit gros"; n=0; for _ in $(seq 400); do _coolbash_fortune t; [[ $t == A ]] && n=$((n+1)); done; echo $n')"
if (( n_petit >= 140 && n_petit <= 260 )); then t_ok "chaque thème a la même probabilité, quelle que soit sa taille (${n_petit}/400 pour le petit)"; else t_fail "tirage biaisé par la taille du thème : ${n_petit}/400 pour le petit (attendu ≈ 200)"; fi
if (( $(grep -c . "${COOLBASH_TEST_ROOT}/share/fortunes/chuck.txt") >= 5000 )); then t_ok "chuck.txt : plus de 5000 facts"; else t_fail "chuck.txt : moins de 5000 facts"; fi
assert_not_contains "doctor ne réclame plus fastfetch" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" doctor 2>&1)" "fastfetch"

assert_eq "up ne laisse pas fuiter sa variable de boucle" "" "$(cd "${COOLBASH_TEST_TMP}" && mod 40-functions.bash 'up 1; echo "${i-}"')"
assert_eq "timer mesure en millisecondes" "1" "$(mod 40-functions.bash 'timer sleep 0.2' | grep -cE '0\.2[0-9]{2}s')"
assert_contains "workon sans .venv : message clair" "$(cd "${COOLBASH_TEST_TMP}" && mod 34-python-venv.bash 'workon')" "No .venv"
mkdir -p "${COOLBASH_TEST_TMP}/proj/.venv/bin"; echo 'return 3' > "${COOLBASH_TEST_TMP}/proj/.venv/bin/activate"
assert_eq "workon : une activation en échec n'affiche pas « No .venv »" "0" "$(cd "${COOLBASH_TEST_TMP}/proj" && mod 34-python-venv.bash 'workon' | grep -c 'No .venv')"

# --- 0.9.0 : historique, fzf, pacman, extract --------------------------------
assert_contains "HISTIGNORE écarte history/fg/bg/jobs" "$(mod 10-history.bash 'echo "$HISTIGNORE"')" "history*:fg:bg:jobs"
kb="${COOLBASH_TEST_TMP}/kb.bash"; echo 'COOLBASH_TEST_KB=loaded' > "${kb}"
printf '#!/bin/sh\nexit 0\n' > "${fakebin}/fzf"; chmod +x "${fakebin}/fzf"
hist_i() { printf 'source "%s"; source "%s"\necho "kb=${COOLBASH_TEST_KB-none}"\n' "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/10-history.bash" | env "$@" MOTD_DISABLE=1 HOME="${COOLBASH_TEST_TMP}" HISTFILE="${COOLBASH_TEST_TMP}/h2" PATH="${fakebin}:${PATH}" COOLBASH_FZF_KEYBINDINGS="${kb}" bash --norc --noprofile -i 2>/dev/null | grep -o 'kb=[a-z]*' | tail -1; }
assert_eq "shell interactif + fzf : raccourcis fzf (Ctrl-R) chargés" "kb=loaded" "$(hist_i)"
assert_eq "COOLBASH_FZF=0 : pas de raccourcis fzf" "kb=none" "$(hist_i COOLBASH_FZF=0)"
assert_eq "mode safe : pas de raccourcis fzf" "kb=none" "$(hist_i COOLBASH_MODE=safe)"
assert_eq "shell non interactif : rien n'est chargé" "none" "$(PATH="${fakebin}:${PATH}" COOLBASH_FZF_KEYBINDINGS="${kb}" mod 10-history.bash 'echo "${COOLBASH_TEST_KB-none}"')"

pm="${COOLBASH_TEST_TMP}/pm"; mkdir -p "${pm}"; printf '#!/bin/sh\nexit 0\n' > "${pm}/pacman"; chmod +x "${pm}/pacman"
for t in bash env ls grep dircolors; do p="$(command -v "$t")" && ln -sf "$p" "${pm}/$t"; done
assert_contains "pacman détecté (sans apt) : mêmes alias, routés vers pacman" "$(PATH="${pm}" mod 30-aliases.bash 'alias ain; alias aug')" "pacman -S"

ex="${COOLBASH_TEST_TMP}/ex"; mkdir -p "${ex}/src"; echo salut > "${ex}/src/a.txt"
tar -czf "${ex}/pack.tar.gz" -C "${ex}/src" a.txt
(cd "${ex}" && mod 40-functions.bash 'extract -d pack.tar.gz' >/dev/null)
assert_file "extract -d : extrait dans un dossier au nom de l'archive" "${ex}/pack/a.txt"
assert_no_path "…et pas dans le dossier courant" "${ex}/a.txt"
(cd "${ex}" && mod 40-functions.bash 'extract pack.tar.gz' >/dev/null)
assert_file "extract sans -d : dossier courant, comme avant" "${ex}/a.txt"
: > "${ex}/x.rar"
out="$(cd "${ex}" && PATH="${pm}" mod 40-functions.bash 'extract x.rar; echo "rc=$?"')"
assert_contains "extract : outil manquant signalé par son nom" "${out}" "unrar"
assert_contains "…avec un code d'erreur" "${out}" "rc=3"

# --- 35-toolchains : SDK dans le PATH seulement s'ils existent, nvm paresseux --
th="${COOLBASH_TEST_TMP}/th"; mkdir -p "${th}"
tc() { MOTD_DISABLE=1 HOME="${th}" PATH=/usr/bin:/bin bash --norc --noprofile -c 'source "$1"; source "$2"; shift 2; eval "$*"' _ "${COOLBASH_TEST_ROOT}/modules/00-core.bash" "${COOLBASH_TEST_ROOT}/modules/35-toolchains.bash" "$@" 2>&1; }
assert_eq "aucun SDK installé : PATH inchangé, rien d'exporté" "/usr/bin:/bin||" "$(tc 'echo "$PATH|${PNPM_HOME-}|${ANDROID_HOME-}"')"
mkdir -p "${th}/.cargo/bin" "${th}/.local/share/pnpm" "${th}/Android/Sdk/platform-tools" "${th}/Android/Sdk/emulator" "${th}/.foundry/bin"
path="$(tc 'echo "$PATH"')"
for d in .cargo/bin .local/share/pnpm Android/Sdk/platform-tools Android/Sdk/emulator .foundry/bin; do
  assert_contains "PATH contient ${d} quand il existe" ":${path}:" ":${th}/${d}:"
done
assert_eq "PNPM_HOME et ANDROID_HOME exportés" "${th}/.local/share/pnpm ${th}/Android/Sdk" "$(tc 'bash -c "echo \$PNPM_HOME \$ANDROID_HOME"')"
assert_eq "rechargé deux fois : pas de doublon dans le PATH" "1" "$(tc 'source "'"${COOLBASH_TEST_ROOT}"'/modules/35-toolchains.bash"; echo "$PATH"' | tr ':' '\n' | grep -c '/.cargo/bin$')"

# FR : nvm.sh coûte ~700 ms par shell. On met le node par défaut dans le PATH en lisant
#      ~/.nvm/alias/default (zéro processus) et `nvm` ne se charge qu'au premier appel.
mkdir -p "${th}/.nvm/alias" "${th}/.nvm/versions/node/v20.1.0/bin" "${th}/.nvm/versions/node/v24.14.0/bin"
printf 'echo x >> "%s/nvm.loaded"\nnvm() { echo "vrai nvm: $*"; }\n' "${th}" > "${th}/.nvm/nvm.sh"
echo '24.14.0' > "${th}/.nvm/alias/default"
assert_contains "node par défaut (alias exact) dans le PATH" ":$(tc 'echo "$PATH"'):" ":${th}/.nvm/versions/node/v24.14.0/bin:"
echo '20' > "${th}/.nvm/alias/default"
assert_contains "alias partiel (20) : version installée correspondante" ":$(tc 'echo "$PATH"'):" ":${th}/.nvm/versions/node/v20.1.0/bin:"
echo 'lts/*' > "${th}/.nvm/alias/default"
assert_contains "alias non résolu (lts/*) : la plus récente installée" ":$(tc 'echo "$PATH"'):" ":${th}/.nvm/versions/node/v24.14.0/bin:"
rm -f "${th}/nvm.loaded"; tc 'true' >/dev/null
assert_no_path "nvm.sh n'est PAS chargé au démarrage" "${th}/nvm.loaded"
assert_eq "NVM_DIR exporté" "${th}/.nvm" "$(tc 'echo "$NVM_DIR"')"
assert_eq "premier appel à nvm : charge nvm.sh puis relaie les arguments" "vrai nvm: use 20" "$(tc 'nvm use 20')"
assert_eq "COOLBASH_NVM_LAZY=0 : chargement immédiat, comme avant" "1" "$(rm -f "${th}/nvm.loaded"; COOLBASH_NVM_LAZY=0 tc 'true' >/dev/null; wc -l < "${th}/nvm.loaded")"
assert_eq "mode safe : ni nvm ni SDK" "/usr/bin:/bin" "$(COOLBASH_MODE=safe tc 'echo "$PATH"')"

t_done
