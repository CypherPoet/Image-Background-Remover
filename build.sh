#!/usr/bin/env bash
#
# Builds Background Remover.app from the Swift sources using swiftc.
#
# Produces a self-contained, ad-hoc-signed .app bundle under ./build. No Xcode
# project required — just the Swift toolchain that ships with Xcode / the
# Command Line Tools.
#
# Usage:
#   ./build.sh            # build for the host architecture
#   ./build.sh --universal  # build a universal (arm64 + x86_64) binary

set -euo pipefail

APP_NAME="Background Remover"
EXECUTABLE="BackgroundRemover"
DEPLOYMENT_TARGET="14.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_DIR="$SCRIPT_DIR/app/Sources"
INFO_PLIST="$SCRIPT_DIR/app/Resources/Info.plist"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
BINARY_PATH="$MACOS_DIR/$EXECUTABLE"

# --- Preconditions -----------------------------------------------------------

if ! command -v swiftc >/dev/null 2>&1; then
	echo "error: swiftc not found. Install Xcode or the Command Line Tools (xcode-select --install)." >&2
	exit 1
fi

# --- Target selection --------------------------------------------------------

build_universal=false
if [[ "${1:-}" == "--universal" ]]; then
	build_universal=true
fi

host_arch="$(uname -m)"  # arm64 or x86_64

# --- Assemble the bundle skeleton -------------------------------------------

echo "Cleaning previous build…"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# Collect every Swift source file.
swift_sources=()
while IFS= read -r -d '' file; do
	swift_sources+=("$file")
done < <(find "$SOURCES_DIR" -name '*.swift' -print0)

if [[ ${#swift_sources[@]} -eq 0 ]]; then
	echo "error: no Swift sources found under $SOURCES_DIR" >&2
	exit 1
fi

echo "Compiling ${#swift_sources[@]} Swift files…"

compile_for_arch() {
	local arch="$1"
	local output="$2"
	swiftc \
		-O \
		-parse-as-library \
		-target "${arch}-apple-macos${DEPLOYMENT_TARGET}" \
		-framework SwiftUI \
		-framework AppKit \
		-framework UniformTypeIdentifiers \
		-o "$output" \
		"${swift_sources[@]}"
}

if $build_universal; then
	echo "Building universal binary (arm64 + x86_64)…"
	tmp_arm="$(mktemp)"
	tmp_x86="$(mktemp)"
	compile_for_arch "arm64" "$tmp_arm"
	compile_for_arch "x86_64" "$tmp_x86"
	lipo -create "$tmp_arm" "$tmp_x86" -output "$BINARY_PATH"
	rm -f "$tmp_arm" "$tmp_x86"
else
	echo "Building for host architecture ($host_arch)…"
	compile_for_arch "$host_arch" "$BINARY_PATH"
fi

chmod +x "$BINARY_PATH"

# --- Sign --------------------------------------------------------------------
# Ad-hoc signing lets a locally built app launch without Gatekeeper complaints.

echo "Signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null 2>&1 || {
	echo "warning: ad-hoc codesign failed; the app may still run." >&2
}

echo "Built: $APP_BUNDLE"
