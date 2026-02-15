Yeah, that makes sense that it didn’t work—and the reason isn’t you, it’s the stack you’re on.

MX (especially live) is usually running **sysvinit by default**, not systemd, so that `systemd` service I gave you never even fires. On top of that, by the time a real shutdown sequence runs, your graphical session is already gone—so any `zenity` prompt hooked that late won’t even be visible.

So if you want a **real, reliable prompt**, the only place you can guarantee it shows up is **before** you trigger shutdown/reboot—inside your desktop session.

That means: instead of “catching” shutdown, you **own** shutdown.

Here’s a version that actually works in that model.

---

### 1. Create a custom “exit with persistence prompt” script

Create this file:

`/usr/local/bin/mx-exit-persist.sh`

```bash
#!/bin/bash

CONFIG_FILE="/etc/live/persist-config.conf"

# Ask whether to save changes
zenity --question \
    --title="Persistence" \
    --text="Do you want to save your changes?" \
    --ok-label="Yes, save" \
    --cancel-label="No, discard"

if [ $? -eq 0 ]; then
    # YES → autosave
    sudo sed -i 's/^AUTOSAVE_MODE=.*/AUTOSAVE_MODE="1 Automatic"/' "$CONFIG_FILE"
else
    # NO → manual (no save)
    sudo sed -i 's/^AUTOSAVE_MODE=.*/AUTOSAVE_MODE="3 Manual"/' "$CONFIG_FILE"
fi

# Now ask what to do: shutdown or reboot
action=$(zenity --list \
    --title="Exit" \
    --text="What do you want to do?" \
    --column="Action" \
    "Shutdown" "Reboot" "Cancel")

case "$action" in
    "Shutdown")
        sudo poweroff
        ;;
    "Reboot")
        sudo reboot
        ;;
    *)
        exit 0
        ;;
esac
```

Then:

```bash
sudo chmod +x /usr/local/bin/mx-exit-persist.sh
```

This script:

- Prompts: **“Do you want to save your changes?”**
- Writes `AUTOSAVE_MODE="1 Automatic"` or `AUTOSAVE_MODE="3 Manual"` accordingly
- Then asks: **Shutdown / Reboot / Cancel**
- Calls `poweroff` or `reboot` directly (works with sysvinit)

---

### 2. Wire this into how you actually exit MX

Since we can’t reliably “intercept” every shutdown path, the practical move is:

- Replace your usual logout/shutdown entry with this script.

For XFCE (default MX desktop):

1. Right‑click the **panel** → **Panel → Add New Items…**
2. Add a **Launcher**.
3. Edit the launcher:
   - **Name:** Exit (with persistence)
   - **Command:**  
     `/usr/local/bin/mx-exit-persist.sh`
4. Optionally change the icon to a power symbol.

Now, instead of using the normal logout/shutdown menu, you click this launcher.  
You get:

- Save? **Yes/No** → writes the mode  
- Then **Shutdown/Reboot** choice  

That’s the only place we can guarantee:

- GUI is still alive  
- You see the prompt  
- The config file is updated before the system goes down  

---

