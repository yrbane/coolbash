#!/usr/bin/env bash
# FR : installation en une ligne — clone le dépôt dans ~/.coolbash puis installe.
#      Relancé sur un clone existant, il le met à jour ; il ne touche jamais à
#      un ~/.coolbash qui n'est pas un clone git.
set -e

REPO_BASE_URL="${COOLBASH_REPO_URL:-https://github.com/yrbane/coolbash}"
INSTALL_DIR="${HOME}/.coolbash"

echo "[CoolBash] Installing from ${REPO_BASE_URL} ..."
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "[CoolBash] ${INSTALL_DIR} existe déjà : mise à jour du clone."
  git -C "${INSTALL_DIR}" pull --rebase
elif [[ -e "${INSTALL_DIR}" ]]; then
  echo "[CoolBash] ${INSTALL_DIR} existe et n'est pas un clone git : déplace-le, puis relance." >&2
  exit 1
elif command -v git >/dev/null 2>&1; then
  git clone --depth=1 "${REPO_BASE_URL%.git}.git" "${INSTALL_DIR}"
else
  echo "[CoolBash] Git not found, downloading ZIP..."
  curl -L "${REPO_BASE_URL}/archive/refs/heads/main.zip" -o /tmp/coolbash.zip
  unzip /tmp/coolbash.zip -d "${HOME}/"
  mv "${HOME}/coolbash-main" "${INSTALL_DIR}"
fi

"${INSTALL_DIR}/cli/coolbash" install
echo "[CoolBash] ✅ Done. Reload your shell or run: source ~/.bashrc"
