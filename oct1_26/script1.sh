#!/bin/bash
# MX Linux Advanced Post-Install Automation Script — SysVinit Edition
# Features:
# - Menu-based
# - Logging
# - Idempotent behavior
# - Python + Node.js + Virtualization + Security tools
# - Compatible with SysVinit init system (MX Linux default)

LOGFILE="$HOME/mx_post_install_$(date +%F_%H-%M-%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec > >(tee -a "$LOGFILE") 2>&1

# Removed set -e — individual functions handle errors gracefully

echo "=== MX Linux Post-Install Script (SysVinit) Started ==="
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
        sudo apt install -y "$pkg" || echo "[WARN] Failed to install $pkg — skipping."
    fi
}

ensure_group_membership() {
    local group="$1"
    if id -nG "$USER" | grep -qw "$group"; then
        echo "[OK] User $USER already in group $group."
    else
        echo "[+] Adding $USER to group $group..."
        sudo usermod -aG "$group" "$USER"
        echo "   NOTE: Log out and back in for this to take effect."
    fi
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "[ERROR] Do not run this script as root. Run as your normal user."
        exit 1
    fi
}

check_sysvinit() {
    local init_comm
    init_comm=$(cat /proc/1/comm 2>/dev/null)
    if [ "$init_comm" = "systemd" ] || pidof systemd &>/dev/null; then
        echo "============================================"
        echo "  [ERROR] systemd is the active init system."
        echo "  This script is for SysVinit."
        echo "  Use mx_post_install.sh for systemd instead."
        echo "============================================"
        exit 1
    fi
    echo "[OK] SysVinit detected — proceeding."
}

# Start a service and enable it on boot (SysVinit equivalent of systemctl enable --now)
start_service() {
    local svc="$1"
    echo "[+] Starting service: $svc"
    sudo service "$svc" start || echo "[WARN] Could not start $svc — may not be installed yet."
    echo "[+] Enabling $svc on boot..."
    sudo update-rc.d "$svc" defaults 2>/dev/null || echo "[WARN] Could not enable $svc on boot."
}

# ---------------------------------------------------------
# 1. System update
# ---------------------------------------------------------
system_update() {
    echo "=== System Update ==="
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
    echo "[OK] System update complete."
}

# ---------------------------------------------------------
# 2. Firewall + Samba
# ---------------------------------------------------------
configure_firewall_samba() {
    echo "=== Firewall + Samba Configuration ==="

    ensure_pkg ufw

    echo "[+] Configuring UFW rules..."
    sudo ufw allow Samba
    sudo ufw allow 137/udp
    sudo ufw allow 138/udp
    sudo ufw allow 139/tcp
    sudo ufw allow 445/tcp

    # ufw enable handles its own boot persistence on SysVinit
    sudo ufw enable
    sudo ufw reload

    echo "[+] UFW status:"
    sudo ufw status verbose

    if pkg_installed samba; then
        echo "[+] Starting and enabling Samba services..."
        start_service smbd
        start_service nmbd
    else
        echo "[INFO] Samba not installed — skipping."
    fi
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
        htop
        neofetch
        tree
        rsync
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

    # Check hardware virtualization support
    if ! grep -qE 'vmx|svm' /proc/cpuinfo; then
        echo "[WARN] Hardware virtualization (VT-x/AMD-V) not detected. VMs may not run."
    else
        echo "[OK] Hardware virtualization supported."
    fi

    local pkgs=(
        qemu-kvm
        libvirt-clients
        libvirt-daemon-system
        virt-manager
        ovmf
        swtpm
        swtpm-tools
        bridge-utils
        virtinst
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done

    ensure_group_membership libvirt
    ensure_group_membership kvm

    start_service libvirtd

    # libvirt-guests init script may not exist on all SysVinit setups
    if [ -f /etc/init.d/libvirt-guests ]; then
        start_service libvirt-guests
    else
        echo "[INFO] libvirt-guests init script not found — skipping (normal on SysVinit)."
    fi

    echo "[OK] Virtualization stack installed."
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

    echo "[OK] Python version: $(python3 --version 2>&1)"
    echo "[OK] Pip version: $(pip3 --version 2>&1)"
}

# ---------------------------------------------------------
# 6. Python libraries
# ---------------------------------------------------------
install_python_libraries() {
    echo "=== Installing Python Libraries ==="

    local pkgs=(
        python3-cryptography
        python3-tk
        python3-psutil
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
        python3-paramiko
        python3-dotenv
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done
}

# ---------------------------------------------------------
# 7. Node.js LTS (via NodeSource)
# ---------------------------------------------------------
install_nodejs() {
    echo "=== Installing Node.js LTS ==="

    if command -v node &>/dev/null; then
        echo "[OK] Node.js already installed: $(node --version)"
        echo "[OK] npm version: $(npm --version)"
        return
    fi

    echo "[+] Adding NodeSource LTS repository..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

    sudo apt install -y nodejs

    echo "[OK] Node.js version: $(node --version)"
    echo "[OK] npm version: $(npm --version)"

    echo "[+] Installing common global npm packages..."
    sudo npm install -g pm2 nodemon || echo "[WARN] Some npm globals failed — non-critical."

    # PM2 startup for SysVinit — auto-detects init system
    echo "[+] Configuring PM2 SysVinit startup..."
    pm2 startup 2>/dev/null | grep "sudo" | bash || \
        echo "[INFO] PM2 startup: run 'pm2 startup' manually after first use."
}

# ---------------------------------------------------------
# 8. KeePassXC
# ---------------------------------------------------------
install_keepassxc() {
    echo "=== Installing KeePassXC ==="

    if command -v keepassxc &>/dev/null; then
        echo "[OK] KeePassXC already installed."
        return
    fi

    sudo apt update
    ensure_pkg keepassxc

    if command -v keepassxc &>/dev/null; then
        echo "[OK] KeePassXC installed: $(keepassxc --version 2>&1 | head -1)"
    else
        echo "[WARN] KeePassXC not found in repos — trying Flatpak..."
        if command -v flatpak &>/dev/null; then
            flatpak install -y flathub org.keepassxc.KeePassXC || echo "[WARN] Flatpak install failed."
        else
            echo "[INFO] Install KeePassXC manually from: https://keepassxc.org/download/"
        fi
    fi
}

# ---------------------------------------------------------
# 9. VeraCrypt
# ---------------------------------------------------------
install_veracrypt() {
    echo "=== Installing VeraCrypt ==="

    if command -v veracrypt &>/dev/null; then
        echo "[OK] VeraCrypt already installed."
        return
    fi

    echo "[+] Fetching latest VeraCrypt release..."

    local TMP_DIR
    TMP_DIR=$(mktemp -d)

    # Get latest version tag from GitHub
    local VER
    VER=$(curl -s https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest \
        | grep '"tag_name"' \
        | sed -E 's/.*"VeraCrypt_([^"]+)".*/\1/')

    if [ -z "$VER" ]; then
        echo "[ERROR] Could not determine VeraCrypt version. Check internet connection."
        rm -rf "$TMP_DIR"
        return 1
    fi

    echo "[+] Latest version: $VER"

    # Detect Debian version for correct .deb
    local DEBIAN_VER
    DEBIAN_VER=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"' | cut -d. -f1)
    # MX Linux 23 is based on Debian 12
    [ -z "$DEBIAN_VER" ] && DEBIAN_VER="12"

    local DEB_FILE="veracrypt-${VER}-Debian-${DEBIAN_VER}-amd64.deb"
    local DOWNLOAD_URL="https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_${VER}/${DEB_FILE}"

    echo "[+] Downloading: $DEB_FILE"
    wget -q --show-progress -O "$TMP_DIR/$DEB_FILE" "$DOWNLOAD_URL"

    if [ ! -f "$TMP_DIR/$DEB_FILE" ]; then
        echo "[ERROR] Download failed. Try manually: https://www.veracrypt.fr/en/Downloads.html"
        rm -rf "$TMP_DIR"
        return 1
    fi

    echo "[+] Installing VeraCrypt..."
    sudo dpkg -i "$TMP_DIR/$DEB_FILE" || sudo apt -f install -y

    rm -rf "$TMP_DIR"

    if command -v veracrypt &>/dev/null; then
        echo "[OK] VeraCrypt installed successfully."
    else
        echo "[WARN] VeraCrypt install may need manual verification."
    fi
}

# ---------------------------------------------------------
# 10. GnuPG (GPG)
# ---------------------------------------------------------
install_gnupg() {
    echo "=== Installing GnuPG ==="

    local pkgs=(
        gnupg
        gnupg2
        gpg-agent
        pinentry-qt    # KDE Plasma PIN entry dialog
        kleopatra      # KDE GUI for GPG key management
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done

    echo "[OK] GPG version: $(gpg --version 2>&1 | head -1)"
    echo "[INFO] Use kleopatra (GUI) or gpg (terminal) to manage your keys."
}

# ---------------------------------------------------------
# 11. Timeshift (System Snapshots)
# ---------------------------------------------------------
install_timeshift() {
    echo "=== Installing Timeshift ==="

    if command -v timeshift &>/dev/null; then
        echo "[OK] Timeshift already installed."
        return
    fi

    sudo apt update
    ensure_pkg timeshift

    if command -v timeshift &>/dev/null; then
        echo "[OK] Timeshift installed."
        echo "[INFO] Run 'sudo timeshift-gtk' to configure snapshots before locking down your USB."
    else
        echo "[WARN] Timeshift not found in repos."
        echo "[INFO] Download manually from: https://github.com/linuxmint/timeshift/releases"
    fi
}

# ---------------------------------------------------------
# 12. Firmware Update (fwupd)
# ---------------------------------------------------------
update_firmware() {
    echo "=== Firmware Update (fwupd) ==="
    echo "[WARN] fwupd has limited support under SysVinit — daemon features may not work."
    echo "[INFO] Command-line firmware checks will still run."

    ensure_pkg fwupd

    # Try to start fwupd if an init script exists
    if [ -f /etc/init.d/fwupd ]; then
        start_service fwupd
    else
        echo "[INFO] No fwupd SysVinit init script found — starting manually..."
        sudo fwupd &>/dev/null || echo "[INFO] fwupd daemon not startable — CLI mode only."
    fi

    echo "[+] Refreshing firmware metadata..."
    sudo fwupdmgr refresh --force || echo "[WARN] Could not refresh firmware metadata."

    echo "[+] Checking for firmware updates..."
    sudo fwupdmgr get-updates 2>&1 || echo "[INFO] No firmware updates available or device not supported."

    read -rp "Apply firmware updates now? (y/N): " apply
    if [[ "$apply" =~ ^[Yy]$ ]]; then
        sudo fwupdmgr update || echo "[WARN] Firmware update encountered issues."
    else
        echo "[INFO] Skipped. Run 'sudo fwupdmgr update' manually when ready."
    fi
}

# ---------------------------------------------------------
# 13. Media tools
# ---------------------------------------------------------
install_media_tools() {
    echo "=== Installing Media Tools ==="

    local pkgs=(
        yt-dlp
        ffmpeg
        vlc
    )

    for p in "${pkgs[@]}"; do
        ensure_pkg "$p"
    done
}

# ---------------------------------------------------------
# 14. Browser extensions (calls install_extensions.py)
# ---------------------------------------------------------
install_browser_extensions() {
    echo "=== Installing Browser Extensions via Policy ==="

    local EXT_SCRIPT="$SCRIPT_DIR/install_extensions.py"

    if [ ! -f "$EXT_SCRIPT" ]; then
        echo "[ERROR] install_extensions.py not found at: $EXT_SCRIPT"
        echo "   Make sure both scripts are in the same directory."
        return 1
    fi

    if ! command -v python3 &>/dev/null; then
        echo "[ERROR] python3 not installed. Run option 6 first."
        return 1
    fi

    echo "[+] Running extension policy installer (requires sudo)..."
    sudo python3 "$EXT_SCRIPT"
}

# ---------------------------------------------------------
# 15. Docker + Docker Compose (optional)
# NOTE: Docker works under SysVinit but requires manual service management
# ---------------------------------------------------------
install_docker() {
    echo "=== Installing Docker + Docker Compose ==="
    echo "[INFO] Docker under SysVinit uses 'service docker start' — no socket activation."

    if command -v docker &>/dev/null; then
        echo "[OK] Docker already installed: $(docker --version)"
        return
    fi

    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release

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

    # Start and enable via SysVinit
    start_service containerd
    start_service docker

    echo "[OK] Docker version: $(docker --version)"
    echo "[OK] Docker Compose version: $(docker compose version)"
    echo "[INFO] To start Docker after reboot: sudo service docker start"
}

# ---------------------------------------------------------
# 16. Zsh + Oh-My-Zsh (optional)
# ---------------------------------------------------------
install_zsh_ohmyzsh() {
    echo "=== Installing Zsh + Oh-My-Zsh ==="

    ensure_pkg zsh

    if [ "$SHELL" != "$(command -v zsh)" ]; then
        echo "[+] Changing default shell to zsh for $USER..."
        chsh -s "$(command -v zsh)"
        echo "   Log out and back in for shell change to take effect."
    else
        echo "[OK] zsh is already the default shell."
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "[+] Installing Oh-My-Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "[OK] Oh-My-Zsh already installed."
    fi
}

# ---------------------------------------------------------
# Run all (core stack — everything except Docker/Zsh)
# ---------------------------------------------------------
run_all() {
    echo "=== Running Full Core Setup (SysVinit) ==="
    system_update
    configure_firewall_samba
    install_utilities
    install_virtualization
    install_python_stack
    install_python_libraries
    install_nodejs
    install_keepassxc
    install_veracrypt
    install_gnupg
    install_timeshift
    install_media_tools
    install_browser_extensions
    echo
    echo "=== Core setup complete ==="
    echo "NOTE: Log out and back in for group changes (libvirt, kvm) to take effect."
    echo "TIP:  Run option 13 (Firmware Update) separately before locking down your USB."
}

# ---------------------------------------------------------
# Menu
# ---------------------------------------------------------
show_menu() {
    clear
    echo "============================================"
    echo "   MX Linux Post-Install Menu [SysVinit]"
    echo "   Log: $LOGFILE"
    echo "============================================"
    echo
    echo "  1)  Run EVERYTHING (full core stack)"
    echo
    echo "  --- System ---"
    echo "  2)  System update"
    echo "  3)  Firewall + Samba"
    echo "  4)  Utilities (curl, git, wget, etc.)"
    echo
    echo "  --- Dev Tools ---"
    echo "  5)  Virtualization (QEMU/KVM, virt-manager)"
    echo "  6)  Python + build tools"
    echo "  7)  Python libraries"
    echo "  8)  Node.js LTS"
    echo
    echo "  --- Security Tools ---"
    echo "  9)  KeePassXC"
    echo "  10) VeraCrypt"
    echo "  11) GnuPG + Kleopatra"
    echo "  12) Timeshift (system snapshots)"
    echo "  13) Firmware update (fwupd — limited on SysVinit)"
    echo "  14) Browser extensions (uBlock + Ghostery)"
    echo
    echo "  --- Optional ---"
    echo "  15) Media tools (yt-dlp, ffmpeg, vlc)"
    echo "  16) Docker + Docker Compose"
    echo "  17) Zsh + Oh-My-Zsh"
    echo
    echo "  0)  Exit"
    echo
}

# ---------------------------------------------------------
# Main
# ---------------------------------------------------------
check_root
check_sysvinit

while true; do
    show_menu
    read -rp "Choose an option: " choice
    echo

    case "$choice" in
        1)  run_all; pause ;;
        2)  system_update; pause ;;
        3)  configure_firewall_samba; pause ;;
        4)  install_utilities; pause ;;
        5)  install_virtualization; pause ;;
        6)  install_python_stack; pause ;;
        7)  install_python_libraries; pause ;;
        8)  install_nodejs; pause ;;
        9)  install_keepassxc; pause ;;
        10) install_veracrypt; pause ;;
        11) install_gnupg; pause ;;
        12) install_timeshift; pause ;;
        13) update_firmware; pause ;;
        14) install_browser_extensions; pause ;;
        15) install_media_tools; pause ;;
        16) install_docker; pause ;;
        17) install_zsh_ohmyzsh; pause ;;
        0)  echo "Exiting. Goodbye."; break ;;
        *)  echo "Invalid choice."; pause ;;
    esac
done

echo "=== MX Linux Post-Install Script (SysVinit) Finished ==="
echo "Remember to log out and back in for group/shell changes to apply."
