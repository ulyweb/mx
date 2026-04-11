Single-line bash command. It uses `DEBIAN_FRONTEND=noninteractive` and `debconf-set-selections` to automatically bypass the display manager prompt, install the full KDE suite, and immediately reboot the system.

```bash
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt install -y debconf-utils && echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections && sudo DEBIAN_FRONTEND=noninteractive apt install -y kubuntu-desktop && sudo reboot
```

**What this does under the hood:**
1. **`sudo apt update && ... apt upgrade -y`**: Refreshes repositories and upgrades existing packages.
2. **`... apt install -y debconf-utils`**: Ensures the tool required to pre-answer installation prompts is present.
3. **`echo "sddm..." | sudo debconf-set-selections`**: Silently answers the "gdm3 vs sddm" prompt by pre-selecting `sddm`.
4. **`... apt install -y kubuntu-desktop`**: Installs the full KDE Plasma environment without asking any interactive questions.
5. **`sudo reboot`**: Restarts your VM immediately so you can select Plasma at the new SDDM login screen.
