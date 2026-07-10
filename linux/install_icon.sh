#!/bin/bash
# install_icon.sh — Install OnyxCore app icon and .desktop file for app-launcher visibility
# Run this after building: bash linux/install_icon.sh
# This installs the icon to the XDG icon theme so it appears in the app section.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ICON_SRC="$PROJECT_ROOT/assets/app_icon/png"
DESKTOP_SRC="$SCRIPT_DIR/onyxcore.desktop"

# Determine install prefix (user-local by default, system if run as root)
if [ "$EUID" -eq 0 ]; then
  ICON_BASE="/usr/share/icons/hicolor"
  DESKTOP_DIR="/usr/share/applications"
  echo "Installing system-wide (root)..."
else
  ICON_BASE="$HOME/.local/share/icons/hicolor"
  DESKTOP_DIR="$HOME/.local/share/applications"
  echo "Installing for current user: $USER"
fi

mkdir -p "$DESKTOP_DIR"

# Install PNG icons at each size into the XDG hicolor theme
declare -a SIZES=(16 24 32 48 64 128 256 512)
for SIZE in "${SIZES[@]}"; do
  DEST="$ICON_BASE/${SIZE}x${SIZE}/apps"
  mkdir -p "$DEST"
  cp "$ICON_SRC/icon_${SIZE}x${SIZE}.png" "$DEST/onyxcore.png"
  echo "  ✓ Installed ${SIZE}x${SIZE} icon → $DEST/onyxcore.png"
done

# Install the SVG as a scalable icon (preferred by GNOME Shell and modern DE)
SCALABLE_DIR="$ICON_BASE/scalable/apps"
mkdir -p "$SCALABLE_DIR"
cp "$PROJECT_ROOT/assets/app_icon/app_icon.svg" "$SCALABLE_DIR/onyxcore.svg"
echo "  ✓ Installed scalable SVG icon → $SCALABLE_DIR/onyxcore.svg"

# Install the .desktop file
cp "$DESKTOP_SRC" "$DESKTOP_DIR/onyxcore.desktop"
echo "  ✓ Installed .desktop → $DESKTOP_DIR/onyxcore.desktop"

# Refresh the icon cache
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$ICON_BASE" 2>/dev/null || true
  echo "  ✓ Icon cache refreshed"
fi

# Update desktop database
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  echo "  ✓ Desktop database updated"
fi

echo ""
echo "✅ OnyxCore icon installed! You should see the icon in your app launcher."
echo "   If using GNOME, you may need to log out and back in, or run:"
echo "   gsettings reset-recursively org.gnome.shell"
