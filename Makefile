# Half-Life: Continuum Edition — build & run front door.
#
# Thin wrappers over the scripts in tools/ (the real work lives there:
# Docker-based reproducible dist builds, the flatpak bundler, the native
# dev build). See tools/dist/README-DIST.md for the packaging details.

SHELL := /bin/bash

# `make play GAME=of ARGS="-windowed +map c1a0"`
GAME ?=
ARGS ?=

.DEFAULT_GOAL := help

.PHONY: help linux linux-arm64 windows macos flatpak install-deck play build-engine clean distclean

help:
	@echo "Half-Life: Continuum Edition"
	@echo
	@echo "Distributable builds (Docker; artifacts land in dist/artifacts/):"
	@echo "  make linux         linux-amd64 tarball + Steam Deck flatpak"
	@echo "  make linux-arm64   linux-arm64 tarball (needs qemu binfmt)"
	@echo "  make windows       win32 (i686) zip"
	@echo "  make macos         macOS universal bundle (must run on a Mac)"
	@echo "  make flatpak       Steam Deck flatpak only"
	@echo
	@echo "Deploy / run:"
	@echo "  make install-deck  build flatpak + install on a Steam Deck"
	@echo "                     (set DECK_SSH=user@host, e.g. deck@steamdeck.local)"
	@echo "  make play          native engine rebuild + launch"
	@echo "                     (GAME=of ARGS=\"-windowed\")"
	@echo
	@echo "  make clean         remove dist staging + artifacts"
	@echo "  make distclean     clean + reset the native waf build state"
	@echo "                     (forces a full reconfigure; keeps install/ + .deps/)"

## Distributable builds -------------------------------------------------

linux:
	tools/build_all.sh flatpak

linux-arm64:
	tools/build_all.sh linux-arm64

windows:
	tools/build_all.sh win32

macos:
	tools/dist/build-macos.sh

flatpak:
	tools/build_all.sh flatpak

## Deploy / run --------------------------------------------------------

install-deck:
	./install-deck.sh

build-engine:
	tools/build-engine.sh

play: build-engine
	./play-continuum.sh $(GAME) $(ARGS)

## Housekeeping --------------------------------------------------------

clean:
	rm -rf dist/linux-amd64 dist/linux-arm64 dist/win32 dist/artifacts

# Reset the native (waf) build state of both submodules — this is what goes
# stale after a move/rename. Leaves install/ (may hold copied game content)
# and .deps/ (locally built SDL2) untouched. build-engine.sh reconfigures on
# the next `make play`.
distclean: clean
	rm -rf xash3d-fwgs/build xash3d-fwgs/.lock-waf_*
	rm -rf hlsdk-portable/build hlsdk-portable/.lock-waf_*
