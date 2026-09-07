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

# FR: Pager Git configuré si non déjà défini.
if command -v git >/dev/null 2>&1; then
  if command -v delta >/dev/null 2>&1; then
    git config --global --get core.pager >/dev/null 2>&1 || git config --global core.pager delta
  elif command -v diff-so-fancy >/dev/null 2>&1; then
    git config --global --get core.pager >/dev/null 2>&1 || \
      git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
  fi
fi
