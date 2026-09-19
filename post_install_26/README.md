Here is the fully adapted, GUI-automated setup script tailored strictly for MX Linux's default `sysVinit` architecture. It handles the initial system update, securely configures the firewall, installs all requested software (including the virtualization fixes), and generates a `sysVinit`-compatible network toggle tool.

You can save this directly into your verbatim Designing Linux OS Airgap documentation.

```bash
#!/bin/bash
# MX Linux Airgap & Post-Install Master Script
# Target: sysVinit (MX Linux Default)

set -e
LOG_FILE="/var/log/mx_airgap_master.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- 1. PRIVILEGE & INIT CHECK ---
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run this script as root (using sudo)."
  exit 1
fi

if pidof systemd &>/dev/null || [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
    echo "[ERROR] systemd detected. This script is strictly designed for sysVinit."
    exit 1
fi
echo "[OK] sysVinit detected — proceeding."

TARGET_USER=${SUDO_USER:-root}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
export DEBIAN_FRONTEND=noninteractive

# --- 2. PREREQUISITE INSTALLATION ---
echo "Installing prerequisites (zenity, ufw, curl, wget, virtiofsd)..."
apt-get update -y || true
apt-get install -y zenity ufw curl wget virtiofsd

if ! command -v zenity >/dev/null 2>&1; then
    echo "Fatal Error: Failed to install zenity. Check network connection."
    exit 1
fi

# --- 3. MAIN AUTOMATED INSTALLATION BLOCK ---
(
echo "5"; echo "# Updating System and Base Packages..."
apt-get upgrade -y

echo "15"; echo "# Configuring UFW Firewall for Airgap Deployment..."
ufw --force reset
ufw default deny incoming
ufw default deny outgoing
ufw allow out 53/tcp
ufw allow out 53/udp
ufw allow out 80/tcp
ufw allow out 443/tcp
ufw --force enable

echo "30"; echo "# Installing Core Media & Utilities..."
apt-get install -y spectacle keepassxc celluloid python3 ffmpeg vlc obs-studio

echo "45"; echo "# Installing Virtualization Stack..."
apt-get install -y qemu-kvm libvirt-clients libvirt-daemon-system virt-manager ovmf swtpm swtpm-tools bridge-utils virtinst
usermod -aG libvirt "$TARGET_USER"
usermod -aG kvm "$TARGET_USER"
update-rc.d libvirtd enable
service libvirtd start

echo "60"; echo "# Downloading Third-Party Applications..."
wget -qO /tmp/veracrypt.deb https://launchpad.net/veracrypt/trunk/1.26.7/+download/veracrypt-1.26.7-Debian-12-amd64.deb
wget -qO /tmp/localsend.deb https://github.com/localsend/localsend/releases/latest/download/LocalSend-linux-x86-64.deb

echo "80"; echo "# Installing VeraCrypt & LocalSend..."
dpkg -i /tmp/veracrypt.deb || apt-get install -f -y
dpkg -i /tmp/localsend.deb || apt-get install -f -y

echo "95"; echo "# Performing Final Cleanup..."
rm -f /tmp/veracrypt.deb /tmp/localsend.deb
apt-get autoremove -y
apt-get clean

echo "100"; echo "# Applications successfully installed!"
) | zenity --progress --title="sysVinit Airgap Configuration Tool" --text="Initializing Setup..." --percentage=0 --width=500 --auto-close

if [ $? -ne 0 ]; then
    zenity --error --title="Installation Failed" --text="An error occurred. Check $LOG_FILE for details."
    exit 1
fi

# --- 4. GENERATE SYSVINIT NETWORK TOGGLE UTILITY ---
TOGGLE_SCRIPT="$TARGET_HOME/Desktop/toggle_network.sh"
mkdir -p "$TARGET_HOME/Desktop"

cat << 'EOF' > "$TOGGLE_SCRIPT"
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  zenity --error --title="Permission Denied" --text="Please run this script as root."
  exit 1
fi

# Toggle logic explicitly utilizing sysVinit controls
if service network-manager status | grep -q "is running"; then
    service network-manager stop
    update-rc.d network-manager disable
    ufw default deny outgoing
    zenity --info --title="Airgap Enabled" --text="Network-manager disabled via sysVinit.\nOutgoing firewall traffic blocked.\nSystem is strictly isolated."
else
    update-rc.d network-manager enable
    service network-manager start
    ufw allow out 53/tcp
    ufw allow out 53/udp
    ufw allow out 80/tcp
    ufw allow out 443/tcp
    zenity --info --title="Network Enabled" --text="Network-manager enabled via sysVinit.\nUpdate ports (53, 80, 443) opened."
fi
EOF
chmod +x "$TOGGLE_SCRIPT"
chown "$TARGET_USER:$TARGET_USER" "$TOGGLE_SCRIPT"

# --- 5. FINAL AIRGAP PROMPT ---
if zenity --question --title="Enable Airgap Mode" --text="Post-installation complete!\n\nWould you like to disable the network interfaces using sysVinit now to enter Airgap mode?\n\n(A 'toggle_network.sh' script has been created on your desktop to manage future updates.)" --width=450; then
    service network-manager stop
    update-rc.d network-manager disable
    ufw default deny outgoing
    zenity --info --title="Airgap Active" --text="Network services successfully disabled. You must log out and back in for virtualization group changes to take effect."
else
    zenity --info --title="Setup Complete" --text="Network remains active. Remember to log out and back in for group changes to take effect."
fi

```

1. **Create the Script:** 1 min.
Open a terminal on your fresh MX Linux installation, type `nano mx_sysvinit_airgap.sh`, paste the code above, and press `CTRL+O` then `ENTER` to save, and `CTRL+X` to exit.
*Verification:* The file `mx_sysvinit_airgap.sh` will exist in your current directory.


2. **Make the Script Executable:** 1 min.
Run `chmod +x mx_sysvinit_airgap.sh` to allow the system to run the file as a program.
*Verification:* Running `ls -l mx_sysvinit_airgap.sh` will show `x` permissions in the output (e.g., `-rwxr-xr-x`).


3. **Execute the Setup:** 15 mins.
Run `sudo ./mx_sysvinit_airgap.sh`.
*Verification:* The script will instantly configure the firewall and launch the GUI progress bar to handle the updates and software installations without further intervention.
