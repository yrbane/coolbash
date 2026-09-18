#!/usr/bin/env bash
# shellcheck disable=SC2016  # FR : scripts inline en simple quotes, voulu
# =============================================================================
#  Test : cycle make install / réinstall / uninstall dans un HOME jetable.
#  FR : tout se joue sur une COPIE du dépôt (make_fake_clone) — jamais sur le
#       vrai clone, un `rm -rf` mal gardé a déjà coûté un dépôt entier.
# =============================================================================
# shellcheck disable=SC1091
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
  "$(find "${CLONE}/modules" -name '*.bash' | wc -l)" "$(find "${PREFIX}/modules" -name '*.bash' | wc -l)"
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
# shellcheck disable=SC2016  # FR : le $HOME littéral est voulu (ancienne forme)
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

# --- update : pull → tests → install, et rien n'est installé si un test échoue -
upd="${COOLBASH_TEST_TMP}/upd"; mkdir -p "${upd}"
git init -q --bare -b main "${upd}/origin.git"
make_fake_clone "${upd}/clone"
rm -f "${upd}/clone"/tests/test_*.sh
printf '#!/usr/bin/env bash\nexit 0\n' > "${upd}/clone/tests/test_ok.sh"
git -C "${upd}/clone" init -q -b main; git -C "${upd}/clone" config user.email t@t; git -C "${upd}/clone" config user.name t
git -C "${upd}/clone" add -A; git -C "${upd}/clone" commit -qm init
git -C "${upd}/clone" remote add origin "${upd}/origin.git"; git -C "${upd}/clone" push -q -u origin main
mkup() { make -s -C "${upd}/clone" update PREFIX="${upd}/.coolbash" BASHRC="${upd}/.bashrc"; }
assert_success "make update réussit quand les tests passent" mkup
assert_file "…et installe" "${upd}/.coolbash/cli/coolbash"
printf '#!/usr/bin/env bash\nexit 1\n' > "${upd}/clone/tests/test_ko.sh"
git -C "${upd}/clone" add -A; git -C "${upd}/clone" commit -qm "casse"; git -C "${upd}/clone" push -q
rm -rf "${upd}/.coolbash"
assert_failure "make update échoue si un test échoue" mkup
assert_no_path "…et n'installe rien" "${upd}/.coolbash/cli/coolbash"

# --- update annonce la version installée -------------------------------------
rm -f "${upd}/clone/tests/test_ko.sh"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.0.0"/' "${upd}/clone/cli/coolbash"
git -C "${upd}/clone" add -A; git -C "${upd}/clone" commit -qm "v1.0.0"; git -C "${upd}/clone" push -q
out="$(mkup 2>&1)"
assert_contains "première installation : version annoncée" "${out}" "1.0.0"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.1.0"/' "${upd}/clone/cli/coolbash"
git -C "${upd}/clone" add -A; git -C "${upd}/clone" commit -qm "v1.1.0"; git -C "${upd}/clone" push -q
assert_contains "update annonce l'ancienne et la nouvelle version" "$(mkup 2>&1)" "1.0.0 → 1.1.0"
assert_contains "update sans changement : déjà à jour" "$(mkup 2>&1)" "déjà à jour (1.1.0)"
printf '#!/usr/bin/env bash\nexit 1\n' > "${upd}/clone/tests/test_ko.sh"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.2.0"/' "${upd}/clone/cli/coolbash"
git -C "${upd}/clone" add -A; git -C "${upd}/clone" commit -qm "v1.2.0 cassée"; git -C "${upd}/clone" push -q
out="$(mkup 2>&1)"
assert_contains "tests en échec : message explicite, rien d'installé" "${out}" "rien n'a été installé"
assert_contains "…avec la version restée en place" "${out}" "1.1.0"

# --- install.sh : réinstallation par-dessus un clone existant ----------------
src="${COOLBASH_TEST_TMP}/src.git"; ih="${COOLBASH_TEST_TMP}/ihome"; mkdir -p "${ih}"
make_fake_clone "${COOLBASH_TEST_TMP}/srcwork"
git -C "${COOLBASH_TEST_TMP}/srcwork" init -q -b main; git -C "${COOLBASH_TEST_TMP}/srcwork" config user.email t@t; git -C "${COOLBASH_TEST_TMP}/srcwork" config user.name t
git -C "${COOLBASH_TEST_TMP}/srcwork" add -A; git -C "${COOLBASH_TEST_TMP}/srcwork" commit -qm init
git clone -q --bare "${COOLBASH_TEST_TMP}/srcwork" "${src}"
ins() { HOME="${ih}" COOLBASH_REPO_URL="${src}" bash "${COOLBASH_TEST_ROOT}/install.sh" >/dev/null 2>&1; }
assert_success "install.sh : première installation" ins
assert_file "…clone en place" "${ih}/.coolbash/cli/coolbash"
assert_success "install.sh : relancé sur un clone existant, il met à jour au lieu d'échouer" ins
mkdir -p "${COOLBASH_TEST_TMP}/ihome2/.coolbash"; : > "${COOLBASH_TEST_TMP}/ihome2/.coolbash/perso"
assert_failure "install.sh : refuse un ~/.coolbash qui n'est pas un clone git" env HOME="${COOLBASH_TEST_TMP}/ihome2" COOLBASH_REPO_URL="${src}" bash "${COOLBASH_TEST_ROOT}/install.sh"
assert_file "…sans y toucher" "${COOLBASH_TEST_TMP}/ihome2/.coolbash/perso"

t_done
