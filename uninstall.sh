#!/usr/bin/env bash
#
# Removes Background Remover from /Applications.
#
# Usage:
#   ./uninstall.sh                # remove from /Applications
#   ./uninstall.sh --from ~/Apps  # remove from a custom directory

set -euo pipefail

APP_NAME="Background Remover"
INSTALL_DIR="/Applications"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--from) INSTALL_DIR="$2"; shift 2 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

DEST="$INSTALL_DIR/$APP_NAME.app"

if [[ ! -d "$DEST" ]]; then
	echo "\"$APP_NAME\" is not installed in $INSTALL_DIR."
	exit 0
fi

echo "Removing $DEST…"
if rm -rf "$DEST" 2>/dev/null; then
	:
else
	sudo rm -rf "$DEST"
fi

echo "Removed. (Your rembg install and downloaded models in ~/.u2net are untouched.)"
