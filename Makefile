SHELL  := /bin/bash
PREFIX ?= $(HOME)/.coolbash
BASHRC ?= $(HOME)/.bashrc
ROOT   := $(abspath .)
# FR : ligne ajoutée au bashrc (le grep de détection accepte aussi l'ancienne
#      forme `source $HOME/.coolbash/cli/coolbash init`).
SOURCE_LINE = source "$(PREFIX)/cli/coolbash" init

# FR : macOS — tar est bsdtar (pas de --transform ni --owner), sed -i veut un
#      suffixe, les shells de terminal sont des shells de login (~/.bash_profile).
UNAME := $(shell uname -s)
ifeq ($(shell tar --version 2>/dev/null | grep -c GNU),0)
  TAR_ROOT   := --uid 0 --gid 0
  TAR_PREFIX  = -s ',^,coolbash-$(VERSION)/,'
else
  TAR_ROOT   := --owner=0 --group=0
  TAR_PREFIX  = --transform 's,^,coolbash-$(VERSION)/,'
endif
# FR : pas de fichiers ._* (attributs étendus) dans les archives faites sous macOS.
export COPYFILE_DISABLE := 1
# FR : ligne ajoutée au fichier de login sous macOS, pour qu'il charge ~/.bashrc.
LOGIN_DIR  = $(patsubst %/,%,$(dir $(BASHRC)))
LOGIN_LINE = [ -n "$$BASH_VERSION" ] && [ -f "$(BASHRC)" ] && . "$(BASHRC)" \# CoolBash : shell de login → ~/.bashrc

.PHONY: install update uninstall verify lint fmt test font dist stage pkg-deb pkg-arch pkg hooks clean
VERSION := $(shell sed -n 's/^COOLBASH_VERSION="\(.*\)"/\1/p' cli/coolbash)
DIST    := dist
# FR : ce qui entre dans un paquet (README et LICENSE s'ils sont là).
PKG_FILES := cli modules share Makefile install.sh CHANGELOG.md packaging $(wildcard README.md LICENSE)

install:
	@echo "[CoolBash] Installing to $(PREFIX)..."
	@mkdir -p "$(PREFIX)/modules" "$(PREFIX)/cli" "$(PREFIX)/share/fortunes" "$(PREFIX)/share/lang"
	@# FR : `-ef` évite de copier un fichier sur lui-même quand PREFIX est le clone
	@#      (cas install.sh) ; 90-local-overrides appartient à l'utilisateur et
	@#      n'est jamais écrasé.
	@for m in modules/*.bash; do \
	  dest="$(PREFIX)/modules/$$(basename "$$m")"; \
	  [[ "$$m" -ef "$$dest" ]] && continue; \
	  [[ "$$m" == */90-local-overrides.bash && -f "$$dest" ]] && continue; \
	  cp "$$m" "$$dest.new" && mv -f "$$dest.new" "$$dest"; \
	done
	@# FR : copie puis `mv` = nouvel inode. `coolbash update` est exécuté PAR le
	@#      fichier qu'il remplace : réécrit en place, bash reprenait sa lecture au
	@#      milieu du nouveau contenu (« erreur de syntaxe près de ;; »).
	@for c in cli/coolbash cli/coolbash-font cli/coolbash-setup; do \
	  dest="$(PREFIX)/$$c"; \
	  [[ "$$c" -ef "$$dest" ]] && continue; \
	  cp "$$c" "$$dest.new" && mv -f "$$dest.new" "$$dest"; \
	done
	@chmod +x "$(PREFIX)/cli/coolbash" "$(PREFIX)/cli/coolbash-font" "$(PREFIX)/cli/coolbash-setup"
	@rm -f "$(PREFIX)/.update-available"
	@# FR : citations du MOTD (un fichier par thème). Les thèmes personnels vivent
	@#      dans $(PREFIX)/fortunes/ et ne sont pas touchés.
	@for f in share/fortunes/*.txt; do \
	  dest="$(PREFIX)/$$f"; \
	  [[ "$$f" -ef "$$dest" ]] && continue; \
	  cp "$$f" "$$dest.new" && mv -f "$$dest.new" "$$dest"; \
	done
	@# FR : les messages traduits (share/lang/*.bash).
	@for f in share/lang/*.bash; do \
	  dest="$(PREFIX)/$$f"; \
	  [[ "$$f" -ef "$$dest" ]] && continue; \
	  cp "$$f" "$$dest.new" && mv -f "$$dest.new" "$$dest"; \
	done
	@# FR : le CHANGELOG, pour `coolbash changelog` (copie puis mv, comme le reste).
	@if [[ -f CHANGELOG.md ]] && ! [[ CHANGELOG.md -ef "$(PREFIX)/CHANGELOG.md" ]]; then \
	  cp CHANGELOG.md "$(PREFIX)/CHANGELOG.md.new" && mv -f "$(PREFIX)/CHANGELOG.md.new" "$(PREFIX)/CHANGELOG.md"; \
	fi
	@[[ "$(ROOT)" -ef "$(PREFIX)" ]] || echo "$(ROOT)" >| "$(PREFIX)/.repo"
	@touch "$(BASHRC)"
	@# FR : première installation sur un .bashrc non vide → copie « avant CoolBash »
	@#      (une seule, jamais écrasée) ; `make uninstall` la restaure.
	@if ! grep -qF 'cli/coolbash' "$(BASHRC)"; then \
	  if [[ -s "$(BASHRC)" ]] && ! ls "$(BASHRC)".avant-coolbash-* >/dev/null 2>&1; then \
	    cp -a "$(BASHRC)" "$(BASHRC).avant-coolbash-$$(date +%F)"; \
	    echo "[CoolBash] Sauvegarde : $(BASHRC).avant-coolbash-$$(date +%F)"; \
	  fi; \
	  echo '$(SOURCE_LINE)' >> "$(BASHRC)"; \
	fi
	@# FR : macOS — Terminal et iTerm ouvrent des shells de LOGIN : bash y lit le
	@#      premier de ~/.bash_profile, ~/.bash_login, ~/.profile, et jamais
	@#      ~/.bashrc. On ajoute la ligne à celui qui existe (sinon ~/.bash_profile),
	@#      sauf s'il parle déjà de .bashrc — ou s'il EST le fichier visé par BASHRC
	@#      (il se sourcerait lui-même). Cherché à côté de BASHRC : c'est $(HOME).
	@if [[ "$(UNAME)" == Darwin ]]; then \
	  login=""; \
	  for f in "$(LOGIN_DIR)/.bash_profile" "$(LOGIN_DIR)/.bash_login" "$(LOGIN_DIR)/.profile"; do [[ -f "$$f" ]] && { login="$$f"; break; }; done; \
	  login="$${login:-$(LOGIN_DIR)/.bash_profile}"; \
	  if ! [[ "$$login" -ef "$(BASHRC)" ]] && ! grep -q 'bashrc' "$$login" 2>/dev/null; then \
	    printf '%s\n' '$(LOGIN_LINE)' >> "$$login"; \
	    echo "[CoolBash] macOS : $$login charge maintenant $(BASHRC) (shells de login)."; \
	  fi; \
	fi
	@# FR : la police des icônes est un confort — son échec (pas de réseau, pas
	@#      de xz…) ne doit jamais faire échouer l'installation.
	@COOLBASH_PREFIX="$(PREFIX)" bash cli/coolbash-font install || true
	@# FR : configuration à la fin — questions si on a un terminal (COOLBASH_SETUP=0
	@#      pour sauter, COOLBASH_SETUP_DEFAULTS=1 pour accepter sans demander : la
	@#      suite de tests), sinon reprise silencieuse de la configuration existante ;
	@#      un ~/.bashrc en mode compiled est régénéré dans les deux cas.
	@if [[ "$${COOLBASH_SETUP:-1}" != 0 ]]; then \
	  if [[ -t 0 && -t 1 && "$${COOLBASH_SETUP_DEFAULTS:-0}" != 1 ]]; then COOLBASH_PREFIX="$(PREFIX)" COOLBASH_BASHRC="$(BASHRC)" bash "$(PREFIX)/cli/coolbash-setup" || true; \
	  else COOLBASH_PREFIX="$(PREFIX)" COOLBASH_BASHRC="$(BASHRC)" bash "$(PREFIX)/cli/coolbash-setup" --defaults >/dev/null || true; fi; \
	fi
	@echo "[CoolBash] Installation complete ✅"
	@# FR : macOS — le shell par défaut est zsh : CoolBash ne se voit que dans bash.
	@if [[ "$(UNAME)" == Darwin && "$${SHELL##*/}" != bash ]]; then \
	  b="$$(command -v bash)"; \
	  echo "[CoolBash] Ton shell de connexion est $${SHELL##*/} : lance « bash » pour voir CoolBash."; \
	  echo "           Pour l'adopter : grep -qx $$b /etc/shells || echo $$b | sudo tee -a /etc/shells ; chsh -s $$b"; \
	fi

update:
	@# FR : jamais d'installation sans suite de tests verte après le pull.
	@#      La fin annonce ce qui a changé : « 0.7.0 → 0.8.0 », « déjà à jour »,
	@#      ou un échec explicite — plus de faux « ça a marché ».
	@ver() { sed -n 's/^COOLBASH_VERSION="\(.*\)"/\1/p' "$(PREFIX)/cli/coolbash" 2>/dev/null; }; \
	old="$$(ver)"; \
	git -C "$(ROOT)" pull --rebase || { echo "[CoolBash] ✘ git pull en échec : rien n'a été installé (version en place : $${old:-aucune})." >&2; exit 1; }; \
	$(MAKE) -C "$(ROOT)" test || { echo "[CoolBash] ✘ Tests en échec : rien n'a été installé (version en place : $${old:-aucune})." >&2; exit 1; }; \
	new="$$(sed -n 's/^COOLBASH_VERSION="\(.*\)"/\1/p' cli/coolbash)"; \
	if [[ -n "$$old" && "$$old" != "$$new" && -f CHANGELOG.md ]]; then \
	  echo "[CoolBash] Nouveautés depuis la $$old :"; \
	  COOLBASH_PREFIX="$(PREFIX)" bash cli/coolbash changelog --since "$$old" | sed 's/^/  /'; \
	fi; \
	$(MAKE) -C "$(ROOT)" install || exit 1; \
	new="$$(ver)"; \
	if [[ -z "$$old" ]]; then echo "[CoolBash] Version installée : $$new"; \
	elif [[ "$$old" == "$$new" ]]; then echo "[CoolBash] déjà à jour ($$new) — modules réinstallés."; \
	else echo "[CoolBash] Mise à jour : $$old → $$new — recharge ton shell : source ~/.bashrc"; fi

uninstall:
	@# FR : garde-fou — ne jamais supprimer le clone git lui-même.
	@if [[ "$(ROOT)" -ef "$(PREFIX)" ]]; then \
	  echo "[CoolBash] Refusing to remove $(PREFIX): it is the git clone itself." >&2; exit 1; \
	fi
	@echo "[CoolBash] Removing CoolBash..."
	@bash cli/coolbash-font remove || true
	@rm -rf "$(PREFIX)"
	@# FR : le .bashrc d'avant CoolBash est restauré s'il a été sauvegardé (le
	@#      courant est gardé à côté) ; sinon on retire seulement la ligne source.
	@backup="$$(ls -t "$(BASHRC)".avant-coolbash-* 2>/dev/null | head -1)"; \
	if [[ -n "$$backup" && -f "$(BASHRC)" ]]; then \
	  cp -a "$(BASHRC)" "$(BASHRC).coolbash-retire-$$(date +%F)"; \
	  cp -a "$$backup" "$(BASHRC)"; \
	  echo "[CoolBash] $(BASHRC) restauré depuis $$backup (l'ancien est dans $(BASHRC).coolbash-retire-$$(date +%F))"; \
	elif [[ -f "$(BASHRC)" ]]; then \
	  grep -v 'cli/coolbash"* init' "$(BASHRC)" > "$(BASHRC).coolbash-tmp"; \
	  cat "$(BASHRC).coolbash-tmp" >| "$(BASHRC)"; rm -f "$(BASHRC).coolbash-tmp"; \
	fi
	@# FR : macOS — la ligne ajoutée au fichier de login repart aussi.
	@for f in "$(LOGIN_DIR)/.bash_profile" "$(LOGIN_DIR)/.bash_login" "$(LOGIN_DIR)/.profile"; do \
	  grep -q '# CoolBash : shell de login' "$$f" 2>/dev/null || continue; \
	  grep -v '# CoolBash : shell de login' "$$f" > "$$f.coolbash-tmp"; \
	  cat "$$f.coolbash-tmp" >| "$$f"; rm -f "$$f.coolbash-tmp"; \
	  [[ -s "$$f" ]] || rm -f "$$f"; \
	done
	@echo "[CoolBash] Uninstalled successfully."

font:
	@COOLBASH_PREFIX="$(PREFIX)" bash cli/coolbash-font install

SH_FILES := cli/coolbash cli/coolbash-font cli/coolbash-setup install.sh modules/*.bash share/lang/*.bash tests/*.sh scripts/hooks/* packaging/coolbash-wrapper

# --- paquets ------------------------------------------------------------------------
# FR : `make dist` → dist/coolbash-X.Y.Z.tar.gz (l'archive source) ; `make pkg-deb` →
#      dist/coolbash_X.Y.Z_all.deb (dpkg-deb en gzip — installable par tout dpkg —,
#      sinon ar + tar : un .deb n'est que cela) ; `make pkg-arch` → dist/arch/coolbash-X.Y.Z-1-any.pkg.tar.zst (makepkg,
#      depuis packaging/arch/PKGBUILD.in). Les deux installent /usr/share/coolbash
#      et /usr/bin/coolbash ; chaque utilisateur fait ensuite `coolbash install`.
dist:
	@mkdir -p "$(DIST)"
	@tar -czf "$(DIST)/coolbash-$(VERSION).tar.gz" $(TAR_PREFIX) $(TAR_ROOT) $(PKG_FILES)
	@echo "[CoolBash] $(DIST)/coolbash-$(VERSION).tar.gz"

stage:
	@rm -rf "$(DIST)/root"
	@mkdir -p "$(DIST)/root/usr/share/coolbash" "$(DIST)/root/usr/bin" "$(DIST)/root/usr/share/doc/coolbash"
	@cp -r cli modules share Makefile install.sh CHANGELOG.md "$(DIST)/root/usr/share/coolbash/"
	@[[ -f README.md ]] && cp README.md "$(DIST)/root/usr/share/doc/coolbash/" || true
	@[[ -f LICENSE ]] && cp LICENSE "$(DIST)/root/usr/share/doc/coolbash/copyright" || true
	@install -m 755 packaging/coolbash-wrapper "$(DIST)/root/usr/bin/coolbash"
	@find "$(DIST)/root" -type d -exec chmod 755 {} +
	@find "$(DIST)/root" -type f ! -perm -u+x -exec chmod 644 {} +

pkg-deb: stage
	@# FR : umask 027 (Debian 13) créerait DEBIAN/ en 750 : dpkg-deb exige 755.
	@#      set -e : une étape qui échoue fait échouer make (plus de .deb fantôme).
	@set -e; \
	mkdir -p "$(DIST)/root/DEBIAN"; chmod 755 "$(DIST)/root/DEBIAN"; \
	sed 's/@VERSION@/$(VERSION)/' packaging/deb/control.in >| "$(DIST)/root/DEBIAN/control"; \
	chmod 644 "$(DIST)/root/DEBIAN/control"; \
	deb="$(DIST)/coolbash_$(VERSION)_all.deb"; \
	if command -v dpkg-deb >/dev/null 2>&1; then \
	  dpkg-deb -Zgzip --build --root-owner-group "$(DIST)/root" "$$deb" >/dev/null; \
	else \
	  tmp="$(DIST)/deb-build"; rm -rf "$$tmp"; mkdir -p "$$tmp"; \
	  tar -C "$(DIST)/root" $(TAR_ROOT) -czf "$$tmp/data.tar.gz" ./usr; \
	  tar -C "$(DIST)/root/DEBIAN" $(TAR_ROOT) -czf "$$tmp/control.tar.gz" ./control; \
	  printf '2.0\n' >| "$$tmp/debian-binary"; \
	  rm -f "$$deb"; (cd "$$tmp" && ar rc "../../$$deb" debian-binary control.tar.gz data.tar.gz); \
	  rm -rf "$$tmp"; \
	fi; \
	echo "[CoolBash] $$deb"

pkg-arch: dist
	@command -v makepkg >/dev/null 2>&1 || { echo "makepkg absent (Arch Linux seulement)" >&2; exit 1; }
	@mkdir -p "$(DIST)/arch"
	@sed 's/@VERSION@/$(VERSION)/' packaging/arch/PKGBUILD.in >| "$(DIST)/arch/PKGBUILD"
	@cp "$(DIST)/coolbash-$(VERSION).tar.gz" "$(DIST)/arch/"
	@cd "$(DIST)/arch" && makepkg -f --noconfirm >/dev/null && echo "[CoolBash] $(DIST)/arch/$$(ls coolbash-$(VERSION)-*.pkg.tar.* | head -1)"

pkg: pkg-deb pkg-arch

# FR : `make hooks` — pre-commit = lint, pre-push = tests : rien ne part rouge.
hooks:
	@[[ -d .git ]] || { echo "pas un dépôt git" >&2; exit 1; }
	@mkdir -p .git/hooks
	@for h in pre-commit pre-push; do ln -sf "../../scripts/hooks/$$h" ".git/hooks/$$h"; done
	@echo "[CoolBash] hooks posés : pre-commit (make lint), pre-push (make test)"

clean:
	@rm -rf "$(DIST)"

verify:
	@echo "[CoolBash] Verifying syntax..."
	@# FR : `bash -n a b` ne vérifie que `a` (b devient $$1) — d'où la boucle.
	@for f in $(SH_FILES); do bash -n "$$f" || exit 1; done
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck cli/coolbash cli/coolbash-font cli/coolbash-setup install.sh tests/*.sh && shellcheck -S warning modules/*.bash; \
	else \
	  echo "  shellcheck absent : contrôle limité à 'bash -n'."; \
	fi
	@# FR : style uniforme (options dans .editorconfig). Fatal si shfmt est là
	@#      et trouve un écart : `make fmt` corrige.
	@if command -v shfmt >/dev/null 2>&1; then \
	  out="$$(shfmt -l $(SH_FILES))"; \
	  if [[ -n "$$out" ]]; then echo "  ✘ shfmt : fichiers à formater (make fmt) :"; echo "$$out" | sed 's/^/      /'; exit 1; fi; \
	else \
	  echo "  shfmt absent : style non vérifié (https://github.com/mvdan/sh)."; \
	fi
	@echo "[CoolBash] Verification complete ✅"

# FR : `make lint` = verify (nom attendu par tout le monde) ; `make fmt` applique shfmt.
lint: verify

fmt:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt absent : https://github.com/mvdan/sh/releases" >&2; exit 1; }
	@shfmt -w $(SH_FILES) && echo "[CoolBash] Formaté ✅"

test:
	@bash tests/run.sh
