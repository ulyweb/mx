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


## Python Script (Works on MX Linux 25.1 KDE)

````
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

## How to run it

````

sudo chmod +x install_extensions.py
sudo ./install_extensions.py

````
