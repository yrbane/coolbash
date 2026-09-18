#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : cli/coolbash-font — détection et installation d'une Nerd Font, appel
#         depuis `make install` (jamais bloquant), diagnostic dans `doctor`.
#         Zéro réseau : archive locale (file://) et faux fc-list dans le PATH.
# =============================================================================
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FONT="${COOLBASH_TEST_ROOT}/cli/coolbash-font"
home="${COOLBASH_TEST_TMP}/home"; bin="${COOLBASH_TEST_TMP}/bin"
mkdir -p "${home}" "${bin}" "${COOLBASH_TEST_TMP}/src"

# FR : faux fc-list — ne « voit » que les .ttf du HOME jetable.
cat > "${bin}/fc-list" <<'EOF'
#!/bin/sh
find "${HOME}/.local/share/fonts" -name '*.ttf' 2>/dev/null | sed 's/$/: Fake Nerd Font/'
EOF
printf '#!/bin/sh\nexit 0\n' > "${bin}/fc-cache"
chmod +x "${bin}/fc-list" "${bin}/fc-cache"

: > "${COOLBASH_TEST_TMP}/src/FakeNerdFont-Regular.ttf"
: > "${COOLBASH_TEST_TMP}/src/FakeNerdFontMono-Thin.ttf"
tar -cJf "${COOLBASH_TEST_TMP}/font.tar.xz" -C "${COOLBASH_TEST_TMP}/src" FakeNerdFont-Regular.ttf FakeNerdFontMono-Thin.ttf
url="file://${COOLBASH_TEST_TMP}/font.tar.xz"

font() { env -u SSH_CONNECTION -u SSH_TTY -u SSH_CLIENT HOME="${home}" XDG_DATA_HOME='' PATH="${bin}:${PATH}" COOLBASH_FONT="${COOLBASH_FONT_TEST:-1}" COOLBASH_FONT_URL="${COOLBASH_FONT_URL_TEST:-${url}}" bash "${FONT}" "$@" 2>&1; }

# --- statut ------------------------------------------------------------------
font status >/dev/null; assert_eq "status : 1 quand aucune Nerd Font n'est installée" "1" "$?"
HOME="${home}" PATH="/nonexistent" /bin/bash "${FONT}" status >/dev/null 2>&1
assert_eq "status : 2 quand fc-list est absent (indéterminé)" "2" "$?"

# --- installation ------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  t_skip "installation depuis une archive locale (curl absent)"
else
  out="$(COOLBASH_FONT_TEST=0 font install)"; rc=$?
  assert_eq "COOLBASH_FONT=0 : rien n'est installé, code 0" "0" "${rc}"
  assert_no_path "…et aucun dossier de police créé" "${home}/.local/share/fonts/coolbash-nerd"

  out="$(font install)"; rc=$?
  assert_eq "install réussit" "0" "${rc}"
  assert_file "la police est extraite dans ~/.local/share/fonts/coolbash-nerd" "${home}/.local/share/fonts/coolbash-nerd/FakeNerdFont-Regular.ttf"
  assert_no_path "seuls les quatre styles utiles sont gardés (pas les 96 variantes)" "${home}/.local/share/fonts/coolbash-nerd/FakeNerdFontMono-Thin.ttf"
  assert_contains "le message dit de choisir la police dans le terminal" "${out}" "terminal"
  font status >/dev/null; assert_eq "status : 0 après installation" "0" "$?"
  assert_contains "seconde installation : déjà présente, rien à faire" "$(font install)" "déjà"

  rm -rf "${home}/.local"
  out="$(COOLBASH_FONT_URL_TEST="file://${COOLBASH_TEST_TMP}/absent.tar.xz" font install)"; rc=$?
  assert_eq "téléchargement impossible : code 1" "1" "${rc}"
  assert_contains "…avec le repli conseillé" "${out}" "COOLBASH_PROMPT_ICONS=basic"
  assert_no_path "…et pas de dossier à moitié rempli" "${home}/.local/share/fonts/coolbash-nerd"
fi

# --- make install : appelle l'installateur, n'échoue jamais à cause de lui ---
CLONE="${COOLBASH_TEST_TMP}/clone"; make_fake_clone "${CLONE}"
mk() { env -u SSH_CONNECTION -u SSH_TTY -u SSH_CLIENT HOME="${home}" PATH="${bin}:${PATH}" make -s -C "${CLONE}" install PREFIX="${home}/.coolbash" BASHRC="${home}/.bashrc" "$@"; }
assert_success "make install réussit même si la police est introuvable" mk COOLBASH_FONT=1 COOLBASH_FONT_URL="file://${COOLBASH_TEST_TMP}/absent.tar.xz"
assert_file "coolbash-font est installé à côté de la CLI" "${home}/.coolbash/cli/coolbash-font"
if command -v curl >/dev/null 2>&1; then
  assert_success "make install installe la police" mk COOLBASH_FONT=1 COOLBASH_FONT_URL="${url}"
  assert_file "…au bon endroit" "${home}/.local/share/fonts/coolbash-nerd/FakeNerdFont-Regular.ttf"
fi

# --- doctor ------------------------------------------------------------------
doctor() { env -u SSH_CONNECTION -u SSH_TTY -u SSH_CLIENT "$@" HOME="${home}" PATH="${bin}:${PATH}" COOLBASH_PREFIX="${home}/.coolbash" bash "${home}/.coolbash/cli/coolbash" doctor 2>&1; }
command -v curl >/dev/null 2>&1 && assert_contains "doctor : police présente" "$(doctor)" "Nerd Font installée"
rm -rf "${home}/.local"
doc="$(doctor)"; rc=$?
assert_contains "doctor : police absente signalée" "${doc}" "Nerd Font absente"
assert_contains "…avec la commande qui répare" "${doc}" "coolbash font"
assert_contains "…et le repli sans police" "${doc}" "COOLBASH_PROMPT_ICONS=basic"
assert_eq "…sans faire échouer doctor (optionnel)" "0" "${rc}"
assert_contains "doctor en SSH : la police se règle côté client" "$(doctor SSH_CONNECTION='1 2 3 4')" "machine qui affiche"

# --- CLI ---------------------------------------------------------------------
assert_contains "coolbash help mentionne la commande font" "$(bash "${COOLBASH_TEST_ROOT}/cli/coolbash" help)" "font"

# --- état de la police mémorisé pour le prompt, police retirée à l'uninstall --
if command -v curl >/dev/null 2>&1; then
  mk COOLBASH_FONT=0 >/dev/null 2>&1
  assert_eq "make install note l'absence de police dans .nerdfont (même avec COOLBASH_FONT=0)" "1" "$(cat "${home}/.coolbash/.nerdfont")"
  mk COOLBASH_FONT=1 COOLBASH_FONT_URL="${url}" >/dev/null 2>&1
  assert_eq "…puis sa présence après installation" "0" "$(cat "${home}/.coolbash/.nerdfont")"
  assert_file "police en place avant uninstall" "${home}/.local/share/fonts/coolbash-nerd/FakeNerdFont-Regular.ttf"
  out="$(env HOME="${home}" PATH="${bin}:${PATH}" make -s -C "${CLONE}" uninstall PREFIX="${home}/.coolbash" BASHRC="${home}/.bashrc" 2>&1)"
  assert_no_path "make uninstall retire la police installée par CoolBash" "${home}/.local/share/fonts/coolbash-nerd"
  assert_contains "…et le dit" "${out}" "olice"
fi

t_done
