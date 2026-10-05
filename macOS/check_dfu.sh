#!/bin/bash
# =============================================================================
# check_dfu.sh - watch for an Apple device in DFU mode (MX Linux / Debian)
# Part of MAC-DFU-RESTORE. Safe/read-only: only runs lsusb (+ dmesg on timeout).
# Audit: ~/Mac_DFU_Restore/dfu_check_<timestamp>.log
# Usage : ./check_dfu.sh [seconds]      (default 90)
# Exit  : 0 = DFU confirmed, 1 = Apple device but NOT DFU, 2 = nothing detected
# =============================================================================
set -u
MAXWAIT="${1:-90}"
BASE="$HOME/Mac_DFU_Restore"
mkdir -p "$BASE"
LOG="$BASE/dfu_check_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

command -v lsusb >/dev/null 2>&1 || { echo "ERROR: lsusb missing -> sudo apt-get install usbutils"; exit 2; }

echo "Waiting up to ${MAXWAIT}s for an Apple USB device (vendor 05ac)..."
echo "NOW: Mac OFF, USB-C data cable in the LEFT port next to MagSafe, MagSafe plugged in."
echo "Hold POWER + RIGHT Shift + LEFT Ctrl + LEFT Option ~10s, release the 3 keys, keep holding POWER ~5s."
echo

sudo -n dmesg -C 2>/dev/null
SEEN_NONDFU=0
for _ in $(seq 1 $((MAXWAIT / 2))); do
  L="$(lsusb -d 05ac: 2>/dev/null)"
  if [ -n "$L" ]; then
    if printf '%s' "$L" | grep -qi "DFU"; then
      echo "DETECTED:"; printf '%s\n' "$L"
      echo ">>> DFU MODE CONFIRMED. Open RestoreKit now."
      exit 0
    fi
    if [ "$SEEN_NONDFU" = "0" ]; then
      echo "Apple device present but NOT DFU: $(printf '%s' "$L" | head -1)"
      echo "  -> shut the Mac fully down and redo the key sequence."
      SEEN_NONDFU=1
    fi
  fi
  sleep 2
done

echo
if [ "$SEEN_NONDFU" = "1" ]; then
  echo "RESULT: Apple device seen but never entered DFU."
else
  echo "RESULT: NOT DETECTED. USB bus snapshot:"
  lsusb
  echo
  echo "Kernel USB messages (empty = PC saw nothing = cable/port/Mac issue):"
  sudo -n dmesg 2>/dev/null | tail -20 || echo "(run with sudo for dmesg)"
  echo
  echo "Try next: 1) data-capable cable  2) USB-A to USB-C cable  3) other PC port  4) other left-side Mac port  5) redo key sequence."
fi
echo "Log: $LOG"
[ "$SEEN_NONDFU" = "1" ] && exit 1
exit 2
