#!/bin/bash
# ================================================================
# PORTABLE UNCENSORED AI - MX LINUX LAUNCHER
# ================================================================
# Run this script from your EXT4 data partition.
# Everything runs from the partition. Nothing is installed on the host.
# ================================================================

# Auto-detect location — works regardless of mount point
cd "$(dirname "$0")"

USB_DIR=$(pwd)
ANYTHINGLLM_DIR="$USB_DIR/anythingllm_linux"
STORAGE_DIR="$USB_DIR/anythingllm_data"
MODEL_NAME="dolphin-llama3"

echo "==================================================="
echo "    Launching Portable AI Engine for Linux...      "
echo "==================================================="

# -----------------------------------------------------------------
# PRE-FLIGHT: Check for required system tools
# -----------------------------------------------------------------
if ! command -v curl &>/dev/null; then
    echo ""
    echo "ERROR: 'curl' is required but not installed."
    echo "Install it with:  sudo apt install curl"
    echo ""
    exit 1
fi

# -----------------------------------------------------------------
# PRE-FLIGHT: Fix USB partition permissions if needed
# (EXT4 partition created as root — normal user can't write to it)
# -----------------------------------------------------------------
if [ "$(id -u)" != "0" ] && [ ! -w "$USB_DIR" ]; then
    echo ""
    echo "Fixing USB partition permissions (enter sudo password if prompted)..."
    sudo chown -R "$(id -un):$(id -gn)" "$USB_DIR" || {
        echo ""
        echo "ERROR: Could not fix permissions. Run this once manually then retry:"
        echo "  sudo chown -R $USER:$USER $USB_DIR"
        echo ""
        exit 1
    }
    echo "Permissions fixed."
    echo ""
fi

# -----------------------------------------------------------------
# PRE-FLIGHT: Fix X11 display access when running as root
# 'sudo bash' strips DISPLAY and XAUTHORITY — restore them so the
# GUI window can appear. Recommend using 'sudo -E bash' instead.
# -----------------------------------------------------------------
if [ "$(id -u)" = "0" ]; then
    ROOT_FLAG="--no-sandbox"
    [ -z "$DISPLAY" ] && export DISPLAY=:0
    # Allow root to connect to the X display
    xhost +local: 2>/dev/null
    # Restore XAUTHORITY from the logged-in user if missing
    if [ -z "$XAUTHORITY" ]; then
        XAUTH_USER=$(who | awk 'NR==1{print $1}')
        XAUTH_FILE="/home/$XAUTH_USER/.Xauthority"
        [ -f "$XAUTH_FILE" ] && export XAUTHORITY="$XAUTH_FILE"
    fi
else
    ROOT_FLAG=""
fi

# -----------------------------------------------------------------
# STEP 1: Download AnythingLLM AppImage (first time only)
# AnythingLLM Desktop bundles its own Ollama — no separate download needed.
# -----------------------------------------------------------------
if [ ! -f "$ANYTHINGLLM_DIR/AnythingLLM.AppImage" ]; then
    echo ""
    echo "First time setup: Downloading AnythingLLM to partition..."
    echo "Requires internet — only needed once. Fully offline after this."
    mkdir -p "$ANYTHINGLLM_DIR"
    curl -L --fail --progress-bar \
        "https://cdn.anythingllm.com/latest/AnythingLLMDesktop.AppImage" \
        -o "$ANYTHINGLLM_DIR/AnythingLLM.AppImage" || {
        echo ""
        echo "ERROR: Download failed. Check your internet connection and try again."
        rm -f "$ANYTHINGLLM_DIR/AnythingLLM.AppImage"
        exit 1
    }
    chmod +x "$ANYTHINGLLM_DIR/AnythingLLM.AppImage"
    echo "AnythingLLM downloaded and ready!"
    echo ""
fi

# -----------------------------------------------------------------
# STEP 2: Prepare storage on partition
# -----------------------------------------------------------------
chmod +x "$ANYTHINGLLM_DIR/AnythingLLM.AppImage"
mkdir -p "$STORAGE_DIR"

echo ""
echo "Starting AI Engine..."

# -----------------------------------------------------------------
# STEP 3: Launch AnythingLLM
# EXT4 supports full file locking — --user-data-dir points directly
# to the partition. All data (config, models, conversations) stays here.
# -----------------------------------------------------------------
APPIMAGE="$ANYTHINGLLM_DIR/AnythingLLM.AppImage"

if [ -e /dev/fuse ] && (fusermount -V &>/dev/null 2>&1 || fusermount3 -V &>/dev/null 2>&1); then
    "$APPIMAGE" --user-data-dir="$STORAGE_DIR" $ROOT_FLAG &
else
    echo "Note: FUSE not detected — using extract-and-run mode..."
    "$APPIMAGE" --appimage-extract-and-run --user-data-dir="$STORAGE_DIR" $ROOT_FLAG &
fi
ANYTHINGLLM_PID=$!

# -----------------------------------------------------------------
# STEP 4: Pull dolphin-llama3 on first run
# Waits for bundled Ollama to start on port 11434, then pulls model.
# -----------------------------------------------------------------
MODEL_MANIFEST="$STORAGE_DIR/storage/ollama/models/manifests/registry.ollama.ai/library/dolphin-llama3"
if [ ! -d "$MODEL_MANIFEST" ]; then
    echo ""
    echo "Waiting for AI engine to be ready..."
    RETRIES=30
    until curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
        sleep 2
        RETRIES=$((RETRIES - 1))
        if [ $RETRIES -eq 0 ]; then
            echo "WARNING: Could not reach Ollama after 60s."
            echo "Download the model manually inside AnythingLLM once it opens."
            break
        fi
    done

    if [ $RETRIES -gt 0 ]; then
        echo "Downloading AI model ($MODEL_NAME ~5.7GB to partition)..."
        echo "AnythingLLM is open — wait for this to finish before chatting."
        echo ""
        curl -s -X POST http://localhost:11434/api/pull \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$MODEL_NAME\",\"stream\":true}" \
            --no-buffer | while IFS= read -r line; do
                STATUS=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                [ -n "$STATUS" ] && echo "  $STATUS"
            done
        echo ""
        echo "Model ready!"
    fi
fi

echo ""
echo "==================================================="
echo "  SYSTEM ONLINE: Your AI is running from the USB!  "
echo "==================================================="
echo ""
echo "Keep this terminal open while you chat!"
echo "Press [ENTER] to shut down the AI safely."
echo ""

read -p "Hit [ENTER] to turn off the Engine..."
kill "$ANYTHINGLLM_PID" 2>/dev/null
pkill -P "$ANYTHINGLLM_PID" 2>/dev/null
echo "AI shut down. You may safely eject the USB."
