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



**Why it didn't happen automatically:**
When you install a new desktop environment alongside an existing one, the display manager (SDDM) doesn't assume it should immediately take priority over your previous setup (GNOME). By default, SDDM will either highlight the system's previously active session or default to an X11 fallback until you manually make a choice, which it then saves as your preference.

Here is the single-line command to force SDDM to default to Plasma (Wayland) on the login screen. It dynamically finds the correct Wayland session name for your specific Plasma version and writes it directly to the SDDM configuration.

```bash
SESSION_FILE=$(basename $(ls /usr/share/wayland-sessions/plasma*.desktop | head -n 1) .desktop) && sudo mkdir -p /etc/sddm.conf.d && echo -e "[Autologin]\nSession=$SESSION_FILE" | sudo tee /etc/sddm.conf.d/10-force-plasma.conf > /dev/null && sudo systemctl restart sddm
```

*(Note: Running this will immediately restart the login screen. If you are currently logged in, it will end your session and drop you back at the newly configured SDDM login screen).*

**What this does under the hood:**
1. **`SESSION_FILE=...`**: Looks inside `/usr/share/wayland-sessions/` to find the exact name of the Plasma Wayland file (e.g., `plasma` or `plasmawayland`) and saves that name.
2. **`sudo mkdir -p /etc/sddm.conf.d`**: Ensures the custom configuration directory for SDDM exists.
3. **`echo -e "[Autologin]\nSession=$SESSION_FILE" | sudo tee...`**: Creates a configuration file that hardcodes Plasma Wayland as the default session loaded by the greeter.
4. **`sudo systemctl restart sddm`**: Restarts the display manager to apply the changes immediately.


Here is the updated single-line command. 

Because `veracrypt` is not included in the standard Ubuntu repositories, this updated script first adds the trusted community PPA (`ppa:unit193/encryption`) before proceeding with the rest of the installations.

```bash
sudo add-apt-repository -y ppa:unit193/encryption && sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt install -y debconf-utils && echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections && sudo DEBIAN_FRONTEND=noninteractive apt install -y kubuntu-desktop veracrypt keepassxc nodejs timeshift python3 && sudo reboot
```

**Additions to the script:**
* **`sudo add-apt-repository -y ppa:unit193/encryption`**: Silently adds the required repository to fetch VeraCrypt.
* **`veracrypt keepassxc nodejs timeshift python3`**: Appended directly to the final `apt install` command so they install simultaneously alongside the KDE Plasma environment.
