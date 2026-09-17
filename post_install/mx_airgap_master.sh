#!/bin/bash
# MX Linux Advanced Airgap & Post-Install Master Script
# Target: systemd init system

set -e
LOG_FILE="/var/log/mx_airgap_master.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== MX Linux Airgap & Post-Install Script Started ==="

# --- 1. PRIVILEGE & SYSTEMD CHECK ---
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run this script as root (using sudo)."
  exit 1
fi

if ! pidof systemd &>/dev/null && [ "$(cat /proc/1/comm 2>/dev/null)" != "systemd" ]; then
    echo "[ERROR] systemd is NOT the active init system. This script requires systemd." #[cite: 1]
    exit 1
fi
echo "[OK] systemd detected — proceeding." #[cite: 1]

# Set the target user for group additions and desktop shortcuts
TARGET_USER=${SUDO_USER:-root}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
export DEBIAN_FRONTEND=noninteractive

# --- 2. PREREQUISITE INSTALLATION ---
echo "Installing prerequisites (zenity, ufw, curl, wget, virtiofsd)..."
apt-get update -y || true
apt-get install -y zenity ufw curl wget virtiofsd

if ! command -v zenity >/dev/null 2>&1; then
    echo "Fatal Error: Failed to install zenity."
    exit 1
fi

# --- 3. MAIN AUTOMATED INSTALLATION BLOCK ---
(
echo "5"; echo "# Configuring UFW Firewall for Airgap Deployment..."
ufw --force reset
ufw default deny incoming
ufw default deny outgoing
ufw allow out 53/tcp
ufw allow out 53/udp
ufw allow out 80/tcp
ufw allow out 443/tcp
ufw --force enable

echo "15"; echo "# System Update & General Utilities..."
apt-get upgrade -y
apt-get install -y mtools git unzip zip qrencode htop neofetch tree rsync #[cite: 1]

echo "25"; echo "# Installing Security Tools (GnuPG & Timeshift)..."
apt-get install -y gnupg gnupg2 gpg-agent pinentry-qt kleopatra timeshift #[cite: 1]

echo "35"; echo "# Installing Media & Core Tools..."
apt-get install -y yt-dlp ffmpeg vlc spectacle keepassxc celluloid obs-studio #[cite: 1]

echo "45"; echo "# Installing Virtualization Stack..."
apt-get install -y qemu-kvm libvirt-clients libvirt-daemon-system virt-manager ovmf swtpm swtpm-tools bridge-utils virtinst #[cite: 1]
usermod -aG libvirt "$TARGET_USER" #[cite: 1]
usermod -aG kvm "$TARGET_USER" #[cite: 1]
systemctl enable libvirtd #[cite: 1]

echo "55"; echo "# Installing Python Stack & Libraries..."
apt-get install -y python3 python3-full python3-pip python3-venv build-essential libssl-dev zlib1g-dev libsqlite3-dev libffi-dev libbz2-dev libreadline-dev tk-dev libxml2-dev libxslt1-dev libjpeg-dev #[cite: 1]
apt-get install -y python3-cryptography python3-tk python3-psutil python3-pandas python3-numpy python3-openpyxl python3-flask python3-bcrypt python3-requests python3-yaml python3-lxml python3-sqlalchemy python3-pil python3-paramiko python3-dotenv #[cite: 1]

echo "70"; echo "# Installing Node.js LTS & Docker..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - #[cite: 1]
apt-get install -y nodejs #[cite: 1]
apt-get install -y docker.io docker-compose-plugin containerd # Adaptive docker repo integration
usermod -aG docker "$TARGET_USER" #[cite: 1]
systemctl enable docker containerd #[cite: 1]

echo "85"; echo "# Downloading VeraCrypt & LocalSend..."
wget -qO /tmp/veracrypt.deb https://launchpad.net/veracrypt/trunk/1.26.7/+download/veracrypt-1.26.7-Debian-12-amd64.deb
wget -qO /tmp/localsend.deb https://github.com/localsend/localsend/releases/latest/download/LocalSend-linux-x86-64.deb

echo "90"; echo "# Installing Standalone Packages..."
dpkg -i /tmp/veracrypt.deb || apt-get install -f -y
dpkg -i /tmp/localsend.deb || apt-get install -f -y

echo "95"; echo "# Performing Final Cleanup..."
rm -f /tmp/veracrypt.deb /tmp/localsend.deb
apt-get autoremove -y
apt-get clean

echo "100"; echo "# Applications successfully installed!"
) | zenity --progress --title="Airgap Configuration Tool" --text="Initializing Setup..." --percentage=0 --width=500 --auto-close

if [ $? -ne 0 ]; then
    zenity --error --title="Installation Failed" --text="An error occurred. Check $LOG_FILE for details."
    exit 1
fi

# --- 4. GENERATE SYSTEMD NETWORK TOGGLE UTILITY ---
TOGGLE_SCRIPT="$TARGET_HOME/Desktop/toggle_network.sh"
mkdir -p "$TARGET_HOME/Desktop"

cat << 'EOF' > "$TOGGLE_SCRIPT"
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  zenity --error --title="Permission Denied" --text="Please run this script as root."
  exit 1
fi
if systemctl is-active --quiet NetworkManager; then
    systemctl stop NetworkManager
    systemctl disable NetworkManager
    ufw default deny outgoing
    zenity --info --title="Airgap Enabled" --text="NetworkManager disabled via systemd.\nOutgoing firewall traffic blocked."
else
    systemctl enable NetworkManager
    systemctl start NetworkManager
    ufw allow out 53/tcp; ufw allow out 53/udp; ufw allow out 80/tcp; ufw allow out 443/tcp
    zenity --info --title="Network Enabled" --text="NetworkManager enabled via systemd.\nUpdate ports opened."
fi
EOF
chmod +x "$TOGGLE_SCRIPT"
chown "$TARGET_USER:$TARGET_USER" "$TOGGLE_SCRIPT"

# --- 5. FINAL AIRGAP PROMPT ---
if zenity --question --title="Enable Airgap Mode" --text="Installation complete!\n\nWould you like to disable the network interfaces using systemd now to enter Airgap mode?" --width=450; then
    systemctl stop NetworkManager
    systemctl disable NetworkManager
    ufw default deny outgoing
    zenity --info --title="Airgap Active" --text="Network services disabled. You must log out and back in for virtualization and Docker group changes to take effect."
else
    zenity --info --title="Setup Complete" --text="Network active. Remember to log out and back in for group changes to take effect."
fi