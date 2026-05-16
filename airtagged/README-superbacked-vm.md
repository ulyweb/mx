# Superbacked OS — VM Setup Guide (MX Linux Host)
> Running Superbacked OS inside Virtual Machine Manager (virt-manager/KVM) on MX Linux with a fully air-gapped (no network) VM.

---

## Overview

This guide walks through running Superbacked OS inside a KVM virtual machine on MX Linux using Virtual Machine Manager (`virt-manager`). The VM is configured with **zero network connectivity** — no wired, no wireless — making it an isolated environment suitable for testing and evaluating Superbacked OS without dedicated hardware.

> ⚠️ **Important Security Note**
> Running Superbacked OS in a VM is suitable for **testing and evaluation only**. For actual secret/seed phrase management, bare-metal booting from a USB drive is strongly preferred. A VM is not as secure as bare metal — the host OS can theoretically inspect VM memory.

---

## Requirements

- MX Linux host (Debian-based, any recent version)
- CPU with hardware virtualization support (Intel VT-x or AMD-V)
- Minimum 4GB RAM on host (2GB allocated to VM)
- At least 15GB free disk space for the image
- Internet connection on the host (to download the image — done before the VM is created)

---

## Phase 1 — Prepare Your MX Linux Host

### Step 1 — Verify Hardware Virtualization is Enabled

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Output must be `1` or higher. If `0`, enter your BIOS and enable **Intel VT-x** or **AMD-V**.

```bash
sudo apt install cpu-checker
kvm-ok
```

Expected output:
```
INFO: /dev/kvm exists
KVM acceleration can be used
```

---

### Step 2 — Install virt-manager and All KVM Dependencies

```bash
sudo apt update
sudo apt install --yes \
  virt-manager \
  qemu-kvm \
  qemu-system-x86 \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  ovmf
```

> `ovmf` is **critical** — it provides UEFI firmware for the VM. Superbacked OS (Ubuntu 24.04-based) requires UEFI, not legacy BIOS. Do not skip it.

---

### Step 3 — Add Your User to the Required Groups

```bash
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
```

**Log out and log back in** (or reboot) for group changes to take effect. Verify:

```bash
groups | grep -E 'libvirt|kvm'
```

---

### Step 4 — Start and Enable the libvirt Daemon

```bash
sudo systemctl enable --now libvirtd
sudo systemctl status libvirtd
```

Should show `active (running)`.

---

## Phase 2 — Download Superbacked OS

Do this on the host with internet — the VM will have no network, so all files must be ready beforehand.

### Step 5 — Download the Superbacked OS Image

```bash
cd ~/Downloads

for number in $(seq 1 2); do
  curl --fail --location \
    "https://github.com/superbacked/superbacked/releases/download/v1.10.0/superbacked-os-amd64-1.10.0.img.xz.part$number" \
  || break
done | cat > superbacked-os-amd64-1.10.0.img.xz
```

---

### Step 6 — Decompress the Image

```bash
cd ~/Downloads
xz --decompress --keep superbacked-os-amd64-1.10.0.img.xz
```

This produces `superbacked-os-amd64-1.10.0.img`. Verify:

```bash
ls -lh superbacked-os-amd64-1.10.0.img
file superbacked-os-amd64-1.10.0.img
```

The `file` command should show `DOS/MBR boot sector` or `x86 boot sector` — confirming it is a bootable disk image.

---

### Step 7 — Move the Image to the libvirt Storage Pool

```bash
sudo cp ~/Downloads/superbacked-os-amd64-1.10.0.img /var/lib/libvirt/images/
sudo chmod 644 /var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img
```

---

## Phase 3 — Create the VM in virt-manager

### Step 8 — Open virt-manager

```bash
virt-manager
```

---

### Step 9 — Create a New Virtual Machine

1. Click **"Create a new virtual machine"** (monitor icon with `+`)
2. Select **"Import existing disk image"** → click **Forward**
3. Click **Browse** → **Browse Locally** → navigate to:
   `/var/lib/libvirt/images/superbacked-os-amd64-1.10.0.img` → click **Open**
4. In the OS field, type `Ubuntu 24.04` and select it (or select `Generic Linux 2022` if not found) → click **Forward**
5. Set RAM: **2048 MB minimum** (4096 recommended)
6. CPUs: **2 minimum**
7. Click **Forward**
8. ✅ Check **"Customize configuration before install"**
9. Name the VM: `superbacked-os`
10. Click **Finish**

---

### Step 10 — Configure UEFI Firmware (Critical)

In the customization window:

1. Click **"Overview"** in the left panel
2. Find the **Firmware** dropdown
3. Change from `BIOS` to:
   ```
   UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd
   ```
   If not visible, confirm `ovmf` was installed in Step 2.
4. Click **Apply**

---

### Step 11 — Remove the Network Interface (Air-Gap the VM)

1. Click **"NIC"** in the left panel
2. Click the **"Remove"** button (minus `−` at bottom left)
3. Confirm removal

This gives the VM **zero network connectivity** — completely isolated.

---

### Step 12 — Set the Boot Order

1. Click **"Boot Options"** in the left panel
2. Ensure **VirtIO Disk 1** is checked and at the **top** of the boot order
3. Click **Apply**

---

### Step 13 — Optional: Pass Through a Physical Webcam

Superbacked OS uses a webcam to scan blocks. To pass through your webcam:

1. Click **"Add Hardware"**
2. Select **"USB Host Device"**
3. Find your webcam in the list and add it

---

### Step 14 — Start the VM

Click **"Begin Installation"** (top left of the customization window).

The VM boots directly into Superbacked OS.

---

## Phase 4 — Using Superbacked OS in the VM

### Step 15 — Log In

When prompted, the password is:
```
superbacked
```

---

### Step 16 — Confirm No Network

Open a terminal inside the VM:

```bash
ip a
```

You should see only the loopback interface (`lo`) — no `eth0`, no `wlan0`. The VM is fully air-gapped.

---

### Step 17 — Use Superbacked OS

Superbacked OS is a live system — **nothing persists between sessions**. Every shutdown and reboot returns it to a clean state, exactly as intended.

---

## Quick Reference

| Step | What | Why |
|------|------|-----|
| `egrep vmx/svm` | Check CPU virtualization | KVM won't work without it |
| Install `ovmf` | UEFI firmware package | Superbacked OS requires UEFI |
| Add user to groups | `libvirt` and `kvm` | Required permissions |
| Decompress `.img.xz` | Raw disk image | virt-manager boots this directly |
| Remove NIC in VM | Delete network interface | Eliminates all network access |
| UEFI firmware selection | Change from BIOS to OVMF | Without it the OS will not boot |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `KVM acceleration can not be used` | Enable VT-x/AMD-V in BIOS |
| VM fails to boot | Confirm UEFI/OVMF is selected, not BIOS |
| No network in VM | Expected — NIC was intentionally removed |
| Webcam not detected | Add USB host device passthrough in VM hardware settings |
| `virt-manager` not opening | Run `sudo systemctl start libvirtd` first |

---

*Superbacked OS version: 1.10.0 | Guide written for MX Linux (Debian 12-based) | virt-manager + KVM*
