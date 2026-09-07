# shellcheck shell=bash
#  ██   ██  ██████  ███████  ██   ██   █████   ██████   ██   ██
#  ███  ██  ██         █     ██   ██  ██   ██  ██   ██  ██  ██
#  ██ ██ ██  █████      █     ██ █ ██  ██   ██  ██████   █████
#  ██  ███  ██         █     ███ ███  ██   ██  ██   ██  ██  ██
#  ██   ██  ██████     █     ██   ██   █████   ██   ██  ██   ██   MODULE: NETWORK
# ─────────────────────────────────────────────────────────────────────────────

alias myip='curl -s --max-time 2 https://ifconfig.me || dig +short myip.opendns.com @resolver1.opendns.com'
alias ports='ss -tulpn'

# FR: grc (colorise) si disponible.
if command -v grc >/dev/null 2>&1; then
  alias tail='grc tail'
  alias ifconfig='grc ifconfig'
fi
