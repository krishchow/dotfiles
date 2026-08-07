DOTFILES_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

DOTFILES  ?= $(HOME)/projects/shell
DRY_RUN   ?= 0

export DOTFILES
export DRY_RUN

.PHONY: install link brew unlink sync-install sync-uninstall dry-run help

install:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh install
	@echo "✓ Done. Restart your shell or run: source ~/.zshrc"

link:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh link

brew:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh brew

unlink:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh unlink

sync-install:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh sync-install

sync-uninstall:
	@DOTFILES="$(DOTFILES)" DRY_RUN="$(DRY_RUN)" $(DOTFILES_DIR)scripts/bootstrap.sh sync-uninstall

dry-run:
	@$(MAKE) install DRY_RUN=1

help:
	@echo "make install       Full setup: link + all installers"
	@echo "make link          Bootstrap ~/.zshrc source line"
	@echo "make brew          Install Homebrew + Brewfile packages"
	@echo "make unlink        Remove source line from ~/.zshrc"
	@echo "make sync-install  Install repo-sync launchd agent (macOS)"
	@echo "make sync-uninstall Uninstall repo-sync launchd agent"
	@echo "make dry-run       Preview what install would do"
	@echo ""
	@echo "Targets support DRY_RUN=1:  make link DRY_RUN=1"
