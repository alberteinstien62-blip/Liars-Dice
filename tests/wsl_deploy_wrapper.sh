#!/bin/bash
set -e

# Convert Windows CWD (tests dir) to WSL path for the project root
# We are in .../liars-dice/tests
# Parent is project root
CURRENT_DIR=$(pwd)
PROJECT_ROOT_WIN="$(dirname "$CURRENT_DIR")"

# If running via wsl from Windows path, pwd might be /mnt/c/...
# If we are in /mnt/c/.../liars-dice/tests
if [[ "$PWD" == /mnt/c* ]] || [[ "$PWD" == /mnt/d* ]]; then
    PROJECT_ROOT_WIN="$(cd .. && pwd)"
else
    # Try to detect from script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT_WIN="$(dirname "$SCRIPT_DIR")"
fi

# Verify the path exists
if [ ! -d "$PROJECT_ROOT_WIN" ]; then
    echo "ERROR: Could not detect project root. Please run from the tests directory."
    exit 1
fi

DEST="$HOME/liars-dice-deploy"

echo "=== WSL Deployment Wrapper ==="
echo "Source: $PROJECT_ROOT_WIN"
echo "Destination: $DEST"

# Clean destination
rm -rf "$DEST"
mkdir -p "$DEST"

echo "Copying source files (using rsync)..."
# Check if rsync exists
if ! command -v rsync &> /dev/null; then
    echo "rsync not found, using cp..."
    mkdir -p "$DEST"
    cp -r "$PROJECT_ROOT_WIN/"* "$DEST/"
    # Remove target to avoid issues
    rm -rf "$DEST/target"
else
    rsync -a --exclude 'target' --exclude '.git' "$PROJECT_ROOT_WIN/" "$DEST/"
fi

cd "$DEST"
echo "Files copied."

echo "Building contracts in WSL..."
source ~/.cargo/env 2>/dev/null || true
export PATH="$HOME/.cargo/bin:$PATH"

# Ensure target is added
rustup target add wasm32-unknown-unknown 2>/dev/null || true

cargo build --release --target wasm32-unknown-unknown

echo "Build complete. Running deployment..."
cd tests
chmod +x conway_deploy.sh
./conway_deploy.sh "$1" "$2"

echo "Copying config files back to Windows source..."
cp ../frontend/web_a/config_conway.json "$PROJECT_ROOT_WIN/frontend/web_a/" 2>/dev/null || echo "Warning: config_conway.json (web_a) not found"
cp ../frontend/web_b/config_conway.json "$PROJECT_ROOT_WIN/frontend/web_b/" 2>/dev/null || echo "Warning: config_conway.json (web_b) not found"

echo "=== Wrapper Complete ==="
