#!/bin/bash
# check_dfu.sh - watch for an Apple device in DFU on MX Linux
echo "Waiting up to 90s for an Apple USB device (vendor 05ac)..."
echo "NOW: Mac OFF, cable connected, MagSafe plugged in."
echo "Hold POWER + RIGHT Shift + LEFT Ctrl + LEFT Option ~10s, then release the 3 keys, keep holding POWER."
echo

sudo dmesg -C 2>/dev/null
for i in $(seq 1 45); do
  if lsusb | grep -qi "05ac"; then
    echo "DETECTED:"; lsusb | grep -i "05ac"
    if lsusb | grep -qi "DFU"; then
      echo ">>> DFU MODE CONFIRMED. Open RestoreKit now."
    else
      echo ">>> Apple device seen but NOT DFU (probably Recovery/boot). Shut down and redo the key sequence."
    fi
    exit 0
  fi
  sleep 2
done

echo
echo "NOT DETECTED. USB bus snapshot:"
lsusb
echo
echo "Kernel USB messages (empty = PC saw nothing = cable/port/Mac issue):"
sudo dmesg | tail -20
echo
echo "Try next: 1) different cable (data-capable)  2) USB-A to USB-C cable  3) other PC port  4) other left-side Mac port  5) redo key sequence."
