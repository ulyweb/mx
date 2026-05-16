# Superbacked OS — USB Airgap Setup Guide (MX Linux)
> Flashing Superbacked OS to a USB thumb drive from MX Linux using `dd`, with a VeraCrypt hidden volume occupying the remaining space — no Raspberry Pi Imager required.

---

## Overview

This guide walks through:
1. Wiping an existing USB thumb drive completely
2. Flashing Superbacked OS using `dd`
3. Creating a VeraCrypt hidden volume in the remaining space for encrypted data storage
4. How to mount and use the encrypted partition going forward

> ✅ This guide works with **any existing USB thumb drive** — new or previously used. Wiping is covered as the first step.

---

## Requirements

- MX Linux host (Debian-based, any recent version)
- USB thumb drive — **16GB minimum**, 128GB used in this guide
- Internet connection on the host (for initial downloads only)
- `parted`, `cryptsetup`, `veracrypt` (installed during the guide)
- The decompressed Superbacked OS `.img` file (see Download section)
- Two strong passphrases prepared in advance (outer + hidden volume)

---

## Your USB Layout (End Result)

```
/dev/sda                    123GB USB Thumb Drive
├─ sda1   537MB   FAT32     Superbacked OS boot partition
├─ sda2   10.7GB  ext4      Superbacked OS root partition
└─ sda3   ~112GB  VeraCrypt Hidden volume container
                   ├─ Outer Volume  → Outer passphrase  → decoy files
                   └─ Hidden Volume → Hidden passphrase → real sensitive data
```

---

## Why VeraCrypt Over LUKS?

| Feature | LUKS2 | VeraCrypt |
|---|---|---|
| Cross-platform (Linux/Win/Mac) | ❌ Linux only | ✅ All three |
| Hidden volume (plausible deniability) | ❌ No | ✅ Yes |
| Independently audited | ❌ Limited | ✅ Yes (2016) |
| GUI available | Partial | ✅ Full GUI |
| Native to Linux, no install needed | ✅ Yes | ❌ Must install |
| Standard on Linux systems | ✅ Yes | ❌ Needs package |

**VeraCrypt is the stronger choice** for this use case because of cross-platform portability, independent security audit, and the hidden volume (plausible deniability) feature. LUKS headers visibly identify themselves as encrypted — VeraCrypt hidden volumes are mathematically undetectable.

---

## How the Hidden Volume Works

```
/dev/sda3  (VeraCrypt container — looks like random data to anyone)
├─ Outer Volume  → Enter Password A → opens decoy files (believable, unimportant)
└─ Hidden Volume → Enter Password B → opens your real sensitive data
```

When you enter **Password A** — VeraCrypt opens the outer volume. Anyone watching sees ordinary files. There is **zero cryptographic evidence** a hidden volume exists.

When you enter **Password B** — VeraCrypt silently opens the hidden volume. Same command, different password, completely different data.

---

## Phase 1 — Download Superbacked OS (Host, With Internet)

### Step 1 — Download the Superbacked OS Image

```bash
cd ~/Downloads

for number in $(seq 1 2); do
  curl --fail --location \
    "https://github.com/superbacked/superbacked/releases/download/v1.10.0/superbacked-os-amd64-1.10.0.img.xz.part$number" \
  || break
done | cat > superbacked-os-amd64-1.10.0.img.xz
```

---

### Step 2 — Decompress the Image

```bash
cd ~/Downloads
xz --decompress --keep superbacked-os-amd64-1.10.0.img.xz
```

Verify:

```bash
ls -lh superbacked-os-amd64-1.10.0.img
file superbacked-os-amd64-1.10.0.img
```

Should show `DOS/MBR boot sector` or `x86 boot sector`.

---

### Step 3 — Move to libvirt Storage (Optional but Recommended)

```bash
sudo cp ~/Downloads/superbacked-os-amd64-1.10.0.img /var/lib/libvirt/images/
sudo chmod 644 /var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img
```

---

## Phase 2 — Identify and Wipe the USB Drive

> ⚠️ **Always wipe first** — even a brand new USB may have a factory partition table that interferes with the image write. For previously used drives this step is mandatory.

### Step 4 — Plug In the USB and Identify It

```bash
lsblk
```

Example output:
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    1 114.6G  0 disk        ← USB (RM=1 means removable)
├─sda1        8:1    1   149M  0 part
├─sda2        8:2    1 114.4G  0 part
└─sda3        8:3    1    49M  0 part
nvme0n1     259:0    0 953.9G  0 disk        ← internal SSD (DO NOT TOUCH)
├─nvme0n1p1 259:1    0   256M  0 part /boot/efi
└─nvme0n1p2 259:2    0 953.6G  0 part /
```

> ⚠️ **Identify your USB device carefully.** In this guide the USB is `/dev/sda`. Your internal drive may be `nvme0n1` or `sda` — confirm by size and the `RM=1` (removable) flag. **Writing to the wrong device will permanently destroy data.**

Cross-check with:

```bash
sudo fdisk -l | grep -E "^Disk /dev/"
```

---

### Step 5 — Unmount All USB Partitions

```bash
sudo umount /dev/sda1 2>/dev/null
sudo umount /dev/sda2 2>/dev/null
sudo umount /dev/sda3 2>/dev/null
```

No error if not mounted — that is fine.

---

### Step 6 — Wipe All Partition Signatures

```bash
sudo wipefs --all /dev/sda
```

Verify it is clean (should return no output):

```bash
sudo wipefs /dev/sda
```

---

### Step 7 — Zero Out the First 10MB

This clears any leftover boot records:

```bash
sudo dd if=/dev/zero of=/dev/sda bs=1M count=10 status=progress
sync
```

---

### Step 8 — Confirm the Drive is Blank

```bash
sudo parted /dev/sda print free
```

Expected output:
```
Partition Table: unknown
Number  Start  End    Size   File system  Name  Flags
        0.00B  123GB  123GB  Free Space
```

`Partition Table: unknown` with one big `Free Space` block = perfectly blank. ✅

---

## Phase 3 — Flash Superbacked OS with `dd`

### Step 9 — Write the Image

```bash
sudo dd \
  if=/var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img \
  of=/dev/sda \
  bs=4M \
  status=progress \
  conv=fsync

sync
```

- `bs=4M` — writes in 4MB chunks for speed
- `status=progress` — shows live write progress
- `conv=fsync` — flushes all data before exit, preventing silent incomplete writes

Expected speed: **50–200 MB/s** depending on your USB drive. This takes a few minutes. A suspiciously fast write (2+ GB/s) means you are writing to a file or VM disk, not real hardware — stop and check your device name.

---

### Step 10 — Verify the Write Integrity

Get checksum of original image:

```bash
sha256sum /var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img
```

Get checksum of what was written to the USB:

```bash
sudo dd if=/dev/sda bs=4M status=progress \
  | head -c $(stat -c%s /var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img) \
  | sha256sum
```

Both hashes must match exactly. If they differ, repeat the `dd` write.

---

### Step 11 — Inspect the Written Partition Table

```bash
sudo parted /dev/sda print free
```

Expected output:
```
Model: USB SanDisk 3.2Gen1 (scsi)
Disk /dev/sda: 123GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos

Number  Start   End     Size    Type     File system  Flags
        32.3kB  1049kB  1016kB           Free Space
 1      1049kB  538MB   537MB   primary  fat32        boot, esp
 2      538MB   11.3GB  10.7GB  primary  ext4
        11.3GB  123GB   112GB            Free Space   ← this is where sda3 goes
```

Note the **End** value of partition 2 (`11.3GB`) — your new partition starts here.

---

## Phase 4 — Create the VeraCrypt Data Partition

### Step 12 — Install Required Tools

```bash
sudo apt update
sudo apt install --yes parted cryptsetup
```

---

### Step 13 — Create a New Partition in the Free Space

```bash
sudo parted /dev/sda mkpart primary 11.3GB 100%
```

Replace `11.3GB` with the actual end value of partition 2 from your `parted` output if different.

Confirm:

```bash
sudo parted /dev/sda print
```

You should now see `sda3` covering the remaining ~112GB.

---

### Step 14 — Refresh the Kernel Partition Table

```bash
sudo partprobe /dev/sda
```

Verify `sda3` is visible:

```bash
lsblk /dev/sda
```

---

## Phase 5 — Install VeraCrypt

### Step 15 — Download VeraCrypt (Latest: 1.26.24)

```bash
cd ~/Downloads

wget https://launchpad.net/veracrypt/trunk/1.26.24/+download/veracrypt-1.26.24-Debian-12-amd64.deb
```

> MX Linux 23 is based on Debian 12 (Bookworm) — this is the correct package.

---

### Step 16 — Verify the Download

```bash
sha256sum veracrypt-1.26.24-Debian-12-amd64.deb
```

Compare against the official checksum at `https://veracrypt.jp/en/Downloads.html` — they must match before proceeding.

---

### Step 17 — Install VeraCrypt

```bash
sudo apt install --yes ./veracrypt-1.26.24-Debian-12-amd64.deb
```

Verify:

```bash
veracrypt --version
```

---

## Phase 6 — Create the Outer + Hidden Volume on `/dev/sda3`

> ⚠️ **Prepare two strong passphrases before starting:**
> - **Outer passphrase** — opens the decoy volume (things you don't mind revealing)
> - **Hidden passphrase** — opens your real sensitive data (never reveal this)
>
> There is **no recovery** if either passphrase is lost. Store them securely offline.

---

### Step 18 — Launch VeraCrypt GUI

```bash
veracrypt
```

---

### Step 19 — Volume Creation Wizard

1. Click **"Create Volume"**
2. Select **"Encrypt a non-system partition/drive"** → click **Next**
3. Select **"Hidden VeraCrypt volume"** → click **Next**
4. Select **"Normal mode"** → click **Next**

---

### Step 20 — Select the Partition

1. Click **"Select Device"**
2. Choose `/dev/sda3` from the list → click **OK**
3. Click **Next**

---

### Step 21 — Configure Outer Volume Encryption

1. Encryption Algorithm: **AES** (fastest, most trusted)
2. Hash Algorithm: **SHA-512**
3. Click **Next**
4. Outer volume size is shown automatically (full `sda3` size) → click **Next**
5. Enter your **Outer passphrase** → confirm → click **Next**

---

### Step 22 — Format the Outer Volume

1. Filesystem: **ext4** (Linux only) or **exFAT** (cross-platform Windows/Mac/Linux)
2. Move your mouse **randomly inside the window for at least 30 seconds** — the entropy progress bar must reach the end
3. Click **"Format"**
4. Wait for completion → click **Next**

---

### Step 23 — Add Decoy Files to the Outer Volume

VeraCrypt will prompt you to open the outer volume and populate it with believable files.

1. Click **"Open Outer Volume"**
2. Copy some plausible but unimportant files — old documents, random photos, anything believable
3. ⚠️ **Do not fill more than 40–50% of the outer volume** — the hidden volume lives in the "free space"
4. When done, click **Next** in the wizard

---

### Step 24 — Configure the Hidden Volume

1. VeraCrypt shows the maximum possible hidden volume size
2. Set hidden volume size — e.g. `50G` if you have ~112GB total
3. Click **Next**
4. Encryption Algorithm: **AES** → click **Next**
5. Enter your **Hidden passphrase** (must be different from outer) → confirm → click **Next**

---

### Step 25 — Format the Hidden Volume

1. Filesystem: **ext4** or **exFAT**
2. Move your mouse randomly for **30+ seconds** again
3. Click **"Format"**
4. Wait for completion → click **Finish**

---

## Phase 7 — Booting Superbacked OS from USB

### On Your MX Linux Machine

1. Plug in the USB
2. Reboot and enter BIOS/UEFI boot menu (usually `F12`, `F2`, `ESC`, or `DEL` on boot)
3. Select your USB drive from the boot menu
4. At the Superbacked OS boot screen, select:
   ```
   Advanced options for Ubuntu → Ubuntu, with Linux 6.14.0-37-generic
   ```
5. Log in with password: `superbacked`
6. Unplug Ethernet if connected before using Superbacked OS

---

## Phase 8 — Using the VeraCrypt Partition on MX Linux

### Mount the Outer Volume (Decoy)

```bash
sudo mkdir -p /mnt/superbacked-data
veracrypt /dev/sda3 /mnt/superbacked-data
```

Enter your **outer passphrase** → opens decoy data.

---

### Mount the Hidden Volume (Real Data)

```bash
veracrypt /dev/sda3 /mnt/superbacked-data
```

Enter your **hidden passphrase** → VeraCrypt silently opens the hidden volume instead. Same command, different password, completely different data.

---

### Unmount and Lock When Done

```bash
veracrypt -d /dev/sda3
```

---

## ⚠️ Critical Rules to Protect the Hidden Volume

| Rule | Why |
|------|-----|
| Never fill the outer volume more than 40–50% | Hidden volume lives in the outer volume's free space |
| Always unmount before unplugging the USB | Prevents filesystem corruption |
| Never reveal the hidden passphrase | That is the entire point of plausible deniability |
| Store both passphrases securely offline | No recovery possible if lost — ever |
| When writing to outer volume, enable hidden volume protection in VeraCrypt | Prevents outer volume writes from overwriting hidden volume data |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `dd` finishes in under 5 seconds at 2+ GB/s | You wrote to a file/VM disk, not the USB — recheck device name |
| USB not detected after `dd` | Run `sudo partprobe /dev/sda` and `lsblk` again |
| `parted mkpart` fails | Confirm `sda3` doesn't already exist with `lsblk` |
| VeraCrypt won't open `/dev/sda3` | Make sure the partition is not mounted: `sudo umount /dev/sda3` |
| Superbacked OS won't boot from USB | Confirm UEFI boot is enabled and Secure Boot settings in BIOS |
| Hidden volume data seems missing | You used the wrong passphrase — outer and hidden use different passwords |

---

## Quick Reference — Full Command Summary

```bash
# 1. Wipe USB
sudo wipefs --all /dev/sda
sudo dd if=/dev/zero of=/dev/sda bs=1M count=10 status=progress && sync

# 2. Flash Superbacked OS
sudo dd if=/var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img \
  of=/dev/sda bs=4M status=progress conv=fsync && sync

# 3. Create data partition
sudo parted /dev/sda mkpart primary 11.3GB 100%
sudo partprobe /dev/sda

# 4. Install VeraCrypt
sudo apt install --yes ./veracrypt-1.26.24-Debian-12-amd64.deb

# 5. Create hidden volume (use GUI)
veracrypt

# 6. Mount hidden volume
veracrypt /dev/sda3 /mnt/superbacked-data   # enter hidden passphrase

# 7. Unmount
veracrypt -d /dev/sda3
```

---

*Superbacked OS version: 1.10.0 | VeraCrypt version: 1.26.24 | Guide written for MX Linux (Debian 12-based)*
