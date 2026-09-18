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
