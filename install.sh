#!/usr/bin/env bash
# FR : installation en une ligne — clone le dépôt dans ~/.coolbash puis installe.
set -e

REPO_BASE_URL="https://github.com/yrbane/coolbash"
INSTALL_DIR="${HOME}/.coolbash"

echo "[CoolBash] Installing from ${REPO_BASE_URL} ..."
if command -v git >/dev/null 2>&1; then
  git clone --depth=1 "${REPO_BASE_URL}.git" "${INSTALL_DIR}"
else
  echo "[CoolBash] Git not found, downloading ZIP..."
  curl -L "${REPO_BASE_URL}/archive/refs/heads/main.zip" -o /tmp/coolbash.zip
  unzip /tmp/coolbash.zip -d "${HOME}/"
  mv "${HOME}/coolbash-main" "${INSTALL_DIR}"
fi

"${INSTALL_DIR}/cli/coolbash" install
echo "[CoolBash] ✅ Done. Reload your shell or run: source ~/.bashrc"
