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



> [!TIP]
> ## Firefox’s settings *can* be automated**, and **Chromium browsers can be partially automated**, but with some limits.
>> Let’s break this down cleanly so you know exactly what’s possible and how to do it.

---

# 🦊 **Firefox: Fully Automatable (via policies.json + user.js)**

Firefox is the *only* browser that exposes nearly every setting through:

- **Enterprise Policies** (`/etc/firefox/policies/policies.json`)
- **User preferences** (`user.js` inside your Firefox profile)

Between these two, you can automate **almost everything you listed**.

---

# ⭐ What You Want to Disable (Firefox)

You mentioned:

### **Home → Interaction**
- Turn off all options

### **Home → Firefox Home Content**
- Web Search  
- Weather  
- Shortcuts  
- Recommended Stories  
- Support Firefox  

### **Search → Search Suggestions**
- All off

### **Search → Firefox Suggest**
- All off

### **Privacy & Security**
- Password saving off  
- Payment methods off  
- Addresses & more off  
- Firefox data collection off  

All of these map to Firefox preferences.

---

# 🐍 **Python Script to Apply All Firefox Settings Automatically**

This script:

- Writes a `policies.json` for enterprise-level settings  
- Writes a `user.js` to enforce all your personal preferences  
- Works system-wide on MX Linux  

```python
#!/usr/bin/env python3
import os
import json
import subprocess

# -----------------------------
# 1. Firefox Enterprise Policies
# -----------------------------
policies_dir = "/etc/firefox/policies"
policies_file = os.path.join(policies_dir, "policies.json")

policies = {
    "policies": {
        "DisableFirefoxStudies": True,
        "DisableTelemetry": True,
        "DisablePocket": True,
        "DisableFirefoxAccounts": False,
        "OfferToSaveLogins": False,
        "PasswordManagerEnabled": False,
        "DisableFormHistory": True,
        "DisableFeedbackCommands": True,
        "DisableSystemAddonUpdate": True,
        "DisableAppUpdate": False,
        "Extensions": {
            "Install": [
                "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
                "https://addons.mozilla.org/firefox/downloads/latest/ghostery/latest.xpi"
            ]
        }
    }
}

os.makedirs(policies_dir, exist_ok=True)
with open(policies_file, "w") as f:
    json.dump(policies, f, indent=4)

print("[OK] Firefox enterprise policies applied")

# -----------------------------
# 2. Firefox user.js preferences
# -----------------------------
# Find Firefox profile directory
profile_root = os.path.expanduser("~/.mozilla/firefox")
profiles = [p for p in os.listdir(profile_root) if p.endswith(".default") or p.endswith(".default-release")]

if not profiles:
    print("No Firefox profile found.")
    exit(1)

profile_path = os.path.join(profile_root, profiles[0])
userjs_path = os.path.join(profile_path, "user.js")

prefs = {
    # Home → Interaction
    "browser.newtabpage.activity-stream.feeds.section.topstories": False,
    "browser.newtabpage.activity-stream.feeds.topsites": False,
    "browser.newtabpage.activity-stream.feeds.weatherfeed": False,
    "browser.newtabpage.activity-stream.showSearch": False,
    "browser.newtabpage.activity-stream.showSponsored": False,
    "browser.newtabpage.activity-stream.showSponsoredTopSites": False,

    # Search suggestions
    "browser.search.suggest.enabled": False,
    "browser.urlbar.suggest.searches": False,
    "browser.urlbar.suggest.quicksuggest.nonsponsored": False,
    "browser.urlbar.suggest.quicksuggest.sponsored": False,

    # Passwords
    "signon.rememberSignons": False,
    "signon.autofillForms": False,

    # Payment & autofill
    "dom.payments.request.enabled": False,
    "extensions.formautofill.addresses.enabled": False,
    "extensions.formautofill.creditCards.enabled": False,

    # Firefox data collection
    "datareporting.healthreport.uploadEnabled": False,
    "toolkit.telemetry.enabled": False,
    "toolkit.telemetry.unified": False,
    "toolkit.telemetry.archive.enabled": False,
    "toolkit.telemetry.server": "",
    "toolkit.telemetry.newProfilePing.enabled": False,
    "toolkit.telemetry.shutdownPingSender.enabled": False,
    "toolkit.telemetry.updatePing.enabled": False,
    "toolkit.telemetry.bhrPing.enabled": False,
    "toolkit.telemetry.firstShutdownPing.enabled": False,
}

with open(userjs_path, "w") as f:
    for key, value in prefs.items():
        if isinstance(value, bool):
            f.write(f'user_pref("{key}", {str(value).lower()});\n')
        else:
            f.write(f'user_pref("{key}", "{value}");\n')

print(f"[OK] Firefox user.js written to {userjs_path}")
print("Restart Firefox to apply all settings.")
```

---

# 🧊 **Chromium Browsers (Brave, Chrome, Edge, Vivaldi)**

Here’s the honest truth:

### ✔️ What *can* be automated
- Extensions (you already have this working)
- Password manager off
- Autofill off
- Payment methods off
- Telemetry off
- Safe browsing settings
- Default search engine
- Homepage / new tab page

### ❌ What *cannot* be automated
Chromium does **not** expose:

- UI toggles like “Show weather on new tab”
- Recommendation toggles
- Suggestion toggles
- Interaction settings
- Per-user content settings

These are stored in an internal SQLite database and JSON files that change constantly.  
Automating them is possible but **fragile** and breaks on updates.

If you want, I can still generate a script that edits:

```
~/.config/<browser>/Default/Preferences
```

…but I’ll warn you:  
**Chromium overwrites this file on exit**, so automation is unreliable.

Firefox is the only browser that supports full configuration automation cleanly.

---

### Combined automation script for Firefox + Chromium browsers

Here’s a single Python script that:

- Forces install of uBlock Origin + Ghostery in **Firefox, Chrome, Brave, Edge, Vivaldi**
- Applies your **privacy/UX preferences in Firefox** (via `policies.json` + `user.js`)
- Applies **partial privacy settings in Chromium browsers** (passwords, autofill, payments, suggestions, telemetry) via policies

---

#### 1. Save this as `browser_setup.py`

```python
#!/usr/bin/env python3
import os
import json
import glob

# -----------------------------
# 1. Chromium-based browsers
# -----------------------------

chromium_browsers = {
    "google-chrome": "/etc/opt/chrome/policies/managed",
    "brave-browser": "/etc/brave/policies/managed",
    "microsoft-edge": "/etc/opt/edge/policies/managed",
    "vivaldi": "/etc/vivaldi/policies/managed",
}

# Chrome extension IDs
chromium_extensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm",  # uBlock Origin
    "mlomiejdfkolichcflejclcbmpeaniij",  # Ghostery
]

chromium_policy = {
    "ExtensionInstallForcelist": chromium_extensions,
    # Passwords / autofill / payments
    "PasswordManagerEnabled": False,
    "AutofillAddressEnabled": False,
    "AutofillCreditCardEnabled": False,
    "PaymentMethodQueryEnabled": False,
    # Suggestions / data collection
    "SearchSuggestEnabled": False,
    "URLKeyedAnonymizedDataCollectionEnabled": False,
    "MetricsReportingEnabled": False,
}

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def apply_chromium_policies():
    for name, path in chromium_browsers.items():
        ensure_dir(path)
        policy_file = os.path.join(path, "browser_policies.json")
        with open(policy_file, "w") as f:
            json.dump(chromium_policy, f, indent=4)
        print(f"[OK] Chromium policy applied for {name} → {policy_file}")

# -----------------------------
# 2. Firefox enterprise policies
# -----------------------------

firefox_policies_dir = "/etc/firefox/policies"
firefox_policies_file = os.path.join(firefox_policies_dir, "policies.json")

firefox_policies = {
    "policies": {
        # Extensions
        "Extensions": {
            "Install": [
                "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
                "https://addons.mozilla.org/firefox/downloads/latest/ghostery/latest.xpi",
            ]
        },
        # Passwords / form history
        "OfferToSaveLogins": False,
        "PasswordManagerEnabled": False,
        "DisableFormHistory": True,
        # Telemetry / data collection
        "DisableTelemetry": True,
        "DisableFirefoxStudies": True,
        "DisablePocket": True,
    }
}

def apply_firefox_policies():
    ensure_dir(firefox_policies_dir)
    with open(firefox_policies_file, "w") as f:
        json.dump(firefox_policies, f, indent=4)
    print(f"[OK] Firefox policies.json written → {firefox_policies_file}")

# -----------------------------
# 3. Firefox user.js preferences
# -----------------------------

def find_firefox_profiles():
    root = os.path.expanduser("~/.mozilla/firefox")
    if not os.path.isdir(root):
        return []
    # Match default profiles
    patterns = ["*.default", "*.default-release", "*.default-esr"]
    profiles = []
    for pattern in patterns:
        profiles.extend(glob.glob(os.path.join(root, pattern)))
    return profiles

firefox_prefs = {
    # Home → Firefox Home Content / Interaction
    "browser.newtabpage.activity-stream.showSearch": False,
    "browser.newtabpage.activity-stream.feeds.section.topstories": False,
    "browser.newtabpage.activity-stream.feeds.topsites": False,
    "browser.newtabpage.activity-stream.feeds.weatherfeed": False,
    "browser.newtabpage.activity-stream.showSponsored": False,
    "browser.newtabpage.activity-stream.showSponsoredTopSites": False,
    "browser.newtabpage.activity-stream.showWeather": False,
    "browser.newtabpage.activity-stream.showRecentSearches": False,
    "browser.newtabpage.activity-stream.showRecentSaves": False,

    # Search suggestions
    "browser.search.suggest.enabled": False,
    "browser.urlbar.suggest.searches": False,
    "browser.urlbar.suggest.quicksuggest.nonsponsored": False,
    "browser.urlbar.suggest.quicksuggest.sponsored": False,
    "browser.urlbar.suggest.bookmark": False,
    "browser.urlbar.suggest.history": False,
    "browser.urlbar.suggest.openpage": False,

    # Passwords
    "signon.rememberSignons": False,
    "signon.autofillForms": False,

    # Payment & autofill
    "dom.payments.request.enabled": False,
    "extensions.formautofill.addresses.enabled": False,
    "extensions.formautofill.creditCards.enabled": False,

    # Firefox data collection and telemetry
    "datareporting.healthreport.uploadEnabled": False,
    "toolkit.telemetry.enabled": False,
    "toolkit.telemetry.unified": False,
    "toolkit.telemetry.archive.enabled": False,
    "toolkit.telemetry.server": "",
    "toolkit.telemetry.newProfilePing.enabled": False,
    "toolkit.telemetry.shutdownPingSender.enabled": False,
    "toolkit.telemetry.updatePing.enabled": False,
    "toolkit.telemetry.bhrPing.enabled": False,
    "toolkit.telemetry.firstShutdownPing.enabled": False,
    "browser.ping-centre.telemetry": False,
}

def apply_firefox_userjs():
    profiles = find_firefox_profiles()
    if not profiles:
        print("[WARN] No Firefox profile found under ~/.mozilla/firefox")
        return

    for profile in profiles:
        userjs_path = os.path.join(profile, "user.js")
        with open(userjs_path, "w") as f:
            for key, value in firefox_prefs.items():
                if isinstance(value, bool):
                    f.write(f'user_pref("{key}", {str(value).lower()});\n')
                else:
                    f.write(f'user_pref("{key}", "{value}");\n')
        print(f"[OK] Firefox user.js written → {userjs_path}")

# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    print("Applying Chromium policies...")
    apply_chromium_policies()
    print("\nApplying Firefox policies...")
    apply_firefox_policies()
    print("\nApplying Firefox user.js preferences...")
    apply_firefox_userjs()
    print("\nAll done. Restart each browser to see changes.")
```

---

#### 2. Run it with sudo

From the folder where you saved it:

```bash
sudo chmod +x browser_setup.py
sudo ./browser_setup.py
```

Then fully close and reopen each browser.

---

