# 🧩 1. The Best Virtualization Stack for MX‑25.1

MX Linux (especially MX‑25.1) is Debian‑based and plays extremely well with:

## **Option A — KVM + QEMU + Virt‑Manager (BEST CHOICE)**  
This is the **native Linux hypervisor**, built into the kernel.

### Why it’s the best:
- **Fastest performance** (hardware virtualization via KVM)
- **Native snapshot support**
- **Supports qcow2 images** (copy‑on‑write, compressed, encrypted)
- **Perfect for offline / air‑gapped VMs**
- **Stable, open‑source, no proprietary drivers**
- **Used by security‑focused distros (Qubes, Whonix, Tails devs)**

### Install everything:
```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager
```

---
# 🏆 **Conclusion: Use KVM + QEMU + Virt‑Manager**  
This is the professional‑grade solution.

---

# 🧱 2. How to Configure KVM Properly on MX‑25.1

Here’s the correct setup for a stable, snapshot‑friendly VM environment.

---

## **Step 1 — Enable KVM hardware virtualization**
Check if your CPU supports it:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

If the result is **1 or higher**, you’re good.

---

## **Step 2 — Add yourself to the libvirt group**
```bash
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

Log out and back in.

---

## **Step 3 — Create a qcow2 disk (supports snapshots)**
Inside Virt‑Manager:

- Storage format: **qcow2**
- Enable:
  - **Copy‑on‑write**
  - **Compression**
  - **Sparse allocation**

This gives you:

- Fast snapshots  
- Small disk footprint  
- Easy cloning  
- Perfect for offline images  

---

## **Step 4 — Enable UEFI (OVMF)**
This ensures your VM matches modern hardware.

Install firmware:

```bash
sudo apt install ovmf
```

In Virt‑Manager → Firmware → **UEFI (OVMF)**

---

## **Step 5 — Enable VirtIO drivers**
For:

- Disk  
- Network  
- Display  

This gives you near‑native performance.

---

# 📸 3. Creating Snapshots the Right Way

Inside Virt‑Manager:

1. Shut down the VM  
2. Open **View → Snapshots**  
3. Click **Take Snapshot**  
4. Name it something meaningful:
   - `baseline-clean`
   - `post-hardening`
   - `airgap-final`

Snapshots are stored inside the qcow2 file.

---

# 🧊 4. Creating a “Frozen” Air‑Gapped MX Linux Image

This is the part you care about most.

You want:

- Your fully configured MX‑25.1  
- All apps installed  
- All settings applied  
- No internet  
- No updates  
- No external attack surface  

Here’s how to do it properly.

---

## **Step 1 — Build your perfect MX Linux inside the VM**
Install:

- All apps  
- All configs  
- All hardening  
- All scripts  
- All privacy tools  

Get it EXACTLY how you want it.

---

## **Step 2 — Take a “golden snapshot”**
Name it:

```
gold-master
```

This is your **immutable baseline**.

---

## **Step 3 — Clone the VM**
Virt‑Manager → Right‑click VM → **Clone**

Choose:

- **Full clone** (not linked clone)
- Storage format: **qcow2**

This gives you a **standalone, portable, offline VM**.

---

## **Step 4 — Disable networking**
Inside Virt‑Manager:

- NIC → **Remove hardware**

Inside the VM:

- Disable NetworkManager  
- Remove DNS resolvers  
- Remove DHCP client  

Now the VM is **air‑gapped**.

---

## **Step 5 — Export the VM**
Virt‑Manager → File → **Export**

This produces a portable VM image you can store offline.

---

# 🔐 5. Why This Is Secure and Beneficial

### ✔ Air‑gapped = immune to:
- Malware  
- Remote exploits  
- Supply‑chain attacks  
- Zero‑days  
- Telemetry  
- Network leaks  

### ✔ Snapshots = perfect rollback
If anything breaks:

- Roll back in 2 seconds  
- No reinstall  
- No reconfiguration  

### ✔ qcow2 = encrypted, compressed, copy‑on‑write
- Small file size  
- Fast  
- Secure  
- Easy to duplicate  

### ✔ VM isolation = hardware sandbox
Your host OS cannot be compromised by the VM, and vice‑versa.

### ✔ Perfect for:
- Secure research  
- Malware analysis  
- Offline development  
- Privacy‑focused workflows  
- Immutable computing  

---


# 🧩 1. Let’s build this like an infrastructure person.

## I’ll walk you through:

1. Installing KVM + QEMU + libvirt + Virt‑Manager on MX‑25.1  
2. Verifying hardware virtualization is actually working  
3. Correct libvirt/user/group setup  
4. Creating a VM from your existing MX ISO  
5. Tuning the VM for performance and snapshots  
6. Taking and using snapshots like a pro  

---

### 1. Install KVM, QEMU, libvirt, Virt‑Manager

Open a terminal in your **installed MX‑25.1** (not live):

```bash
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager bridge-utils ovmf
```

**What each piece is:**

- **qemu-kvm:** KVM‑accelerated virtualization backend  
- **libvirt-daemon-system / libvirt-clients:** libvirt service + CLI tools  
- **virt-manager:** GUI to manage VMs  
- **bridge-utils:** for advanced networking (optional but good to have)  
- **ovmf:** UEFI firmware for VMs  

---

### 2. Verify hardware virtualization support

Run:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

- **Result ≥ 1:** CPU supports virtualization  
- **Result = 0:** VT‑x/AMD‑V disabled in BIOS/UEFI → enable it there first  

Then check KVM modules:

```bash
lsmod | grep kvm
```

You should see:

- `kvm_intel` or `kvm_amd`  
- `kvm`  

If not, try:

```bash
sudo modprobe kvm
sudo modprobe kvm_intel   # or kvm_amd
```

---

### 3. Add your user to the right groups

So you don’t have to run everything as root:

```bash
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

Then **log out and log back in** (group changes only apply to new sessions).

You can confirm:

```bash
groups
```

You should see `libvirt` and `kvm` in the list.

---

### 4. Start and verify libvirtd

On MX (Debian‑based), libvirt is usually managed via systemd even if the system uses sysvinit for PID 1.

Check status:

```bash
sudo systemctl status libvirtd
```

If it’s not active:

```bash
sudo systemctl enable --now libvirtd
```

---

### 5. Launch Virt‑Manager

From your MX menu, open:

> **Virtual Machine Manager** (virt-manager)

Or from terminal:

```bash
virt-manager
```

You should see:

- A connection: **QEMU/KVM – System**  
- Status: **Connected**

If it shows “Not connected”, click it and connect.

---

### 6. Create a new VM from your existing MX ISO

You said you already have an MX snapshot ISO — perfect.

In Virt‑Manager:

1. **File → New Virtual Machine**
2. **Step 1 – Choose how to install:**
   - Select: **Local install media (ISO image or CDROM)**
3. **Step 2 – Choose ISO:**
   - Click **Browse** → **Browse Local**
   - Select your MX snapshot ISO
   - OS type: **Linux**
   - Version: **Debian 12** or **Generic Linux 6.x** (close enough)
4. **Step 3 – Memory and CPU:**
   - **RAM:**  
     - 4 GB (4096 MB) minimum for comfort  
     - 8 GB if you have enough host RAM  
   - **CPUs:**  
     - 2 vCPUs minimum  
     - 4 if your host has 8+ threads
5. **Step 4 – Storage:**
   - Check **Create a disk image for the virtual machine**
   - Size:  
     - 40–80 GB if you plan to install a lot  
   - Click **Customize configuration before install** (important)
6. **Step 5 – Name:**
   - Name it something like: `mx25-golden-vm`
   - Click **Finish** → this opens the VM details before boot

---

### 7. Correct VM configuration (engineering‑grade)

In the VM details window:

#### **Overview → Firmware**

- **Firmware:** select **UEFI (OVMF)** if available  
  - This matches modern hardware and future‑proofs the VM

#### **Overview → Chipset**

- Use **Q35** if available (more modern), otherwise **i440FX** is fine.

---

#### **CPUs**

- **Model:** host‑passthrough (best performance)
- **vCPUs:** 2–4 depending on your host
- Enable:
  - **Copy host CPU configuration** if available

---

#### **Memory**

- **Current allocation:** 4096–8192 MB  
- **Max allocation:** same as current (no ballooning needed for your use case)

---

#### **Disk (vda)**

Click the disk:

- **Bus type:** set to **VirtIO** (for performance)
- **Cache mode:** `writeback` or `none` (default is usually fine)
- **Storage format:** should be **qcow2** (this is critical for snapshots)

If it’s not qcow2, recreate the disk as qcow2:

- Delete the disk  
- Add Hardware → Storage → qcow2 → set size  

---

#### **Network**

Click **NIC**:

- **Device model:** `virtio`  
- If you plan to air‑gap this VM:
  - For now, leave it enabled to install and update  
  - Later, you can **remove the NIC** entirely

---

#### **Display**

- **Type:** `Spice`  
- **Video model:** `QXL` or `Virtio` (for better performance)

---

When done, click **Begin Installation**.

---

### 8. Install MX inside the VM (from your snapshot ISO)

You know this part already, but key points:

- Boot from your snapshot ISO  
- Install MX to the virtual disk (vda)  
- Reboot into the installed system (not the live ISO)  
- Confirm everything works: apps, configs, etc.

At this point, you have:

- A **virtual MX** that mirrors your configured system  
- Running on **KVM** with **qcow2** storage  

Now we make it snapshot‑friendly and air‑gap‑ready.

---

### 9. Take a “golden” snapshot

Shut down the VM cleanly.

In Virt‑Manager:

1. Select your VM (`mx25-golden-vm`)
2. **View → Snapshots**
3. Click **Take Snapshot**
4. Name it: `baseline-clean` or `gold-master`
5. Optionally add a description:  
   - “Fresh install from MX snapshot ISO, fully configured”

This snapshot is your **frozen, known‑good state**.

---

### 10. Clone the VM for experiments

Instead of abusing the golden VM, clone it.

In Virt‑Manager:

1. Right‑click your VM → **Clone**
2. Name: `mx25-lab-1` or similar
3. Choose:
   - **Clone type:** Full clone
   - This creates a separate qcow2 file
4. Finish

Now you have:

- `mx25-golden-vm` → untouched baseline  
- `mx25-lab-1` → playground  

---

### 11. Air‑gap the VM

Once you’re happy with the internal state and don’t need internet:

1. Shut down the VM
2. In Virt‑Manager → VM details → **NIC**
3. Click **Remove Hardware**

Now the VM has **no network card at all**.

Inside the VM, you can also:

- Disable NetworkManager  
- Remove any leftover network configs  

Result: **true air‑gap** — no network stack, no IP, no DNS, nothing.

---

### 12. Using snapshots in “engineering mode”

For your lab VM (`mx25-lab-1`):

- Before big changes:
  - Shut down  
  - Take a snapshot: `pre-change-X`
- After changes:
  - If happy → keep going  
  - If broken → revert snapshot

To revert:

1. Shut down the VM
2. Virt‑Manager → Snapshots
3. Select snapshot → **Revert**

This is instant rollback.

---

### 13. Using your existing MX snapshot ISO inside this flow

You said:

> “Once I have setup I will use my current snapshot that's ISO already and see if it works or not”

That’s exactly what we did:

- You used your **MX snapshot ISO** as the install media  
- Installed it into a **KVM VM**  
- Took a **golden snapshot**  
- Cloned it for experiments  
- Air‑gapped it by removing NIC  

So now you have:

- A **virtualized, reproducible version** of your tuned MX system  
- Snapshots for rollback  
- Air‑gap capability for security  
- All of it running on **native Linux virtualization**  

---
