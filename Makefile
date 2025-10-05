SHELL := /bin/bash
PREFIX ?= $(HOME)/.coolbash
BASHRC ?= $(HOME)/.bashrc
DATE   := $(shell date +%F-%H%M%S)

.PHONY: install update uninstall verify

install:
	@echo "[CoolBash] Installing modules to $(PREFIX)..."
	@mkdir -p "$(PREFIX)/modules"
	@cp -r modules/* "$(PREFIX)/modules/"
	@mkdir -p "$(PREFIX)/cli"
	@cp cli/coolbash "$(PREFIX)/cli/coolbash"
	@chmod +x "$(PREFIX)/cli/coolbash"
	@grep -q "coolbash" $(BASHRC) || echo 'source $$HOME/.coolbash/cli/coolbash init' >> $(BASHRC)
	@echo "[CoolBash] Installation complete."

update:
	@git pull --rebase
	@$(MAKE) install

uninstall:
	@echo "[CoolBash] Removing CoolBash..."
	@rm -rf "$(PREFIX)"
	@sed -i '/coolbash/d' $(BASHRC)
	@echo "[CoolBash] Uninstalled successfully."

verify:
	@bash -n modules/*.bash
	@echo "[CoolBash] Syntax OK ✅"

