#!/bin/bash
# prep_macos_usb.sh - MX Linux
# Downloads macOS Tahoe InstallAssistant.pkg from Apple and loads it onto an exFAT USB (label PKGUSB)
# for use with the Terminal script in macOS Recovery.

# ---- EDIT THIS to change version (URLs from mrmacintosh.com Tahoe database) ----
# 26.7.1 (25G241) latest Tahoe:
URL="https://swcdn.apple.com/content/downloads/51/17/142-28081-A_616Q67X32N/5atqz1miz61kmrim7fwkn7yi62xuzzcc0s/InstallAssistant.pkg"
# 26.6.2 (25G83):
# URL="https://swcdn.apple.com/content/downloads/37/33/140-93587-A_GRFFH93NOL/f944yaqo1cjhh2m0kxrl0zhcpg9yb9qphv/InstallAssistant.pkg"
# ---------------------------------------------------------------------------------

WORKDIR="$HOME/Downloads/macos_installer"
PKG="$WORKDIR/InstallAssistant.pkg"
LOG="$WORKDIR/prep_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$WORKDIR"
exec > >(tee -a "$LOG") 2>&1

set -u
echo "== macOS installer USB prep =="; date

# 1. Dependencies
need=""
command -v mkfs.exfat >/dev/null || need="$need exfatprogs"
command -v parted     >/dev/null || need="$need parted"
command -v curl       >/dev/null || need="$need curl"
if [ -n "$need" ]; then
  echo "Installing:$need"
  sudo apt-get update && sudo apt-get install -y $need || { echo "ERROR: package install failed"; exit 1; }
fi

# 2. Download (resumable)
free_kb=$(df --output=avail -k "$WORKDIR" | tail -1)
if [ "$free_kb" -lt 25000000 ]; then echo "ERROR: need ~25 GB free in $WORKDIR"; exit 1; fi
remote=$(curl -sIL "$URL" | awk 'tolower($1)=="content-length:"{gsub("\r","");v=$2} END{print v}')
echo "Remote size: ${remote:-unknown} bytes"
curl -L -C - --retry 5 --retry-delay 5 -o "$PKG" "$URL" || { echo "ERROR: download failed (re-run to resume)"; exit 1; }
local_size=$(stat -c%s "$PKG")
echo "Local size:  $local_size bytes"
if [ -n "${remote:-}" ] && [ "$remote" != "$local_size" ]; then echo "ERROR: size mismatch - re-run to resume/redownload"; exit 1; fi
echo "Download OK."

# 3. Pick the USB
echo; echo "Removable disks:"
lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | awk 'NR==1 || $NF==1'
echo
read -r -p "Enter USB device (e.g. /dev/sdb): " DEV
[ -b "$DEV" ] || { echo "ERROR: $DEV is not a block device"; exit 1; }
case "$DEV" in *[0-9]) echo "ERROR: give the whole disk (e.g. /dev/sdb), not a partition"; exit 1;; esac
[ "$(lsblk -dno RM "$DEV")" = "1" ] || { echo "ERROR: $DEV is not removable - refusing"; exit 1; }
size_b=$(lsblk -bdno SIZE "$DEV")
[ "$size_b" -ge 28000000000 ] || { echo "ERROR: USB too small (need 32 GB+)"; exit 1; }
echo; lsblk "$DEV"
read -r -p "ALL DATA on $DEV will be ERASED. Type the device path again to confirm: " CONFIRM
[ "$CONFIRM" = "$DEV" ] || { echo "Aborted."; exit 1; }

# 4. Partition + format exFAT
for p in $(lsblk -lnpo NAME "$DEV" | tail -n +2); do sudo umount "$p" 2>/dev/null; done
sudo wipefs -a "$DEV"
sudo parted -s "$DEV" mklabel gpt mkpart PKGUSB 1MiB 100%
sudo partprobe "$DEV"; sleep 2
PART=$(lsblk -lnpo NAME "$DEV" | sed -n '2p')
sudo mkfs.exfat -L PKGUSB "$PART" || { echo "ERROR: mkfs.exfat failed"; exit 1; }

# 5. Copy
MNT=$(mktemp -d)
sudo mount -t exfat "$PART" "$MNT" || { echo "ERROR: mount failed"; exit 1; }
echo "Copying package to USB (several minutes)..."
sudo cp --no-preserve=mode,ownership "$PKG" "$MNT/InstallAssistant.pkg" || { echo "ERROR: copy failed"; sudo umount "$MNT"; exit 1; }
sync
if cmp -s "$PKG" "$MNT/InstallAssistant.pkg"; then echo "Verify: USB copy matches download."; else echo "ERROR: USB copy mismatch"; sudo umount "$MNT"; exit 1; fi
sudo umount "$MNT"; rmdir "$MNT"
sync

echo
echo "DONE. USB '$DEV' (label PKGUSB) is ready. Safe to unplug."
echo "Next: boot the Mac into Recovery, erase internal drive as 'Macintosh HD', run the Terminal script."
echo "Log: $LOG"
