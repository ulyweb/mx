#!/bin/bash

# MX Linux Post‑Install Script Installer
# This installer:
# - Creates ~/scripts if missing
# - Saves the main script into it
# - Sets correct permissions
# - Optionally adds a global command "mxsetup"
# - Runs the main script

set -e

TARGET_DIR="$HOME/scripts"
TARGET_SCRIPT="$TARGET_DIR/mx_post_install.sh"
GLOBAL_LINK="/usr/local/bin/mxsetup"

echo "=== MX Linux Post‑Install Installer ==="

# 1. Create scripts directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "[+] Creating $TARGET_DIR ..."
    mkdir -p "$TARGET_DIR"
else
    echo "[OK] $TARGET_DIR already exists."
fi

# 2. Write the main script into place
echo "[+] Installing main post‑install script..."
cat > "$TARGET_SCRIPT" << 'EOF'
#!/bin/bash
# MX Linux Advanced Post‑Install Automation Script
# Features:
# - Menu-based
# - Logging
# - Idempotent-ish behavior
# - Python + virtualization + extras

LOGFILE="$HOME/mx_post_install_$(date +%F_%H-%M-%S).log"

exec > >(tee -a "$LOGFILE") 2>&1

set -e  # Stop on error

echo "=== MX Linux Post‑Install Script Started ==="
echo "Logging to: $LOGFILE"
echo

# ---------------------------------------------------------
# Helper functions
# ---------------------------------------------------------

pause() {
    read -rp "Press Enter to continue..."
}

pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

ensure_pkg() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        echo "[OK] $pkg already installed."
    else
        echo "[+] Installing $pkg..."
        sudo apt install -y "$pkg"
    fi
}

ensure_group_membership() {
    local group="$1"
    if id -nG "$USER" | grep -qw "$group"; then
        echo "[OK] User $USER already in group $group."
    else
        echo "[+] Adding $USER to group $group..."
        sudo usermod -aG "$group" "$USER"
        echo "   You must log out and back in for this to take effect."
    fi
}

# ---------------------------------------------------------
# 1. System update
# ---------------------------------------------------------
system_update() {
    echo "=== System Update ==="
    sudo apt update && sudo apt upgrade -y
    echo "System update complete."
}

# ---------------------------------------------------------
# 2. Firewall + Samba
# ---------------------------------------------------------
configure_firewall_samba() {
    echo "=== Firewall + Samba Configuration ==="

    ensure_pkg ufw

    echo "[+] Allowing Samba and related ports..."
    sudo ufw allow Samba
    sudo ufw allow 137/udp
    sudo ufw allow 138/udp
    sudo ufw allow 139/tcp
    sudo ufw allow 445/tcp

    echo "[+] Reloading UFW..."
    sudo ufw reload

    echo "[+] UFW status:"
    sudo ufw status verbose

    echo "[+] Restarting Samba services..."
    sudo systemctl restart smbd nmbd || echo "Samba services not found or not enabled."
}

# ---------------------------------------------------------
# 3. Utilities
# ---------------------------------------------------------
install_utilities() {
    echo "=== Installing General Utilities ==="
    local pkgs=(
        mtools
        curl
        wget
        git
        unzip
        zip
        qrencode
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done
}

# ---------------------------------------------------------
# 4. Virtualization stack
# ---------------------------------------------------------
install_virtualization() {
    echo "=== Installing Virtualization Stack (QEMU/KVM, libvirt, virt-manager) ==="

    local pkgs=(
        qemu-kvm
        libvirt-clients
        libvirt-daemon-system
        virt-manager
        ovmf
        swtpm
        swtpm-tools
        virtiofsd
        bridge-utils
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done

    ensure_group_membership libvirt
}

# ---------------------------------------------------------
# 5. Python + build tools
# ---------------------------------------------------------
install_python_stack() {
    echo "=== Installing Python + Build Tools ==="

    local pkgs=(
        python3
        python3-full
        python3-pip
        python3-venv
        build-essential
        libssl-dev
        zlib1g-dev
        libsqlite3-dev
        libffi-dev
        libbz2-dev
        libreadline-dev
        libncursesw5-dev
        tk-dev
        libxml2-dev
        libxslt1-dev
        libjpeg-dev
        libfreetype6-dev
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done

    echo "[+] Python version:"
    python3 --version || true

    echo "[+] Pip version:"
    pip3 --version || true
}

# ---------------------------------------------------------
# 6. Python libraries
# ---------------------------------------------------------
install_python_libraries() {
    echo "=== Installing Python Libraries (APT) ==="

    local pkgs=(
        python3-cryptography
        python3-mnemonic
        python3-tk
        python3-psutil
        python3-pyinstaller
        python3-pandas
        python3-numpy
        python3-openpyxl
        python3-flask
        python3-bcrypt
        python3-requests
        python3-yaml
        python3-lxml
        python3-sqlalchemy
        python3-pil
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done
}

# ---------------------------------------------------------
# 7. Media tools
# ---------------------------------------------------------
install_media_tools() {
    echo "=== Installing Media Tools (yt-dlp, ffmpeg) ==="

    local pkgs=(
        yt-dlp
        ffmpeg
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done
}

# ---------------------------------------------------------
# 8. Docker + Docker Compose (optional)
# ---------------------------------------------------------
install_docker() {
    echo "=== Installing Docker + Docker Compose ==="

    sudo apt update
    sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        echo "[+] Adding Docker GPG key and repository..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    sudo apt update
    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    ensure_group_membership docker

    echo "[+] Docker version:"
    docker --version || true

    echo "[+] Docker Compose version:"
    docker compose version || true
}

# ---------------------------------------------------------
# 9. Zsh + Oh-My-Zsh (optional)
# ---------------------------------------------------------
install_zsh_ohmyzsh() {
    echo "=== Installing Zsh + Oh-My-Zsh ==="

    ensure_pkg zsh

    if [ "$SHELL" != "$(command -v zsh)" ]; then
        echo "[+] Changing default shell to zsh for $USER..."
        chsh -s "$(command -v zsh)"
        echo "   Log out and back in for shell change to take effect."
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "[+] Installing Oh-My-Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
}

# ---------------------------------------------------------
# 10. Run everything
# ---------------------------------------------------------
run_all() {
    system_update
    configure_firewall_samba
    install_utilities
    install_virtualization
    install_python_stack
    install_python_libraries
    install_media_tools
    echo
    echo "Core setup complete."
}

# ---------------------------------------------------------
# Menu
# ---------------------------------------------------------
show_menu() {
    clear
    echo "=== MX Linux Post‑Install Menu ==="
    echo "Log file: $LOGFILE"
    echo
    echo "1) Run EVERYTHING (core stack)"
    echo "2) System update"
    echo "3) Firewall + Samba"
    echo "4) Utilities"
    echo "5) Virtualization stack"
    echo "6) Python + build tools"
    echo "7) Python libraries"
    echo "8) Media tools (yt-dlp, ffmpeg)"
    echo "9) Install Docker + Docker Compose"
    echo "10) Install Zsh + Oh-My-Zsh"
    echo "0) Exit"
    echo
}

# ---------------------------------------------------------
# Main loop
# ---------------------------------------------------------
while true; do
    show_menu
    read -rp "Choose an option: " choice
    echo

    case "$choice" in
        1) run_all; pause ;;
        2) system_update; pause ;;
        3) configure_firewall_samba; pause ;;
        4) install_utilities; pause ;;
        5) install_virtualization; pause ;;
        6) install_python_stack; pause ;;
        7) install_python_libraries; pause ;;
        8) install_media_tools; pause ;;
        9) install_docker; pause ;;
        10) install_zsh_ohmyzsh; pause ;;
        0) echo "Exiting. Goodbye."; break ;;
        *) echo "Invalid choice."; pause ;;
    esac
done

echo "=== MX Linux Post‑Install Script Finished ==="
echo "Remember to log out and back in for group/shell changes to apply."
EOF

# 3. Set permissions
echo "[+] Setting executable permissions..."
chmod +x "$TARGET_SCRIPT"

# 4. Offer to add global command
echo
read -rp "Do you want to install a global command 'mxsetup'? (y/n): " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    echo "[+] Creating symlink at $GLOBAL_LINK ..."
    sudo ln -sf "$TARGET_SCRIPT" "$GLOBAL_LINK"
    echo "[OK] You can now run: mxsetup"
else
    echo "[i] Skipping global command installation."
fi

# 5. Run the main script
echo
echo "=== Running MX Post‑Install Script Now ==="
bash "$TARGET_SCRIPT"
