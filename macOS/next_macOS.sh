#!/bin/bash
# Build a bootable macOS installer on the USB from inside Recovery
SRC="/Volumes/PKGUSB"                 # USB holding InstallAssistant.pkg
SCRATCH="/Volumes/Macintosh HD/tmp"   # internal scratch (erased volume)

set -e
[ -f "$SRC/InstallAssistant.pkg" ] || { echo "ERROR: $SRC/InstallAssistant.pkg not found"; ls /Volumes; exit 1; }
mkdir -p "$SCRATCH"
echo "Expanding package (takes several minutes)..."
pkgutil --expand-full "$SRC/InstallAssistant.pkg" "$SCRATCH/expanded"

APP=$(find "$SCRATCH/expanded" -maxdepth 4 -type d -name "Install macOS*.app" | head -1)
[ -n "$APP" ] || { echo "ERROR: Install app not found"; find "$SCRATCH/expanded" -maxdepth 3; exit 1; }
echo "Found: $APP"

# Make sure SharedSupport.dmg is inside the app
if [ ! -f "$APP/Contents/SharedSupport/SharedSupport.dmg" ]; then
  DMG=$(find "$SCRATCH/expanded" -name "SharedSupport.dmg" | head -1)
  [ -n "$DMG" ] || { echo "ERROR: SharedSupport.dmg not found"; exit 1; }
  mkdir -p "$APP/Contents/SharedSupport"
  cp "$DMG" "$APP/Contents/SharedSupport/SharedSupport.dmg"
fi

# Erase the pkg USB and turn it into the installer
diskutil eraseVolume JHFS+ INSTALLUSB "$SRC"
"$APP/Contents/Resources/createinstallmedia" --volume /Volumes/INSTALLUSB --nointeraction
echo "DONE. Shut down, then hold the power button until 'Loading startup options' and pick the installer."
