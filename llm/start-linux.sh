#!/bin/bash
# ================================================================
# PORTABLE UNCENSORED AI - MX LINUX LAUNCHER
# ================================================================
# Just run this script from your USB drive on any MX Linux machine.
# Everything runs from the USB drive. Nothing is installed on the host.
# ================================================================

# Move to the USB drive directory where this script lives
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
# STEP 1: Download AnythingLLM AppImage (first time only)
# NOTE: AnythingLLM Desktop already bundles its own Ollama engine.
#       No separate Ollama download needed.
# -----------------------------------------------------------------
if [ ! -f "$ANYTHINGLLM_DIR/AnythingLLM.AppImage" ]; then
    echo ""
    echo "First time setup: Downloading AnythingLLM directly to USB..."
    echo "NO installation on the host machine! Everything stays on the drive."
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
# STEP 2: Prepare storage directories on USB
# -----------------------------------------------------------------
# Re-apply execute bit every launch (exFAT may not persist it)
chmod +x "$ANYTHINGLLM_DIR/AnythingLLM.AppImage"

mkdir -p "$STORAGE_DIR"
mkdir -p "$STORAGE_DIR/ollama_models"

echo ""
echo "Starting AI Engine from USB..."

# -----------------------------------------------------------------
# STEP 3: Launch AnythingLLM with ALL data redirected to USB
#
# Three layers to ensure nothing touches the host:
#   --user-data-dir  → overrides Electron's userData path (app config, DB)
#   STORAGE_DIR      → AnythingLLM's server storage (documents, vectors)
#   OLLAMA_MODELS    → where the bundled Ollama stores AI model files
# -----------------------------------------------------------------
export STORAGE_DIR="$STORAGE_DIR"
export OLLAMA_MODELS="$STORAGE_DIR/ollama_models"

# Electron's process lock (SingletonLock) uses flock() which exFAT doesn't support.
# So we put Electron's internal session files in /tmp — these are throwaway process
# files (lock, GPU cache, Chromium internals), NOT your conversations or AI data.
# All actual data (conversations, models, documents) still goes to USB via STORAGE_DIR
# and OLLAMA_MODELS above.
ELECTRON_TMP="/tmp/anythingllm_portable"
mkdir -p "$ELECTRON_TMP"
USERDATA_ARG="--user-data-dir=$ELECTRON_TMP"

APPIMAGE="$ANYTHINGLLM_DIR/AnythingLLM.AppImage"

if [ -e /dev/fuse ] && (fusermount -V &>/dev/null 2>&1 || fusermount3 -V &>/dev/null 2>&1); then
    "$APPIMAGE" "$USERDATA_ARG" &
else
    echo "Note: FUSE not detected — using extract-and-run mode (first launch may be slower)..."
    "$APPIMAGE" --appimage-extract-and-run "$USERDATA_ARG" &
fi
ANYTHINGLLM_PID=$!

# -----------------------------------------------------------------
# STEP 4: Pull dolphin-llama3 on first run
# Wait for AnythingLLM's bundled Ollama to come online (port 11434),
# then pull the model via its REST API so it downloads to the USB.
# -----------------------------------------------------------------
MODEL_MANIFEST="$STORAGE_DIR/ollama_models/manifests/registry.ollama.ai/library/dolphin-llama3"
if [ ! -d "$MODEL_MANIFEST" ]; then
    echo ""
    echo "Waiting for AI engine to be ready..."
    RETRIES=30
    until curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
        sleep 2
        RETRIES=$((RETRIES - 1))
        if [ $RETRIES -eq 0 ]; then
            echo "WARNING: Could not reach Ollama engine after 60s."
            echo "You can download the model manually inside AnythingLLM."
            break
        fi
    done

    if [ $RETRIES -gt 0 ]; then
        echo "Downloading AI model ($MODEL_NAME ~5.7GB to USB)..."
        echo "AnythingLLM is open — this downloads in the background."
        echo ""
        curl -s -X POST http://localhost:11434/api/pull \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$MODEL_NAME\",\"stream\":true}" \
            --no-buffer | while IFS= read -r line; do
                STATUS=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                [ -n "$STATUS" ] && echo "  $STATUS"
            done
        echo ""
        echo "Model ready on USB!"
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

# Wait for user, then clean shutdown
read -p "Hit [ENTER] to turn off the Engine..."
kill "$ANYTHINGLLM_PID" 2>/dev/null
pkill -P "$ANYTHINGLLM_PID" 2>/dev/null
echo "AI shut down. You may safely eject the USB."
