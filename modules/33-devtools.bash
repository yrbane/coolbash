# shellcheck shell=bash
#  ██████  ██████ ██   ██ ███████  █████   █████  ██      █████
#  ██   ██ ██     ██   ██    █    ██   ██ ██   ██ ██     ██
#  ██   ██ █████  ██   ██    █    ██   ██ ██   ██ ██      █████
#  ██   ██ ██     ██   ██    █    ██   ██ ██   ██ ██          ██
#  ██████  ██████  █████     █     █████   █████  ██████  █████   MODULE: DEVTOOLS
# ─────────────────────────────────────────────────────────────────────────────

# FR: yt-dlp préféré à youtube-dl si présent.
if command -v yt-dlp >/dev/null 2>&1; then
  alias youtubedl="yt-dlp -f 'bestaudio' -o '%(artist)s - %(title)s.%(ext)s'"
elif command -v youtube-dl >/dev/null 2>&1; then
  alias youtubedl="youtube-dl -f 'bestaudio' -o '%(artist)s - %(title)s.%(ext)s'"
fi

# FR: Symfony / PHP
alias s='symfony '
alias c='symfony console '
alias fix='vendor/bin/php-cs-fixer fix src/ && vendor/bin/phpstan'
