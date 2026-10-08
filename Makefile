SHELL  := /bin/bash
PREFIX ?= $(HOME)/.coolbash
BASHRC ?= $(HOME)/.bashrc
ROOT   := $(abspath .)
# FR : ligne ajoutée au bashrc (le grep de détection accepte aussi l'ancienne
#      forme `source $HOME/.coolbash/cli/coolbash init`).
SOURCE_LINE = source "$(PREFIX)/cli/coolbash" init

.PHONY: install update uninstall verify lint fmt test font

install:
	@echo "[CoolBash] Installing to $(PREFIX)..."
	@mkdir -p "$(PREFIX)/modules" "$(PREFIX)/cli" "$(PREFIX)/share/fortunes"
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
	  sed -i '\#cli/coolbash"* init#d' "$(BASHRC)"; \
	fi
	@echo "[CoolBash] Uninstalled successfully."

font:
	@COOLBASH_PREFIX="$(PREFIX)" bash cli/coolbash-font install

SH_FILES := cli/coolbash cli/coolbash-font cli/coolbash-setup install.sh modules/*.bash tests/*.sh

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
