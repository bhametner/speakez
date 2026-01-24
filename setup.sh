#!/bin/bash

# Speakez Setup Script
# This script helps set up the development environment

set -e

echo "=========================================="
echo "Speakez Setup Script"
echo "=========================================="
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed."
    echo "Please install Xcode from the App Store."
    exit 1
fi

echo "✓ Xcode found"

# Check for xcodegen (optional but recommended)
if command -v xcodegen &> /dev/null; then
    echo "✓ XcodeGen found"
    HAS_XCODEGEN=true
else
    echo "⚠ XcodeGen not found (optional)"
    echo "  Install with: brew install xcodegen"
    HAS_XCODEGEN=false
fi

echo ""
echo "Step 1: Setting up whisper.cpp"
echo "----------------------------------------"

# Clone whisper.cpp if not present
if [ ! -d "whisper.cpp" ]; then
    echo "Cloning whisper.cpp..."
    git clone https://github.com/ggml-org/whisper.cpp.git
else
    echo "whisper.cpp already exists, updating..."
    cd whisper.cpp && git pull && cd ..
fi

# Build whisper.cpp
echo "Building whisper.cpp..."
cd whisper.cpp
make clean
make -j$(sysctl -n hw.ncpu)

# Download model if not present
MODEL_PATH="models/ggml-tiny.en.bin"
if [ ! -f "$MODEL_PATH" ]; then
    echo "Downloading tiny.en model..."
    ./models/download-ggml-model.sh tiny.en
else
    echo "Model already downloaded"
fi

cd ..

echo ""
echo "✓ whisper.cpp built successfully"
echo "✓ Model downloaded: whisper.cpp/$MODEL_PATH"

echo ""
echo "Step 2: Setting up model in app directory"
echo "----------------------------------------"

# Create Application Support directory
APP_SUPPORT_DIR="$HOME/Library/Application Support/Speakez/Models"
mkdir -p "$APP_SUPPORT_DIR"

# Copy model
if [ -f "whisper.cpp/$MODEL_PATH" ]; then
    cp "whisper.cpp/$MODEL_PATH" "$APP_SUPPORT_DIR/"
    echo "✓ Model copied to: $APP_SUPPORT_DIR"
fi

echo ""
echo "Step 3: Generating Xcode project"
echo "----------------------------------------"

if [ "$HAS_XCODEGEN" = true ]; then
    echo "Generating Xcode project with XcodeGen..."
    xcodegen generate
    echo "✓ Speakez.xcodeproj generated"
else
    echo "Skipping Xcode project generation (XcodeGen not installed)"
    echo ""
    echo "To generate the project manually:"
    echo "1. Install XcodeGen: brew install xcodegen"
    echo "2. Run: xcodegen generate"
    echo ""
    echo "Or create the project manually in Xcode:"
    echo "1. File > New > Project > macOS > App"
    echo "2. Copy all Swift files from Speakez/ folder"
    echo "3. Configure as described in README.md"
fi

echo ""
echo "Step 4: Integrating whisper.cpp"
echo "----------------------------------------"
echo ""
echo "To integrate whisper.cpp with your Xcode project:"
echo ""
echo "Option A: Build XCFramework (recommended)"
echo "  cd whisper.cpp"
echo "  make xcframework"
echo "  # Then drag build/whisper.xcframework into Xcode"
echo ""
echo "Option B: Link static library directly"
echo "  1. In Xcode, go to Build Phases > Link Binary With Libraries"
echo "  2. Add whisper.cpp/libwhisper.a"
echo "  3. Add whisper.cpp/include to Header Search Paths"
echo ""

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Open Speakez.xcodeproj in Xcode"
echo "2. Add whisper.xcframework or libwhisper.a"
echo "3. Build and run the app"
echo "4. Grant Microphone and Accessibility permissions"
echo ""
echo "For detailed instructions, see README.md"
