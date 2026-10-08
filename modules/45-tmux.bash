# shellcheck shell=bash
#  ████████ ███    ███ ██    ██ ██   ██
#     ██    ████  ████ ██    ██  ██ ██
#     ██    ██ ████ ██ ██    ██   ███
#     ██    ██  ██  ██ ██    ██  ██ ██
#     ██    ██      ██  ██████  ██   ██   MODULE: TMUX
# ─────────────────────────────────────────────────────────────────────────────
# FR: En SSH, attacher la session tmux (ou la créer) dès la connexion — une
#     coupure réseau ne perd plus un travail en cours ; on se reconnecte, on
#     retrouve tout. Opt-in : COOLBASH_TMUX_SSH=1 (coolbash setup). Seulement
#     avec un terminal (pas scp, pas rsync, pas une commande ssh distante), hors
#     tmux et screen, si tmux est installé. `exec` : détacher (Ctrl-b d) ferme
#     la connexion proprement. COOLBASH_TMUX_SESSION nomme la session (main).

_coolbash_safe && return 0

if [[ "${COOLBASH_TMUX_SSH:-0}" == 1 && $- == *i* && -t 0 && -t 1 ]] \
  && [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" && -z "${TMUX:-}" && "${TERM:-}" != @(screen*|tmux*|dumb|linux) ]] \
  && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s "${COOLBASH_TMUX_SESSION:-main}"
fi
true
