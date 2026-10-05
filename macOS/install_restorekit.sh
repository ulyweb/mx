#!/bin/bash
# install_restorekit.sh - MX Linux (Debian-based, amd64)
# Installs the RestoreKit desktop app (.deb) and prints DFU steps.

VER="0.5.10"
DEB="RestoreKit_${VER}_amd64.deb"
URL="https://github.com/fcjr/restorekit/releases/download/v${VER}/${DEB}"
SHA256="ca57a35980adb3b586dcb316833be0fe6336cdcf14b867e20da10900d6b074b6"
DL="$HOME/Downloads"
mkdir -p "$DL"

[ "$(uname -m)" = "x86_64" ] || { echo "ERROR: this script is for x86_64/amd64 only"; exit 1; }

echo "Downloading $DEB ..."
curl -L -C - --retry 5 --retry-delay 5 -o "$DL/$DEB" "$URL" || { echo "ERROR: download failed"; exit 1; }

echo "Verifying checksum..."
GOT=$(sha256sum "$DL/$DEB" | awk '{print $1}')
if [ "$GOT" != "$SHA256" ]; then
  echo "ERROR: checksum mismatch"; echo "expected $SHA256"; echo "got      $GOT"; exit 1
fi
echo "Checksum OK."

echo "Installing (also installs the USB udev rule)..."
sudo apt-get update
sudo apt-get install -y "$DL/$DEB" || { echo "ERROR: install failed - send me the output"; exit 1; }
sudo udevadm control --reload-rules && sudo udevadm trigger

cat <<'EOF'

=== INSTALLED. NEXT: PUT THE MAC IN DFU MODE ===
1. Shut the MacBook Pro fully down and plug it into power.
2. Cable: USB-C DATA cable from the Mac's LEFT-side port NEXT TO MAGSAFE -> this PC.
3. Hold POWER + RIGHT Shift + LEFT Control + LEFT Option for ~10 seconds,
   then release the three keys but KEEP HOLDING POWER ~5 more seconds.
   The Mac screen stays black - that's normal.
4. Check it's detected:   lsusb | grep -i apple     (should say "DFU Mode")
   If not, retry the key timing; Apple Wiki has per-model guides:
   https://theapplewiki.com/wiki/DFU_Mode#Mac_with_Apple_Silicon

=== THEN RESTORE ===
Open "RestoreKit" from the application menu and follow the prompts.
It detects the Mac, downloads the firmware, and restores it.
(Unplug and replug the cable once if it reports a USB permission error.)
EOF
