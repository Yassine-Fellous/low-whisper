#!/bin/bash
set -e

echo "Building LowWhisper executable in Release mode..."
swift build -c release

echo "Creating LowWhisper.app bundle structure..."
rm -rf LowWhisper.app
mkdir -p LowWhisper.app/Contents/MacOS
mkdir -p LowWhisper.app/Contents/Frameworks
mkdir -p LowWhisper.app/Contents/Resources

# Copy executable
cp .build/release/LowWhisper LowWhisper.app/Contents/MacOS/

# Copy framework
cp -R Frameworks/whisper.xcframework/macos-arm64/whisper.framework LowWhisper.app/Contents/Frameworks/

# Update RPATH to ensure the app loads the framework from the bundle
# Using || true in case the rpath is already present or fails non-critically
install_name_tool -add_rpath "@executable_path/../Frameworks" LowWhisper.app/Contents/MacOS/LowWhisper || true

# Write Info.plist
cat > LowWhisper.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LowWhisper</string>
    <key>CFBundleIdentifier</key>
    <string>com.lowwhisper.LowWhisper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LowWhisper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.3</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>LowWhisper a besoin d'accéder au microphone pour capturer votre voix pour la dictée.</string>
</dict>
</plist>
EOF

echo "Ad-hoc signing LowWhisper.app..."
codesign --force --deep --sign - LowWhisper.app

echo "LowWhisper.app successfully built and packaged at $(pwd)/LowWhisper.app!"
