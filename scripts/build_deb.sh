#!/bin/bash

# Configuration
APP_NAME="onyxcore"
VERSION="1.0.0"
PACKAGE_NAME="${APP_NAME}_${VERSION}_amd64"
BUILD_DIR="build/linux/x64/release/bundle"
DEB_DIR="build/debian/${PACKAGE_NAME}"

echo "🚀 Building OnyxCore in Release mode..."
flutter build linux --release

if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed. Aborting."
    exit 1
fi

# 1. Create Structure
echo "📂 Preparing Debian structure..."
rm -rf "build/debian"
mkdir -p "${DEB_DIR}/DEBIAN"
mkdir -p "${DEB_DIR}/usr/bin"
mkdir -p "${DEB_DIR}/usr/lib/${APP_NAME}"
mkdir -p "${DEB_DIR}/usr/share/applications"
mkdir -p "${DEB_DIR}/usr/share/icons/${APP_NAME}"

# 2. Copy Build Files
echo "📦 Copying build artifacts..."
cp -r ${BUILD_DIR}/* "${DEB_DIR}/usr/lib/${APP_NAME}/"

# 3. Create Symlink in /usr/bin
cat <<EOF > "${DEB_DIR}/usr/bin/${APP_NAME}"
#!/bin/bash
/usr/lib/${APP_NAME}/${APP_NAME} "\$@"
EOF
chmod +x "${DEB_DIR}/usr/bin/${APP_NAME}"

# 4. Copy Icon
# Using video.svg as a fallback app icon
if [ -f "assets/icons/video.svg" ]; then
    cp "assets/icons/video.svg" "${DEB_DIR}/usr/share/icons/${APP_NAME}/icon.svg"
    ICON_PATH="/usr/share/icons/${APP_NAME}/icon.svg"
else
    ICON_PATH="system-file-manager"
fi

# 5. Create Desktop Entry
cat <<EOF > "${DEB_DIR}/usr/share/applications/${APP_NAME}.desktop"
[Desktop Entry]
Version=1.0
Name=OnyxCore
GenericName=Multimedia File Manager
Comment=High-performance Linux-native multimedia explorer
Exec=${APP_NAME}
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=Utility;Multimedia;
EOF

# 6. Create Control File
# libmpv1 or libmpv2 is required for media_kit
cat <<EOF > "${DEB_DIR}/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, liblzma5, libmpv1 | libmpv2, mpv, p7zip-full
Maintainer: Vimal Babu
Description: OnyxCore — Linux-native multimedia file manager.
 A high-performance, multi-window explorer designed for advanced archival and media management.
EOF

# 7. Build Package
echo "📦 Building .deb package..."
dpkg-deb --build --root-owner-group "${DEB_DIR}"

echo "✅ Done! Package located at: build/debian/${PACKAGE_NAME}.deb"
