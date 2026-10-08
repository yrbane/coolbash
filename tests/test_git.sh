#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : module 31-git — gwip/gunwip, gfix, gsw, gopen, garde-fou du push --force.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE="${COOLBASH_TEST_ROOT}/modules/00-core.bash"
GITM="${COOLBASH_TEST_ROOT}/modules/31-git.bash"
export MOTD_DISABLE=1

# FR : exécute du bash dans le dépôt jetable, après 00-core puis 31-git.
ing() { (cd "${repo}" && HOME="${COOLBASH_TEST_TMP}" bash --norc --noprofile -c 'source "$1"; source "$2"; shift 2; eval "$*"' _ "${CORE}" "${GITM}" "$@" 2>&1); }

repo="${COOLBASH_TEST_TMP}/grepo"
bare="${COOLBASH_TEST_TMP}/gbare.git"
git init -q --bare -b main "${bare}"
git clone -q "${bare}" "${repo}" 2>/dev/null
git -C "${repo}" config user.email t@t
git -C "${repo}" config user.name t
git -C "${repo}" checkout -q -b main 2>/dev/null
printf 'a\n' >"${repo}/a"
git -C "${repo}" add a && git -C "${repo}" commit -qm "a"
printf 'b\n' >"${repo}/b"
git -C "${repo}" add b && git -C "${repo}" commit -qm "b"
git -C "${repo}" push -q -u origin main 2>/dev/null
git -C "${repo}" remote set-url origin "git@github.com:yrbane/coolbash.git"

# --- gwip / gunwip ------------------------------------------------------------
printf 'a2\n' >"${repo}/a"
printf 'nouveau\n' >"${repo}/c"
assert_contains "gwip : commit WIP de tout l'état courant" "$(ing 'gwip; git log -1 --format=%s')" "WIP"
assert_eq "gwip : l'arbre est propre après" "" "$(git -C "${repo}" status --porcelain)"
assert_eq "gwip : le fichier nouveau est inclus" "1" "$(git -C "${repo}" show --stat HEAD | grep -c ' c ')"
assert_eq "gunwip : le commit WIP est défait, les changements reviennent (non indexés)" " M a
?? c" "$(ing 'gunwip >/dev/null; git status --porcelain')"
assert_eq "gunwip : refuse si le dernier commit n'est pas un WIP" "1" "$(ing 'gunwip >/dev/null 2>&1; echo $?')"
git -C "${repo}" checkout -q -- a
rm -f "${repo}/c"

# --- gfix -----------------------------------------------------------------------
sha_a="$(git -C "${repo}" log --format=%H --grep='^a$')"
printf 'a corrigé\n' >"${repo}/a"
git -C "${repo}" add a
assert_eq "gfix <sha> : fixup + autosquash, toujours deux commits" "2" "$(ing "gfix ${sha_a} >/dev/null 2>&1; git log --oneline | wc -l")"
assert_eq "gfix : la correction est dans le commit visé" "a corrigé" "$(git -C "${repo}" show "$(git -C "${repo}" log --format=%H --grep='^a$'):a")"
assert_eq "gfix : aucun commit fixup! restant" "0" "$(git -C "${repo}" log --format=%s | grep -c fixup)"
assert_eq "gfix sans argument → usage, code 1" "1" "$(ing 'gfix >/dev/null 2>&1; echo $?')"
assert_eq "gfix sans rien d'indexé → refuse" "1" "$(ing 'gfix HEAD >/dev/null 2>&1; echo $?')"

# --- gsw ------------------------------------------------------------------------
git -C "${repo}" branch feature/login
git -C "${repo}" branch feature/logout
assert_eq "gsw <motif> unique : bascule directement" "feature/login" "$(ing 'gsw login >/dev/null; git branch --show-current')"
assert_eq "gsw <motif> ambigu sans fzf : liste et refuse" "1" "$(ing 'gsw feature >/dev/null 2>&1; echo $?')"
assert_contains "…en nommant les candidates" "$(ing 'gsw feature 2>&1')" "feature/logout"
fb="${COOLBASH_TEST_TMP}/fbgit"
mkdir -p "${fb}"
assert_contains "gsw sans argument ni terminal : la liste de toutes les branches" "$(ing 'gsw 2>&1')" "feature/login"
git -C "${repo}" checkout -q main
assert_eq "gsw : une branche distante est suivie localement" "main" "$(ing 'gsw main >/dev/null; git branch --show-current')"

# --- gopen ----------------------------------------------------------------------
assert_eq "gopen -p : URL https du dépôt (depuis une URL ssh)" "https://github.com/yrbane/coolbash" "$(ing 'gopen -p')"
assert_eq "gopen -p fichier : blob sur la branche courante" "https://github.com/yrbane/coolbash/blob/main/a" "$(ing 'gopen -p a')"
assert_eq "gopen -p fichier:ligne : ancre #L" "https://github.com/yrbane/coolbash/blob/main/a#L12" "$(ing 'gopen -p a:12')"
git -C "${repo}" remote set-url origin "https://gitlab.com/grp/proj.git"
assert_eq "gopen -p : URL https gardée telle quelle, sans .git" "https://gitlab.com/grp/proj" "$(ing 'gopen -p')"
printf '#!/bin/bash\necho "OPEN $1"\n' >|"${fb}/xdg-open"
chmod +x "${fb}/xdg-open"
assert_contains "gopen : ouvre avec xdg-open" "$(ing "PATH=${fb}:\$PATH; gopen")" "OPEN https://gitlab.com/grp/proj"
git -C "${repo}" remote set-url origin "${bare}"

# --- garde-fou : git push --force sur main -------------------------------------------
assert_eq "git push --force sur main : refusé si on répond n" "1" "$(ing 'echo n | git push --force origin main >/dev/null 2>&1; echo $?')"
assert_contains "…avec un message explicite" "$(ing 'echo n | git push --force origin main 2>&1')" "main"
assert_eq "git push --force sur main : accepté si on répond o" "0" "$(ing 'echo o | git push --force origin main >/dev/null 2>&1; echo $?')"
assert_eq "git push --force-with-lease : jamais de question" "0" "$(ing 'git push --force-with-lease origin main </dev/null >/dev/null 2>&1; echo $?')"
git -C "${repo}" checkout -q feature/login
assert_eq "git push --force sur une autre branche : jamais de question" "0" "$(ing 'git push --force origin HEAD </dev/null >/dev/null 2>&1; echo $?')"
git -C "${repo}" checkout -q main
assert_eq "COOLBASH_GIT_GUARD=0 : pas de garde-fou" "0" "$(COOLBASH_GIT_GUARD=0 ing 'git push --force origin main </dev/null >/dev/null 2>&1; echo $?')"
assert_eq "git reste git pour tout le reste" "main" "$(ing 'git branch --show-current')"

# --- 0.31.0 : complétion de gsw (branches) et gfix (commits) -----------------------
git -C "${repo}" branch -q feature/compl 2>/dev/null
assert_contains "complétion de gsw : les branches" "$(ing 'COMP_WORDS=(gsw fe); COMP_CWORD=1; _coolbash_gsw_complete; echo "${COMPREPLY[*]}"')" "feature/compl"
assert_eq "…filtrées par le préfixe, sans HEAD ni doublon origin/" "0" "$(ing 'COMP_WORDS=(gsw fe); COMP_CWORD=1; _coolbash_gsw_complete; printf "%s\n" "${COMPREPLY[@]}"' | grep -c 'HEAD\|origin/\|^main$')"
assert_eq "complétion de gfix : des sha courts" "1" "$(ing 'COMP_WORDS=(gfix ""); COMP_CWORD=1; _coolbash_gfix_complete; printf "%s\n" "${COMPREPLY[0]}"' | grep -cE '^[0-9a-f]{7,}$')"

t_done
