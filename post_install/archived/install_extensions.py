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
