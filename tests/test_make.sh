#!/usr/bin/env bash
# =============================================================================
#  Test : cycle make install / réinstall / uninstall dans un HOME jetable.
#  FR : tout se joue sur une COPIE du dépôt (make_fake_clone) — jamais sur le
#       vrai clone, un `rm -rf` mal gardé a déjà coûté un dépôt entier.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLONE="${COOLBASH_TEST_TMP}/clone"
PREFIX="${COOLBASH_TEST_TMP}/home/.coolbash"
BASHRC="${COOLBASH_TEST_TMP}/home/.bashrc"
make_fake_clone "${CLONE}"
mkdir -p "$(dirname "${BASHRC}")"
printf '# mon bashrc\nexport FOO=1\n# coolbash rocks (commentaire à préserver)\n' > "${BASHRC}"

mk() { make -s -C "${CLONE}" "$@" PREFIX="${PREFIX}" BASHRC="${BASHRC}"; }

# --- install -----------------------------------------------------------------
assert_success "make install réussit" mk install
assert_file "la CLI est installée" "${PREFIX}/cli/coolbash"
assert_success "la CLI installée est exécutable" test -x "${PREFIX}/cli/coolbash"
assert_file "les modules sont installés" "${PREFIX}/modules/00-core.bash"
assert_eq "autant de modules installés que dans le dépôt" \
  "$(ls "${CLONE}"/modules/*.bash | wc -l)" "$(ls "${PREFIX}"/modules/*.bash | wc -l)"
assert_eq "le chemin du clone est mémorisé pour coolbash update" "${CLONE}" "$(cat "${PREFIX}/.repo")"
assert_eq "une seule ligne source ajoutée au bashrc" "1" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_contains "le contenu initial du bashrc est préservé" "$(cat "${BASHRC}")" "export FOO=1"

# --- le bashrc généré fonctionne vraiment ------------------------------------
res="$(HOME="${COOLBASH_TEST_TMP}/home" MOTD_DISABLE=1 bash --norc --noprofile -c 'source "$1"; echo "prefix=${PREFIX-} fn=$(type -t coolbash)"' _ "${BASHRC}" 2>&1)"
assert_eq "sourcer le bashrc charge CoolBash sans PREFIX ni erreur" "prefix= fn=function" "${res}"

# --- réinstall : idempotence + overrides locaux préservés -------------------
echo 'alias perso="echo perso"' > "${PREFIX}/modules/90-local-overrides.bash"
assert_success "make install une seconde fois réussit" mk install
assert_eq "toujours une seule ligne source dans le bashrc" "1" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_eq "90-local-overrides.bash n'est jamais écrasé" 'alias perso="echo perso"' "$(cat "${PREFIX}/modules/90-local-overrides.bash")"

# --- l'ancienne ligne `source $HOME/.coolbash/cli/coolbash init` est reconnue -
old_rc="${COOLBASH_TEST_TMP}/old_bashrc"
echo 'source $HOME/.coolbash/cli/coolbash init' > "${old_rc}"
assert_success "make install avec un bashrc à l'ancienne forme" make -s -C "${CLONE}" install PREFIX="${PREFIX}" BASHRC="${old_rc}"
assert_eq "…n'ajoute pas de doublon" "1" "$(grep -c 'cli/coolbash' "${old_rc}")"

# --- la CLI installée délègue au clone ---------------------------------------
assert_success "coolbash verify depuis l'installation délègue au clone" \
  env COOLBASH_PREFIX="${PREFIX}" bash "${PREFIX}/cli/coolbash" verify

# --- install avec PREFIX = racine du clone (cas install.sh) ------------------
assert_success "make install PREFIX=<clone> ne s'écrase pas lui-même" \
  make -s -C "${CLONE}" install PREFIX="${CLONE}" BASHRC="${COOLBASH_TEST_TMP}/bashrc2"
assert_no_path "…et ne laisse pas de fichier .repo dans le clone" "${CLONE}/.repo"
assert_file "…et le clone est intact" "${CLONE}/Makefile"

# --- uninstall ---------------------------------------------------------------
assert_success "make uninstall réussit" mk uninstall
assert_no_path "le répertoire d'installation est supprimé" "${PREFIX}"
assert_eq "la ligne source est retirée du bashrc" "0" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_contains "les autres lignes mentionnant coolbash sont préservées" "$(cat "${BASHRC}")" "# coolbash rocks"
assert_contains "le reste du bashrc est intact" "$(cat "${BASHRC}")" "export FOO=1"
assert_failure "make uninstall PREFIX=<clone> refuse de supprimer le dépôt" \
  make -s -C "${CLONE}" uninstall PREFIX="${CLONE}" BASHRC="${COOLBASH_TEST_TMP}/bashrc2"
assert_file "…et le clone est toujours là" "${CLONE}/Makefile"
assert_file "…avec ses modules" "${CLONE}/modules/00-core.bash"

t_done
