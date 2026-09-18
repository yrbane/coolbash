SHELL  := /bin/bash
PREFIX ?= $(HOME)/.coolbash
BASHRC ?= $(HOME)/.bashrc
ROOT   := $(abspath .)
# FR : ligne ajoutée au bashrc (le grep de détection accepte aussi l'ancienne
#      forme `source $HOME/.coolbash/cli/coolbash init`).
SOURCE_LINE = source "$(PREFIX)/cli/coolbash" init

.PHONY: install update uninstall verify test font

install:
	@echo "[CoolBash] Installing to $(PREFIX)..."
	@mkdir -p "$(PREFIX)/modules" "$(PREFIX)/cli"
	@# FR : `-ef` évite de copier un fichier sur lui-même quand PREFIX est le clone
	@#      (cas install.sh) ; 90-local-overrides appartient à l'utilisateur et
	@#      n'est jamais écrasé.
	@for m in modules/*.bash; do \
	  dest="$(PREFIX)/modules/$$(basename "$$m")"; \
	  [[ "$$m" -ef "$$dest" ]] && continue; \
	  [[ "$$m" == */90-local-overrides.bash && -f "$$dest" ]] && continue; \
	  cp "$$m" "$$dest"; \
	done
	@[[ cli/coolbash -ef "$(PREFIX)/cli/coolbash" ]] || cp cli/coolbash "$(PREFIX)/cli/coolbash"
	@[[ cli/coolbash-font -ef "$(PREFIX)/cli/coolbash-font" ]] || cp cli/coolbash-font "$(PREFIX)/cli/coolbash-font"
	@chmod +x "$(PREFIX)/cli/coolbash" "$(PREFIX)/cli/coolbash-font"
	@[[ "$(ROOT)" -ef "$(PREFIX)" ]] || echo "$(ROOT)" >| "$(PREFIX)/.repo"
	@touch "$(BASHRC)"
	@grep -qF 'cli/coolbash' "$(BASHRC)" || echo '$(SOURCE_LINE)' >> "$(BASHRC)"
	@# FR : la police des icônes est un confort — son échec (pas de réseau, pas
	@#      de xz…) ne doit jamais faire échouer l'installation.
	@bash cli/coolbash-font install || true
	@echo "[CoolBash] Installation complete ✅"

update:
	@# FR : jamais d'installation sans suite de tests verte après le pull.
	@git -C "$(ROOT)" pull --rebase
	@$(MAKE) -C "$(ROOT)" test
	@$(MAKE) -C "$(ROOT)" install

uninstall:
	@# FR : garde-fou — ne jamais supprimer le clone git lui-même.
	@if [[ "$(ROOT)" -ef "$(PREFIX)" ]]; then \
	  echo "[CoolBash] Refusing to remove $(PREFIX): it is the git clone itself." >&2; exit 1; \
	fi
	@echo "[CoolBash] Removing CoolBash..."
	@rm -rf "$(PREFIX)"
	@[[ -f "$(BASHRC)" ]] && sed -i '\#cli/coolbash"* init#d' "$(BASHRC)" || true
	@echo "[CoolBash] Uninstalled successfully."

font:
	@bash cli/coolbash-font install

verify:
	@echo "[CoolBash] Verifying syntax..."
	@# FR : `bash -n a b` ne vérifie que `a` (b devient $$1) — d'où la boucle.
	@for f in cli/coolbash cli/coolbash-font install.sh modules/*.bash tests/*.sh; do bash -n "$$f" || exit 1; done
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck cli/coolbash cli/coolbash-font install.sh tests/*.sh && shellcheck -S error modules/*.bash; \
	else \
	  echo "  shellcheck absent : contrôle limité à 'bash -n'."; \
	fi
	@echo "[CoolBash] Verification complete ✅"

test:
	@bash tests/run.sh
