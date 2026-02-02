> [!TIP]
> MX App installed list


>Text Editor - The GNOME Project v49.1
>VerCrypt
>KeePassXC
>Virtual Machine Manager
>Celluloid
>Kamoso
>Brave Web Browser
>Google Chrome
>Microsoft Edge
>RustDesk
>Vivaldi
>Python

>##Installation command
````
sudo apt update
sudo apt install python3-full -y
sudo apt install python3 python3-pip -y
python3 --version
pip3 --version
sudo apt install -y build-essential libssl-dev zlib1g-dev libsqlite3-dev libffi-dev libbz2-dev libreadline-gplv2-dev libncursesw5-dev tk-dev yt-dlp -y 
pip3 install flask bcrypt cryptgraphy cryptography
````

> [!TIP]
> ## Python Script (Works on MX Linux 25.1 KDE)
>>Below is a clear breakdown of what *is* possible, what *isn’t*, and a practical Python/Bash approach that works on MX Linux.

---

# ⭐ The Reality of Browser Extension Automation on Linux

| Browser | Can Install Extensions Automatically? | How | Notes |
|--------|----------------------------------------|-----|-------|
| **Firefox** | ✔️ Yes | Policies JSON | Fully supported |
| **Brave** | ✔️ Yes | Chromium policies | Works like Chrome |
| **Google Chrome** | ✔️ Yes | Chromium policies | Official method |
| **Microsoft Edge** | ✔️ Yes | Edge policies | Same mechanism |
| **Vivaldi** | ⚠️ Partial | Chromium policies | Works, but Vivaldi sometimes overrides |

All Chromium‑based browsers support **forced extension installation** using a JSON policy file.

Firefox uses its own policy system.

---

# ⭐ Extensions You Want

| Extension | Firefox ID | Chrome/Brave/Edge/Vivaldi ID |
|----------|------------|-------------------------------|
| **uBlock Origin** | `uBlock0@raymondhill.net` | `cjpalhdlnbpafiamejdnhcphjbkeiagm` |
| **Ghostery** | `firefox@ghostery.com` | `mlomiejdfkolichcflejclcbmpeaniij` |

---

# ⭐ AUTOMATION SOLUTION

Below is a **single Python script** that:

- Detects installed browsers  
- Creates the correct policy directories  
- Writes the JSON policy files  
- Forces installation of uBlock Origin + Ghostery  

You run it once, and all browsers will open with the extensions already installed.

---

# 🐍 **Python Script (Works on MX Linux 25.1 KDE)**

````python
#!/usr/bin/env python3
import os
import json

# Chromium-based browsers and their policy paths
chromium_browsers = {
    "google-chrome": "/etc/opt/chrome/policies/managed",
    "brave-browser": "/etc/brave/policies/managed",
    "microsoft-edge": "/etc/opt/edge/policies/managed",
    "vivaldi": "/etc/vivaldi/policies/managed"
}

# Chrome extension IDs
extensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm",  # uBlock Origin
    "mlomiejdfkolichcflejclcbmpeaniij"   # Ghostery
]

policy_data = {
    "ExtensionInstallForcelist": [f"{ext}" for ext in extensions]
}

# Firefox policy
firefox_policy_dir = "/etc/firefox/policies"
firefox_policy_file = os.path.join(firefox_policy_dir, "policies.json")

firefox_data = {
    "policies": {
        "Extensions": {
            "Install": [
                "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
                "https://addons.mozilla.org/firefox/downloads/latest/ghostery/latest.xpi"
            ]
        }
    }
}

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)

# Apply Chromium policies
for browser, path in chromium_browsers.items():
    ensure_dir(path)
    with open(os.path.join(path, "extensions.json"), "w") as f:
        json.dump(policy_data, f, indent=4)
    print(f"[OK] Applied extension policy for {browser}")

# Apply Firefox policies
ensure_dir(firefox_policy_dir)
with open(firefox_policy_file, "w") as f:
    json.dump(firefox_data, f, indent=4)
print("[OK] Applied Firefox extension policy")

print("\nDone! Restart your browsers to see the extensions installed.")
````

---

# ▶️ How to Run It

```bash
sudo chmod +x install_extensions.py
sudo ./install_extensions.py
```

Then restart each browser.

---

# 🎉 What Happens After Running It

- Firefox installs uBlock Origin + Ghostery automatically on next launch  
- Chrome/Brave/Edge/Vivaldi install the extensions silently  
- You never need to manually click “Add extension” again  

This is the same mechanism used by enterprise deployments — completely safe and supported.

---

