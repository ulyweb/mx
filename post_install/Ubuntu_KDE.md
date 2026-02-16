Clean, detailed, beginner‑friendly guide to switch your Ubuntu Desktop 25 VM from **GNOME** to **KDE Plasma**. I’ll walk you through everything from installation to selecting Plasma at login.

---

# ⭐ Step‑by‑Step: Install KDE Plasma on Ubuntu Desktop 25

Ubuntu makes it easy to install additional desktop environments. KDE Plasma can be installed **alongside GNOME**, and you choose which one to use when logging in.

---

# 1. Update your system  
Open a terminal and run:

```bash
sudo apt update
sudo apt upgrade -y
```

This ensures your system is ready for new packages.

---

# 2. Install KDE Plasma

You have two choices depending on how complete you want the KDE experience to be.

---

## **Option A — Full KDE (Kubuntu Desktop)**  
This installs the full KDE Plasma desktop **plus** all the standard KDE applications and settings.

```bash
sudo apt install kubuntu-desktop -y
```

During installation, Ubuntu will ask:

### **“Which display manager do you want to use?”**
- **gdm3** → GNOME’s login screen  
- **sddm** → KDE’s login screen (recommended for Plasma)

Choose **sddm** if you want the full KDE look and feel.

---

## **Option B — Minimal KDE Plasma (lighter install)**  
This installs only the Plasma desktop environment without the full suite of KDE apps.

```bash
sudo apt install plasma-desktop -y
```

You may still be asked to choose a display manager.

---

# 3. Reboot your system

```bash
sudo reboot
```

---

# 4. Choose KDE Plasma at the login screen

When the login screen appears:

1. Click your username  
2. Look for a **gear icon** or **session selector** (usually bottom-right or top-right)  
3. Select **Plasma** or **KDE Plasma**  
4. Log in normally

You will now be in KDE Plasma instead of GNOME.

---
