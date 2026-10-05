#!/bin/bash
# dfu_restore_mac.sh - MX Linux (Debian-based)
# Restores an Apple silicon Mac from DFU mode using idevicerestore + Apple IPSW.
# WARNING: wipes the target Mac completely.

WORK="$HOME/mac_dfu_restore"
IPSW_DIR="$HOME/Downloads/macos_ipsw"
LOG="$WORK/restore_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$WORK" "$IPSW_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "== Apple silicon DFU restore from Linux =="; date

# ---- IPSW choices (URLs from mrmacintosh.com IPSW database) ----
IPSW_TAHOE_URL="https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw"
IPSW_GG_URL="https://updates.cdn-apple.com/2026FallFCS/59241290-5d51-4ca8-9df4-31624b9a4eac/UniversalMac_27.0.1_26A434_Restore.ipsw"

echo
echo "Choose macOS version:"
echo "  1) macOS Tahoe 26.6.2  (newest Tahoe IPSW listed)"
echo "  2) macOS Golden Gate 27.0.1 (latest, ~3 weeks old)"
read -r -p "Enter 1 or 2: " CHOICE
case "$CHOICE" in
  1) URL="$IPSW_TAHOE_URL" ;;
  2) URL="$IPSW_GG_URL" ;;
  *) echo "Invalid choice."; exit 1 ;;
esac
IPSW="$IPSW_DIR/$(basename "$URL")"

# ---- 1. Dependencies + build idevicerestore stack (skipped if present) ----
if ! command -v idevicerestore >/dev/null; then
  echo "Installing build dependencies..."
  sudo apt-get update
  sudo apt-get install -y libcurl4-openssl-dev libplist-dev libzip-dev openssl libssl-dev \
    libusb-1.0-0-dev libreadline-dev build-essential git make automake autoconf libtool \
    pkg-config python3-dev usbutils curl || { echo "ERROR: apt install failed"; exit 1; }

  cd "$WORK" || exit 1
  for r in libplist libimobiledevice-glue libusbmuxd libimobiledevice usbmuxd libirecovery idevicerestore; do
    [ -d "$r" ] || git clone "https://github.com/libimobiledevice/$r" || { echo "ERROR: clone $r failed"; exit 1; }
  done
  # Debian: make sure /usr/local libs/pkgconfig are found during the chain build
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
  for r in libplist libimobiledevice-glue libusbmuxd libimobiledevice usbmuxd libirecovery idevicerestore; do
    echo "######## building $r"
    ( cd "$WORK/$r" && ./autogen.sh && make -j"$(nproc)" && sudo make install ) \
      || { echo "ERROR: build of $r failed - send me the last 20 lines"; exit 1; }
    sudo ldconfig
  done
fi
command -v idevicerestore >/dev/null || { echo "ERROR: idevicerestore not installed"; exit 1; }

# ---- 2. Download IPSW (resumable) ----
free_kb=$(df --output=avail -k "$IPSW_DIR" | tail -1)
[ "$free_kb" -gt 25000000 ] || { echo "ERROR: need ~25 GB free in $IPSW_DIR"; exit 1; }
remote=$(curl -sIL "$URL" | awk 'tolower($1)=="content-length:"{gsub("\r","");v=$2} END{print v}')
echo "Remote size: ${remote:-unknown}"
curl -L -C - --retry 5 --retry-delay 5 -o "$IPSW" "$URL" || { echo "ERROR: download failed (re-run to resume)"; exit 1; }
local_size=$(stat -c%s "$IPSW")
if [ -n "${remote:-}" ] && [ "$remote" != "$local_size" ]; then
  echo "ERROR: size mismatch ($local_size vs $remote). Re-run to resume."; exit 1
fi
echo "IPSW OK: $IPSW"

# ---- 3. Put the Mac in DFU ----
cat <<'EOF'

=== PUT THE MAC IN DFU MODE ===
1. Shut the MacBook Pro down completely and plug it into power.
2. Connect the USB-C data cable: Mac LEFT-side port closest to the back/screen -> this PC.
3. Press and hold: POWER + RIGHT Shift + LEFT Control + LEFT Option until it powers off/screen stays black.
4. Wait exactly 3 seconds, then release Shift/Control/Option but KEEP HOLDING POWER
   (a few more seconds) until the PC detects it. The Mac screen stays black - that's normal.
EOF
echo
echo "Waiting for the Mac to appear in DFU mode (Ctrl+C to abort)..."
until lsusb | grep -qi "Apple.*DFU"; do sleep 2; done
lsusb | grep -i apple
echo "DFU detected."

# ---- 4. Restore ----
sudo pkill usbmuxd 2>/dev/null; sudo usbmuxd 2>/dev/null
echo "Starting restore - do NOT unplug anything. Takes ~15-30 min; screen may flash and reboot."
sudo idevicerestore --erase "$IPSW"
RC=$?
if [ $RC -eq 0 ]; then
  echo "DONE. The Mac should boot to Setup Assistant. Log: $LOG"
else
  echo "ERROR: idevicerestore exit code $RC. Log: $LOG - send me the last 30 lines."
fi
