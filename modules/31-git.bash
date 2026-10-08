# shellcheck shell=bash
#   █████   █████  ███████
#  ██       ██       █
#  ██ ████   █        █
#  ██   ██   █        █
#   █████   █████    █       MODULE: GIT
# ─────────────────────────────────────────────────────────────────────────────
# FR: Raccourcis Git + pager configuré une seule fois.

alias g='git'
alias ga='git add'
alias gb='git branch'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gst='git status -sb'
alias gl='git log --oneline --decorate --graph --all'
alias gcm='git commit -m'
alias gca='git commit -a -m'
alias gpf='git push --force-with-lease'
alias gpo='git push origin HEAD'
alias grhh='git reset --hard HEAD'
alias gundo='git reset --soft HEAD~1'
alias gpr='git pull --rebase --autostash'

# FR : ce module ne touche plus à ~/.gitconfig (il y écrivait core.pager à
#      chaque ouverture de shell, au prix de deux processus git). `coolbash
#      doctor` suggère la commande quand delta est là sans être configuré.

# --- 0.21.0 : gwip, gunwip, gfix, gsw, gopen, garde-fou -------------------------
# FR : un alias homonyme (ancien ~/.bash_aliases) serait développé à la lecture
#      de « nom() { » — voir 30-aliases.
unalias gwip gunwip gfix gsw gopen git 2>/dev/null

# FR : gwip — tout l'état courant dans un commit « WIP » (hooks ignorés, [skip ci]) ;
#      gunwip — le défait et rend les changements, non indexés. Refuse si le
#      dernier commit n'est pas un WIP : on ne défait jamais un vrai commit.
gwip() {
  git add -A && git commit -q --no-verify -m "WIP [skip ci]: $(printf '%(%Y-%m-%d %H:%M)T' -1)" && git log -1 --oneline
}
gunwip() {
  local subject
  subject="$(git log -1 --format=%s 2>/dev/null)"
  [[ "$subject" == WIP* ]] || {
    echo "gunwip : le dernier commit n'est pas un WIP (« ${subject:-aucun} »)" >&2
    return 1
  }
  git reset -q --soft HEAD~1 && git reset -q && git status -sb
}

# FR : gfix <commit> — commit fixup de ce qui est indexé, puis rebase autosquash
#      sans éditeur, avec autostash pour ce qui ne l'est pas.
gfix() {
  local target="${1:-}"
  [[ -n "$target" ]] || {
    echo "usage : gfix <commit>  (indexe d'abord la correction : git add …)" >&2
    return 1
  }
  git diff --cached --quiet && {
    echo "gfix : rien d'indexé — git add la correction d'abord" >&2
    return 1
  }
  # FR : un commit racine n'a pas de parent : --root.
  local base
  if git rev-parse -q --verify "${target}~1" >/dev/null 2>&1; then base="${target}~1"; else base=--root; fi
  git commit -q --no-verify --fixup "$target" \
    && GIT_SEQUENCE_EDITOR=true git rebase -q -i --autosquash --autostash "$base"
}

# FR : gsw [motif] — changer de branche. Un motif unique bascule direct (une
#      branche distante est suivie localement) ; ambigu ou vide → fzf s'il est là
#      et qu'on a un terminal, sinon la liste des candidates.
gsw() {
  local motif="${1:-}" line chosen
  local -a cands=()
  while IFS= read -r line; do
    line="${line#remotes/}"
    line="${line#origin/}"
    [[ "$line" == HEAD* || " ${cands[*]} " == *" $line "* ]] && continue
    [[ -z "$motif" || "$line" == *"$motif"* ]] && cands+=("$line")
  done < <(git branch -a --format='%(refname:short)' 2>/dev/null)
  ((${#cands[@]})) || {
    echo "gsw : aucune branche ne correspond à « $motif »" >&2
    return 1
  }
  if ((${#cands[@]} == 1)); then
    chosen="${cands[0]}"
  elif [[ -t 0 ]] && command -v fzf >/dev/null 2>&1; then
    chosen="$(printf '%s\n' "${cands[@]}" | fzf --height 40% --reverse --prompt 'branche > ' --preview 'git log --oneline -5 {}')" || return 1
  else
    echo "gsw : plusieurs branches correspondent (fzf absent) :" >&2
    printf '  %s\n' "${cands[@]}" >&2
    return 1
  fi
  [[ -n "$chosen" ]] || return 1
  git switch -q "${chosen#origin/}" 2>/dev/null || git switch -q --track "origin/${chosen#origin/}"
}

# FR : complétion de gsw : les branches locales et distantes (sans origin/) ;
#      de gfix : les 20 derniers commits (sha court, puis le sujet en aide).
_coolbash_gsw_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" line
  COMPREPLY=()
  while IFS= read -r line; do
    line="${line#remotes/}"
    line="${line#origin/}"
    [[ "$line" == HEAD* || "$line" != "$cur"* || " ${COMPREPLY[*]} " == *" $line "* ]] && continue
    COMPREPLY+=("$line")
  done < <(git branch -a --format='%(refname:short)' 2>/dev/null)
}
complete -F _coolbash_gsw_complete gsw
_coolbash_gfix_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  mapfile -t COMPREPLY < <(git log --format=%h -20 2>/dev/null | grep -- "^${cur}")
}
complete -F _coolbash_gfix_complete gfix

# FR : gopen [-p] [fichier[:ligne]] — le dépôt, ou le fichier sur la branche
#      courante, dans le navigateur (xdg-open, open) ; -p affiche l'URL.
gopen() {
  local print=0 target="" url branch path line
  [[ "${1:-}" == -p ]] && {
    print=1
    shift
  }
  target="${1:-}"
  url="$(git remote get-url origin 2>/dev/null)" || {
    echo "gopen : pas de remote origin" >&2
    return 1
  }
  # FR : git@hôte:user/repo(.git) → https://hôte/user/repo ; ssh://git@hôte/… aussi.
  url="${url%.git}"
  url="${url#ssh://}"
  url="${url#git@}"
  url="${url#https://}"
  url="${url#http://}"
  url="${url/://}"
  url="https://${url}"
  if [[ -n "$target" ]]; then
    branch="$(git branch --show-current 2>/dev/null)"
    path="${target%%:*}"
    line=""
    [[ "$target" == *:* ]] && line="#L${target##*:}"
    path="$(git ls-files --full-name -- "$path" 2>/dev/null | head -1)"
    [[ -n "$path" ]] || {
      echo "gopen : ${target%%:*} n'est pas suivi par git" >&2
      return 1
    }
    url="${url}/blob/${branch:-main}/${path}${line}"
  fi
  if ((print)); then
    printf '%s\n' "$url"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" 2>/dev/null
    printf '%s\n' "$url"
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  else
    printf '%s\n' "$url"
  fi
}

# FR : garde-fou — `git push --force` (ou -f) sur main/master demande confirmation ;
#      --force-with-lease reste libre, les autres branches aussi. Sans terminal,
#      refus. COOLBASH_GIT_GUARD=0 désactive. Tout le reste passe tel quel.
git() {
  if [[ "${COOLBASH_GIT_GUARD:-1}" != 0 && " $* " == *" push "* && (" $* " == *" --force "* || " $* " == *" -f "*) ]]; then
    local branch reply
    branch="$(command git branch --show-current 2>/dev/null)"
    if [[ "$branch" == main || "$branch" == master ]]; then
      printf '\e[31m⚠ git push --force sur %s\e[0m — confirmer ? [o/N] ' "$branch" >&2
      read -r reply
      [[ "$reply" =~ ^[oOyY]$ ]] || {
        echo "git : push --force annulé (préfère --force-with-lease, alias gpf)" >&2
        return 1
      }
    fi
  fi
  command git "$@"
}
