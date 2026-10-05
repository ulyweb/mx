#!/bin/bash
# Recovery-mode macOS installer builder (mounts USB itself; exFAT w/ Linux GUID safe)
USBDISK="disk6"        # whole USB disk (from your diskutil list)
USBPART="disk6s1"      # USB partition holding InstallAssistant.pkg
INTVOL="disk3s1"       # internal 'Macintosh HD' volume (scratch space)

# --- Mount internal scratch volume ---
diskutil mount "$INTVOL" >/dev/null 2>&1
SCRATCHROOT=$(diskutil info "$INTVOL" | awk -F': *' '/Mount Point/{print $2}')
[ -n "$SCRATCHROOT" ] || SCRATCHROOT="/Volumes/Macintosh HD"
[ -d "$SCRATCHROOT" ] || { echo "ERROR: internal volume not mounted"; diskutil list; exit 1; }
SCRATCH="$SCRATCHROOT/tmp"

# --- Mount USB (diskutil first, manual exFAT fallback) ---
diskutil mount "$USBPART" >/dev/null 2>&1
SRC=$(diskutil info "$USBPART" | awk -F': *' '/Mount Point/{print $2}')
if [ -z "$SRC" ] || [ ! -f "$SRC/InstallAssistant.pkg" ]; then
  echo "diskutil mount didn't expose the pkg; mounting exFAT manually..."
  mkdir -p /tmp/pkgusb
  mount_exfat -o rdonly "/dev/$USBPART" /tmp/pkgusb || { echo "ERROR: cannot mount $USBPART"; diskutil info "$USBPART"; exit 1; }
  SRC="/tmp/pkgusb"
fi
[ -f "$SRC/InstallAssistant.pkg" ] || { echo "ERROR: InstallAssistant.pkg not found in $SRC"; ls "$SRC"; exit 1; }
echo "USB source: $SRC"
echo "Scratch:    $SCRATCH"

# --- Expand package ---
mkdir -p "$SCRATCH" || { echo "ERROR: cannot write scratch"; exit 1; }
rm -rf "$SCRATCH/expanded"
echo "Expanding package (several minutes, no output until done)..."
pkgutil --expand-full "$SRC/InstallAssistant.pkg" "$SCRATCH/expanded" || { echo "ERROR: pkgutil failed"; exit 1; }

APP=$(find "$SCRATCH/expanded" -maxdepth 4 -type d -name "Install macOS*.app" | head -1)
[ -n "$APP" ] || { echo "ERROR: Install app not found"; find "$SCRATCH/expanded" -maxdepth 3; exit 1; }
echo "Found: $APP"

if [ ! -f "$APP/Contents/SharedSupport/SharedSupport.dmg" ]; then
  DMG=$(find "$SCRATCH/expanded" -name "SharedSupport.dmg" | head -1)
  [ -n "$DMG" ] || { echo "ERROR: SharedSupport.dmg not found"; exit 1; }
  mkdir -p "$APP/Contents/SharedSupport"
  cp "$DMG" "$APP/Contents/SharedSupport/SharedSupport.dmg" || { echo "ERROR: copy failed"; exit 1; }
fi

# --- Erase whole USB and build installer ---
umount "$SRC" 2>/dev/null
diskutil unmountDisk force "$USBDISK" >/dev/null 2>&1
diskutil eraseDisk JHFS+ INSTALLUSB GPT "$USBDISK" || { echo "ERROR: eraseDisk failed"; exit 1; }
"$APP/Contents/Resources/createinstallmedia" --volume /Volumes/INSTALLUSB --nointeraction \
  || { echo "ERROR: createinstallmedia failed - send me the message above"; exit 1; }

echo
echo "DONE. Run: shutdown -h now"
echo "Then hold the power button until 'Loading startup options' and pick the installer."
