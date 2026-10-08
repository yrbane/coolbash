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
printf '# mon bashrc\nexport FOO=1\n# coolbash rocks (commentaire à préserver)\n' >"${BASHRC}"

mk() { make -s -C "${CLONE}" "$@" PREFIX="${PREFIX}" BASHRC="${BASHRC}"; }

# --- garde-fou : la suite ne touche jamais au vrai HOME ----------------------
assert_contains "HOME des tests = dossier jetable (make uninstall y supprime une police)" "${HOME}" "${COOLBASH_TEST_TMP}/"
sentinel="${HOME}/.local/share/fonts/coolbash-nerd"
mkdir -p "${sentinel}"
: >"${sentinel}/x.ttf"

# --- install -----------------------------------------------------------------
assert_success "make lint (bash -n + shellcheck + shfmt) passe sur le dépôt" make -s -C "${COOLBASH_TEST_ROOT}" lint
assert_success ".editorconfig fixe l'indentation à 2 espaces pour shfmt" grep -qx 'indent_size = 2' "${COOLBASH_TEST_ROOT}/.editorconfig"
assert_success "make install réussit" mk install
assert_eq "make install : le .bashrc non vide est sauvegardé une fois (avant-coolbash)" "1" "$(
  set -- "${HOME}"/.bashrc.avant-coolbash-*
  [[ -f "$1" ]] && echo $#
)"
assert_eq "…avec son contenu d'origine" "# mon bashrc
export FOO=1
# coolbash rocks (commentaire à préserver)" "$(
  set -- "${HOME}"/.bashrc.avant-coolbash-*
  cat "$1"
)"
assert_file "la CLI est installée" "${PREFIX}/cli/coolbash"
assert_success "la CLI installée est exécutable" test -x "${PREFIX}/cli/coolbash"
assert_file "les modules sont installés" "${PREFIX}/modules/00-core.bash"
assert_file "les citations sont installées" "${PREFIX}/share/fortunes/dev.txt"
set -- "${COOLBASH_TEST_ROOT}"/share/fortunes/*.txt
n_src=$#
set -- "${PREFIX}"/share/fortunes/*.txt
assert_eq "autant de thèmes installés que dans le dépôt" "${n_src}" "$#"
assert_eq "autant de modules installés que dans le dépôt" \
  "$(find "${CLONE}/modules" -name '*.bash' | wc -l)" "$(find "${PREFIX}/modules" -name '*.bash' | wc -l)"
assert_eq "le chemin du clone est mémorisé pour coolbash update" "${CLONE}" "$(cat "${PREFIX}/.repo")"
assert_eq "une seule ligne source ajoutée au bashrc" "1" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_contains "le contenu initial du bashrc est préservé" "$(cat "${BASHRC}")" "export FOO=1"

# --- le bashrc généré fonctionne vraiment ------------------------------------
res="$(HOME="${COOLBASH_TEST_TMP}/home" MOTD_DISABLE=1 bash --norc --noprofile -c 'source "$1"; echo "prefix=${PREFIX-} fn=$(type -t coolbash)"' _ "${BASHRC}" 2>&1)"
assert_eq "sourcer le bashrc charge CoolBash sans PREFIX ni erreur" "prefix= fn=function" "${res}"

# --- la CLI est remplacée, jamais réécrite en place --------------------------
# FR : `coolbash update` est exécuté PAR ~/.coolbash/cli/coolbash ; réécrire ce fichier
#      pendant que bash le lit donnait « erreur de syntaxe près de ;; » en fin d'update.
#      Le script ci-dessous se réinstalle lui-même en cours de route, comme update.
ino_before="$(stat -c %i "${PREFIX}/cli/coolbash")"
cat >"${COOLBASH_TEST_TMP}/selfupdate.sh" <<EOF
cp "${PREFIX}/cli/coolbash" "${COOLBASH_TEST_TMP}/cli.bak"
{ printf '# %0300d\n' 0; cat "${COOLBASH_TEST_TMP}/cli.bak"; } > "${CLONE}/cli/coolbash"
EOF
printf '\n_coolbash_selftest() { bash "%s"; make -s -C "%s" install PREFIX="%s" BASHRC="%s" >/dev/null; }\n[[ -n "${COOLBASH_SELFTEST:-}" ]] && _coolbash_selftest\n%s\n' \
  "${COOLBASH_TEST_TMP}/selfupdate.sh" "${CLONE}" "${PREFIX}" "${BASHRC}" "$(printf 'true %.0s\n' $(seq 1 40))" >>"${PREFIX}/cli/coolbash"
out="$(COOLBASH_SELFTEST=1 bash "${PREFIX}/cli/coolbash" version 2>&1 >/dev/null)"
assert_empty "une CLI qui se réinstalle pendant son exécution ne produit aucune erreur" "${out}"
assert_eq "…car le fichier installé est un nouvel inode (mv), pas une réécriture" "1" "$([[ "$(stat -c %i "${PREFIX}/cli/coolbash")" != "${ino_before}" ]] && echo 1)"
cp "${COOLBASH_TEST_ROOT}/cli/coolbash" "${CLONE}/cli/coolbash"
mk install >/dev/null

# --- réinstall : idempotence + overrides locaux préservés -------------------
echo 'alias perso="echo perso"' >"${PREFIX}/modules/90-local-overrides.bash"
assert_success "make install une seconde fois réussit" mk install
assert_eq "toujours une seule ligne source dans le bashrc" "1" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_eq "90-local-overrides.bash n'est jamais écrasé" 'alias perso="echo perso"' "$(cat "${PREFIX}/modules/90-local-overrides.bash")"

# --- l'ancienne ligne `source $HOME/.coolbash/cli/coolbash init` est reconnue -
old_rc="${COOLBASH_TEST_TMP}/old_bashrc"
# shellcheck disable=SC2016  # FR : le $HOME littéral est voulu (ancienne forme)
echo 'source $HOME/.coolbash/cli/coolbash init' >"${old_rc}"
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

# --- install en mode compiled : ~/.bashrc régénéré sans question (pas de tty) ----
printf '# CoolBash 0.26.0 — réglages\nexport COOLBASH_INSTALL_MODE="${COOLBASH_INSTALL_MODE:-compiled}"\n' >|"${PREFIX}/config.bash"
assert_success "make install avec config compiled (sans terminal) réussit" mk install
assert_contains "…et ~/.bashrc est le fichier compilé" "$(head -4 "${BASHRC}")" "# COOLBASH-COMPILED"
assert_eq "…qui se charge sans erreur" "ok" "$(MOTD_DISABLE=1 HOME="${HOME}" COOLBASH_STARTUP_TIME=0 bash --norc --noprofile -ic "source '${BASHRC}' && echo ok" 2>/dev/null | tail -1)"
printf 'source "%s/cli/coolbash" init\n' "${PREFIX}" >|"${BASHRC}"
set -- "${BASHRC}".avant-coolbash-*
printf '# mon bashrc\nexport FOO=1\n# coolbash rocks (commentaire à préserver)\n' >|"$1"
rm -f "${PREFIX}/config.bash"

# --- install depuis un terminal : setup n'interroge pas pendant les tests -----------
if command -v script >/dev/null 2>&1; then
  tty_out="$(timeout 120 script -qec "make -s -C '${CLONE}' install PREFIX='${PREFIX}' BASHRC='${BASHRC}'" /dev/null 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
  assert_not_contains "make install sous un tty : aucune question posée (COOLBASH_SETUP_DEFAULTS=1)" "${tty_out}" "Choix ["
  assert_contains "…et l'installation va au bout" "${tty_out}" "Installation complete"
else
  t_skip "make install sous un tty (script absent)"
fi

# --- uninstall ---------------------------------------------------------------
assert_success "make uninstall réussit" mk uninstall
assert_contains "uninstall : le .bashrc d'avant CoolBash est restauré" "$(cat "${BASHRC}")" "# mon bashrc"
assert_eq "uninstall : le .bashrc retiré est gardé à côté (coolbash-retire)" "1" "$(
  set -- "${HOME}"/.bashrc.coolbash-retire-*
  [[ -f "$1" ]] && echo $#
)"
assert_no_path "le répertoire d'installation est supprimé" "${PREFIX}"
assert_no_path "uninstall retire la police du HOME qu'il voit — d'où le HOME jetable" "${sentinel}"
assert_eq "la ligne source est retirée du bashrc" "0" "$(grep -c 'cli/coolbash' "${BASHRC}")"
assert_contains "les autres lignes mentionnant coolbash sont préservées" "$(cat "${BASHRC}")" "# coolbash rocks"
assert_contains "le reste du bashrc est intact" "$(cat "${BASHRC}")" "export FOO=1"
assert_failure "make uninstall PREFIX=<clone> refuse de supprimer le dépôt" \
  make -s -C "${CLONE}" uninstall PREFIX="${CLONE}" BASHRC="${COOLBASH_TEST_TMP}/bashrc2"
assert_file "…et le clone est toujours là" "${CLONE}/Makefile"
assert_file "…avec ses modules" "${CLONE}/modules/00-core.bash"

# --- update : pull → tests → install, et rien n'est installé si un test échoue -
upd="${COOLBASH_TEST_TMP}/upd"
mkdir -p "${upd}"
git init -q --bare -b main "${upd}/origin.git"
make_fake_clone "${upd}/clone"
rm -f "${upd}/clone"/tests/test_*.sh
printf '#!/usr/bin/env bash\nexit 0\n' >"${upd}/clone/tests/test_ok.sh"
git -C "${upd}/clone" init -q -b main
git -C "${upd}/clone" config user.email t@t
git -C "${upd}/clone" config user.name t
git -C "${upd}/clone" add -A
git -C "${upd}/clone" commit -qm init
git -C "${upd}/clone" remote add origin "${upd}/origin.git"
git -C "${upd}/clone" push -q -u origin main
mkup() { make -s -C "${upd}/clone" update PREFIX="${upd}/.coolbash" BASHRC="${upd}/.bashrc"; }
assert_success "make update réussit quand les tests passent" mkup
assert_file "…et installe" "${upd}/.coolbash/cli/coolbash"
printf '#!/usr/bin/env bash\nexit 1\n' >"${upd}/clone/tests/test_ko.sh"
git -C "${upd}/clone" add -A
git -C "${upd}/clone" commit -qm "casse"
git -C "${upd}/clone" push -q
rm -rf "${upd}/.coolbash"
assert_failure "make update échoue si un test échoue" mkup
assert_no_path "…et n'installe rien" "${upd}/.coolbash/cli/coolbash"

# --- update annonce la version installée -------------------------------------
rm -f "${upd}/clone/tests/test_ko.sh"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.0.0"/' "${upd}/clone/cli/coolbash"
git -C "${upd}/clone" add -A
git -C "${upd}/clone" commit -qm "v1.0.0"
git -C "${upd}/clone" push -q
out="$(mkup 2>&1)"
assert_contains "première installation : version annoncée" "${out}" "1.0.0"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.1.0"/' "${upd}/clone/cli/coolbash"
printf '# Changelog\n\n## 1.1.0 — 2026-01-01 · « Test »\n### Ajouté\n- une nouveauté de test\n\n## 1.0.0 — 2025-12-31 · « Base »\n- ancienne\n' >|"${upd}/clone/CHANGELOG.md"
git -C "${upd}/clone" add -A
git -C "${upd}/clone" commit -qm "v1.1.0"
git -C "${upd}/clone" push -q
out="$(mkup 2>&1)"
assert_contains "update annonce l'ancienne et la nouvelle version" "${out}" "1.0.0 → 1.1.0"
assert_contains "update affiche les nouveautés depuis l'ancienne version" "${out}" "Nouveautés depuis la 1.0.0"
assert_contains "…les puces de la 1.1.0" "${out}" "une nouveauté de test"
assert_eq "…pas celles de la 1.0.0" "0" "$(printf '%s\n' "${out}" | grep -c 'ancienne')"
assert_file "update copie le CHANGELOG dans le préfixe" "${upd}/.coolbash/CHANGELOG.md"
assert_contains "update sans changement : déjà à jour" "$(mkup 2>&1)" "déjà à jour (1.1.0)"
printf '#!/usr/bin/env bash\nexit 1\n' >"${upd}/clone/tests/test_ko.sh"
sed -i 's/^COOLBASH_VERSION=.*/COOLBASH_VERSION="1.2.0"/' "${upd}/clone/cli/coolbash"
git -C "${upd}/clone" add -A
git -C "${upd}/clone" commit -qm "v1.2.0 cassée"
git -C "${upd}/clone" push -q
out="$(mkup 2>&1)"
assert_contains "tests en échec : message explicite, rien d'installé" "${out}" "rien n'a été installé"
assert_contains "…avec la version restée en place" "${out}" "1.1.0"

# --- install.sh : réinstallation par-dessus un clone existant ----------------
src="${COOLBASH_TEST_TMP}/src.git"
ih="${COOLBASH_TEST_TMP}/ihome"
mkdir -p "${ih}"
make_fake_clone "${COOLBASH_TEST_TMP}/srcwork"
git -C "${COOLBASH_TEST_TMP}/srcwork" init -q -b main
git -C "${COOLBASH_TEST_TMP}/srcwork" config user.email t@t
git -C "${COOLBASH_TEST_TMP}/srcwork" config user.name t
git -C "${COOLBASH_TEST_TMP}/srcwork" add -A
git -C "${COOLBASH_TEST_TMP}/srcwork" commit -qm init
git clone -q --bare "${COOLBASH_TEST_TMP}/srcwork" "${src}"
ins() { HOME="${ih}" COOLBASH_REPO_URL="${src}" bash "${COOLBASH_TEST_ROOT}/install.sh" >/dev/null 2>&1; }
assert_success "install.sh : première installation" ins
assert_file "…clone en place" "${ih}/.coolbash/cli/coolbash"
assert_success "install.sh : relancé sur un clone existant, il met à jour au lieu d'échouer" ins
mkdir -p "${COOLBASH_TEST_TMP}/ihome2/.coolbash"
: >"${COOLBASH_TEST_TMP}/ihome2/.coolbash/perso"
assert_failure "install.sh : refuse un ~/.coolbash qui n'est pas un clone git" env HOME="${COOLBASH_TEST_TMP}/ihome2" COOLBASH_REPO_URL="${src}" bash "${COOLBASH_TEST_ROOT}/install.sh"
assert_file "…sans y toucher" "${COOLBASH_TEST_TMP}/ihome2/.coolbash/perso"

# --- 0.33.0 : paquets (dist, pkg-deb, pkg-arch) et hooks git -----------------------------
pk="${COOLBASH_TEST_TMP}/pk"
make_fake_clone "${pk}"
pkver="$(sed -n 's/^COOLBASH_VERSION="\(.*\)"/\1/p' "${pk}/cli/coolbash")"
assert_success "make dist produit l'archive source" make -s -C "${pk}" dist
assert_file "…dist/coolbash-<version>.tar.gz" "${pk}/dist/coolbash-${pkver}.tar.gz"
assert_contains "…préfixée coolbash-<version>/, avec les modules" "$(tar -tzf "${pk}/dist/coolbash-${pkver}.tar.gz")" "coolbash-${pkver}/modules/00-core.bash"
assert_success "make pkg-deb produit le .deb (dpkg-deb, sinon ar + tar)" make -s -C "${pk}" pkg-deb
deb="${pk}/dist/coolbash_${pkver}_all.deb"
assert_file "…dist/coolbash_<version>_all.deb" "${deb}"
# FR : inspection par dpkg-deb quand il est là (Debian), sinon par ar + tar (Arch, macOS).
if command -v dpkg-deb >/dev/null 2>&1; then
  deb_control() { dpkg-deb -f "${deb}"; }
  deb_files() { dpkg-deb -c "${deb}"; }
else
  deb_control() { ar p "${deb}" control.tar.gz | tar -xzO ./control; }
  deb_files() { ar p "${deb}" data.tar.gz | tar -tzv; }
fi
if command -v ar >/dev/null 2>&1; then
  assert_eq "…un vrai .deb : debian-binary, control.tar.gz, data.tar.gz" "debian-binary control.tar.gz data.tar.gz" "$(ar t "${deb}" | tr '\n' ' ' | sed 's/ $//')"
else
  t_skip "ar absent : membres du .deb non listés"
fi
assert_contains "…control porte la version" "$(deb_control)" "Version: ${pkver}"
assert_contains "…les fichiers vont dans /usr/share/coolbash et /usr/bin/coolbash" "$(deb_files)" "./usr/bin/coolbash"
assert_contains "…avec le CHANGELOG et les citations" "$(deb_files)" "./usr/share/coolbash/share/fortunes/dev.txt"
assert_eq "…le wrapper est exécutable" "1" "$(deb_files | grep './usr/bin/coolbash$' | grep -c '^-rwxr-xr-x')"
if command -v makepkg >/dev/null 2>&1 && [[ $EUID -ne 0 ]]; then
  assert_success "make pkg-arch produit le paquet Arch (makepkg)" make -s -C "${pk}" pkg-arch
  assert_eq "…dist/arch/coolbash-<version>-1-any.pkg.tar.*" "1" "$(compgen -G "${pk}/dist/arch/coolbash-${pkver}-1-any.pkg.tar.*" | wc -l)"
  assert_contains "…avec /usr/share/coolbash et /usr/bin/coolbash" "$(tar -tf "${pk}"/dist/arch/coolbash-"${pkver}"-1-any.pkg.tar.* 2>/dev/null)" "usr/bin/coolbash"
else
  t_skip "makepkg absent (ou root) : paquet Arch non construit ici"
fi
# FR : installé par paquet = un Makefile sans .git : update renvoie vers le gestionnaire.
assert_contains "coolbash update sur une installation par paquet : message explicite" "$(COOLBASH_PREFIX="${pk}/.cb" COOLBASH_REPO="${pk}" bash "${pk}/cli/coolbash" update 2>&1)" "installé par paquet"
assert_success "make clean retire dist/" make -s -C "${pk}" clean
assert_no_path "…dist/ absent" "${pk}/dist"
# hooks
git -C "${pk}" init -q -b main
git -C "${pk}" config user.email t@t
git -C "${pk}" config user.name t
assert_success "make hooks pose les hooks git" make -s -C "${pk}" hooks
assert_eq "…pre-commit et pre-push, exécutables" "2" "$(
  n=0
  for h in pre-commit pre-push; do [[ -x "${pk}/.git/hooks/$h" ]] && n=$((n + 1)); done
  echo "$n"
)"
printf 'if then fi (\n' >|"${pk}/modules/zz-casse.bash"
git -C "${pk}" add -A
assert_failure "pre-commit : un module en erreur de syntaxe bloque le commit" git -C "${pk}" commit -qm "casse"
rm -f "${pk}/modules/zz-casse.bash"
git -C "${pk}" add -A
assert_success "…et le commit passe une fois corrigé (lint vert)" git -C "${pk}" commit -qm "ok"
assert_failure "make hooks hors d'un dépôt git échoue" make -s -C "${COOLBASH_TEST_TMP}/upd/clone/.." hooks

t_done
