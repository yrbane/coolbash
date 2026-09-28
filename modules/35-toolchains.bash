# shellcheck shell=bash
#  ███████   █████    █████   ██       ███████
#     █     ██   ██  ██   ██  ██       ██
#     █     ██   ██  ██   ██  ██       ███████
#     █     ██   ██  ██   ██  ██            ██
#     █      █████    █████   ███████  ███████   MODULE: TOOLCHAINS (SDK)
# ─────────────────────────────────────────────────────────────────────────────
# FR: Chaînes d'outils installées dans le HOME, à leur emplacement standard :
#     cargo, pnpm, Android SDK, foundry, nvm. Chaque entrée n'est ajoutée que
#     si le dossier existe, sans doublon (path_prepend / path_append), et
#     AUCUN processus n'est lancé : ce bloc remplace les lignes que chaque
#     installeur ajoute au ~/.bashrc.
#     Un SDK rangé ailleurs (ex. ~/Dev/flutter) va dans 90-local-overrides.
#     Réglage : COOLBASH_NVM_LAZY=0 pour charger nvm.sh au démarrage.

_coolbash_safe && return 0

[[ -d "$HOME/.cargo/bin" ]] && path_prepend "$HOME/.cargo/bin"

if [[ -d "${PNPM_HOME:-$HOME/.local/share/pnpm}" ]]; then
  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  path_prepend "$PNPM_HOME"
fi

# FR: ~/Android/Sdk est l'emplacement par défaut d'Android Studio.
if [[ -d "${ANDROID_HOME:-$HOME/Android/Sdk}" ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
  [[ -d "$ANDROID_HOME/platform-tools" ]] && path_append "$ANDROID_HOME/platform-tools"
  [[ -d "$ANDROID_HOME/emulator" ]] && path_append "$ANDROID_HOME/emulator"
fi

[[ -d "$HOME/.foundry/bin" ]] && path_append "$HOME/.foundry/bin"

# --- nvm : paresseux ---------------------------------------------------------
# FR: sourcer nvm.sh coûte plusieurs centaines de ms à CHAQUE shell. À la
#     place : le node par défaut est mis dans le PATH en lisant
#     ~/.nvm/alias/default (node, npm, npx et les binaires globaux marchent
#     tout de suite, y compris pour le prompt et les scripts), et la fonction
#     `nvm` ne charge le vrai nvm.sh qu'à son premier appel.
#     Alias exact (24.14.0), partiel (24) ou symbolique (lts/*, node) : dans
#     ce dernier cas on prend la version installée la plus récente.
_coolbash_nvm_default_bin() {
  local alias="" dir best=""
  read -r alias 2>/dev/null <"$NVM_DIR/alias/default"
  alias="${alias#v}"
  if [[ "$alias" =~ ^[0-9][0-9.]*$ ]]; then
    for dir in "$NVM_DIR/versions/node/v${alias}" "$NVM_DIR/versions/node/v${alias}".*; do
      [[ -d "$dir/bin" ]] && best="$dir"
    done
  fi
  if [[ -z "$best" ]]; then
    # FR: le glob trie en ordre lexical (v9 > v24) — on compare les majeures.
    local major top=-1
    for dir in "$NVM_DIR"/versions/node/v*; do
      [[ -d "$dir/bin" ]] || continue
      major="${dir##*/v}"
      major="${major%%.*}"
      if [[ "$major" =~ ^[0-9]+$ ]] && ((major >= top)); then
        top="$major"
        best="$dir"
      fi
    done
  fi
  [[ -n "$best" ]] && path_prepend "$best/bin"
}

if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ "${COOLBASH_NVM_LAZY:-1}" == 0 ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  else
    _coolbash_nvm_default_bin
    # FR : un alias homonyme serait développé à la lecture de « nvm() { ».
    unalias nvm 2>/dev/null
    nvm() {
      unset -f nvm
      # shellcheck disable=SC1091
      . "$NVM_DIR/nvm.sh"
      # shellcheck disable=SC1091
      [[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
      nvm "$@"
    }
  fi
fi
unset -f _coolbash_nvm_default_bin
true
