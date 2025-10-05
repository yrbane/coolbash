#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/yourusername/coolbash.git"
INSTALL_DIR="${HOME}/.coolbash"

echo "[CoolBash] Installing from ${REPO_URL} ..."
if command -v git >/dev/null 2>&1; then
  git clone --depth=1 "${REPO_URL}" "${INSTALL_DIR}"
else
  echo "[CoolBash] Git not found, downloading ZIP..."
  curl -L "${REPO_URL}/archive/refs/heads/main.zip" -o /tmp/coolbash.zip
  unzip /tmp/coolbash.zip -d "${HOME}/"
  mv "${HOME}/coolbash-main" "${INSTALL_DIR}"
fi

"${INSTALL_DIR}/cli/coolbash" install
echo "[CoolBash] ✅ Done. Reload your shell or run: source ~/.bashrc"
