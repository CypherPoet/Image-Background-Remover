#!/usr/bin/env bash
#
# Installs Background Remover to /Applications.
#
# Steps:
#   1. Make sure the rembg CLI is available (offer to install it if not).
#   2. Build the app from source.
#   3. Copy it into /Applications.
#
# Usage:
#   ./install.sh                 # build + install to /Applications
#   ./install.sh --universal     # build a universal binary first
#   ./install.sh --to ~/Apps     # install to a custom directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Background Remover"
APP_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
INSTALL_DIR="/Applications"
BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--universal) BUILD_ARGS+=("--universal"); shift ;;
		--to) INSTALL_DIR="$2"; shift 2 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

bold() { printf '\033[1m%s\033[0m\n' "$1"; }

# --- 1. Check for rembg ------------------------------------------------------

bold "Checking for rembg…"
if command -v rembg >/dev/null 2>&1; then
	echo "  Found: $(command -v rembg)"
else
	echo "  rembg was not found on your PATH."
	if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
		PIP_CMD="$(command -v pip3 || command -v pip)"
		read -r -p "  Install it now with: $PIP_CMD install \"rembg[cli]\" ? [y/N] " reply
		if [[ "$reply" =~ ^[Yy]$ ]]; then
			"$PIP_CMD" install "rembg[cli]"
		else
			echo "  Skipping. Install rembg yourself before running the app:" >&2
			echo "    pip install \"rembg[cli]\"" >&2
		fi
	else
		echo "  pip wasn't found either. Install Python 3 and then:" >&2
		echo "    pip install \"rembg[cli]\"" >&2
	fi
fi

# --- 2. Build ----------------------------------------------------------------

bold "Building the app…"
"$SCRIPT_DIR/build.sh" "${BUILD_ARGS[@]}"

if [[ ! -d "$APP_BUNDLE" ]]; then
	echo "error: build did not produce $APP_BUNDLE" >&2
	exit 1
fi

# --- 3. Install --------------------------------------------------------------

DEST="$INSTALL_DIR/$APP_NAME.app"
bold "Installing to $DEST…"

if [[ -d "$DEST" ]]; then
	echo "  Removing existing install…"
	rm -rf "$DEST"
fi

if cp -R "$APP_BUNDLE" "$DEST" 2>/dev/null; then
	:
else
	echo "  Need elevated permissions to write to $INSTALL_DIR."
	sudo cp -R "$APP_BUNDLE" "$DEST"
fi

bold "Done."
echo "Installed \"$APP_NAME\" to $INSTALL_DIR."
echo "Launch it from Spotlight or with: open \"$DEST\""
