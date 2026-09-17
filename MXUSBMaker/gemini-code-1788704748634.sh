cat << 'EOF' > ~/.local/bin/install-app-gui.sh
#!/usr/bin/env bash
set -e

# GUI wrappers (supports kdialog and zenity)
choose_file() {
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "Select App Archive (.tar.gz, .zip)" --getopenfilename "$HOME/Downloads" "*.tar.gz *.tgz *.zip|Archive Files"
    else
        zenity --file-selection --title="Select App Archive (.tar.gz, .zip)" --filename="$HOME/Downloads/"
    fi
}

ask_input() {
    local prompt="$1" default="$2"
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "App Installer" --inputbox "$prompt" "$default"
    else
        zenity --entry --title="App Installer" --text="$prompt" --entry-text="$default"
    fi
}

notify() {
    local msg="$1"
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "App Installer" --msgbox "$msg"
    else
        zenity --info --title="App Installer" --text="$msg"
    fi
}

notify_error() {
    local msg="$1"
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "App Installer" --error "$msg"
    else
        zenity --error --title="App Installer" --text="$msg"
    fi
}

# 1. Prompt user for archive file
ARCHIVE=$(choose_file)
[ -z "$ARCHIVE" ] && exit 0

FILENAME=$(basename "$ARCHIVE")
CLEAN_NAME=$(echo "$FILENAME" | sed -E 's/\.(tar\.gz|tgz|zip)$//I' | tr -cd '[:alnum:] ._-')

# 2. Ask user for App Display Name
APP_NAME=$(ask_input "Enter the Display Name for this Application:" "$CLEAN_NAME")
[ -z "$APP_NAME" ] && exit 0

SLUG=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
INSTALL_DIR="/opt/$SLUG"

# 3. Create temp workspace and extract
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$ARCHIVE" =~ \.(tar\.gz|tgz)$ ]]; then
    tar -xzf "$ARCHIVE" -C "$TMP_DIR"
elif [[ "$ARCHIVE" =~ \.zip$ ]]; then
    unzip -q "$ARCHIVE" -d "$TMP_DIR"
fi

# Handle nested single parent folder if archive wraps everything in one folder
ITEMS=("$TMP_DIR"/*)
if [ ${#ITEMS[@]} -eq 1 ] && [ -d "${ITEMS[0]}" ]; then
    SOURCE_DIR="${ITEMS[0]}"
else
    SOURCE_DIR="$TMP_DIR"
fi

# 4. Prompt for sudo/root permissions and deploy to /opt
pkexec bash -c "rm -rf '$INSTALL_DIR' && mkdir -p '$INSTALL_DIR' && cp -a '$SOURCE_DIR'/. '$INSTALL_DIR/'"

# 5. Locate binary and icon
BIN_TARGET=$(find "$INSTALL_DIR" -maxdepth 2 -type f -executable ! -name "*.sh" ! -name "*.so*" | head -n 1)
if [ -z "$BIN_TARGET" ]; then
    BIN_TARGET=$(find "$INSTALL_DIR" -maxdepth 2 -type f -executable | head -n 1)
fi

ICON_TARGET=$(find "$INSTALL_DIR" -type f \( -name "*.png" -o -name "*.svg" \) | grep -iE 'icon|logo|app' | head -n 1)
[ -z "$ICON_TARGET" ] && ICON_TARGET="utilities-terminal"

# 6. Create symlink in /usr/local/bin
if [ -n "$BIN_TARGET" ]; then
    pkexec ln -sf "$BIN_TARGET" "/usr/local/bin/$SLUG"
fi

# 7. Create .desktop file
mkdir -p "$HOME/.local/share/applications"
cat <<DESKTOP > "$HOME/.local/share/applications/$SLUG.desktop"
[Desktop Entry]
Name=$APP_NAME
Exec=$BIN_TARGET
Icon=$ICON_TARGET
Type=Application
Terminal=false
Categories=Utility;Development;
DESKTOP

notify "Successfully installed $APP_NAME!\n\nFolder: $INSTALL_DIR\nCommand: $SLUG\nLauncher added to Menu."
EOF

chmod +x ~/.local/bin/install-app-gui.sh