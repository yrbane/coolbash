SHELL  := /bin/bash
PREFIX ?= $(HOME)/.coolbash
BASHRC ?= $(HOME)/.bashrc
ROOT   := $(abspath .)
# FR : ligne ajoutée au bashrc (le grep de détection accepte aussi l'ancienne
#      forme `source $HOME/.coolbash/cli/coolbash init`).
SOURCE_LINE = source "$(PREFIX)/cli/coolbash" init

.PHONY: install update uninstall verify test

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
	@chmod +x "$(PREFIX)/cli/coolbash"
	@[[ "$(ROOT)" -ef "$(PREFIX)" ]] || echo "$(ROOT)" >| "$(PREFIX)/.repo"
	@touch "$(BASHRC)"
	@grep -qF 'cli/coolbash' "$(BASHRC)" || echo '$(SOURCE_LINE)' >> "$(BASHRC)"
	@echo "[CoolBash] Installation complete ✅"

update:
	@git -C "$(ROOT)" pull --rebase
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

verify:
	@echo "[CoolBash] Verifying syntax..."
	@bash -n cli/coolbash install.sh modules/*.bash
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck cli/coolbash install.sh tests/*.sh && shellcheck -S error modules/*.bash; \
	else \
	  echo "  shellcheck absent : contrôle limité à 'bash -n'."; \
	fi
	@echo "[CoolBash] Verification complete ✅"

test:
	@bash tests/run.sh
