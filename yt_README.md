If the system already has a broken, outdated, or default apt version of `yt-dlp` installed, the previous script would just see that it exists and skip the installation—even if it was missing the required Python addons for impersonation.

To make this completely bulletproof, we will update the script to actively test if the installed `yt-dlp` can *actually* perform browser impersonation. If it fails that test, or if it doesn't exist at all, the script will force-download the fully loaded standalone binary directly into `/usr/local/bin/` so it is permanently accessible system-wide. We will also add `wget` to the core apps check.

Here is the fully comprehensive script.

1. **Open the script for editing:**
Open your existing file again:

```bash
sudo nano /usr/local/bin/yt

```


2. **Replace with the bulletproof code:**
Delete the old contents and paste this thoroughly hardened version:

```bash
#!/bin/bash

# 1. Core System Dependencies Check
MISSING_APT=""

# Check for GUI tool, Audio converter, Python, and download tools
if ! command -v zenity &> /dev/null; then MISSING_APT="$MISSING_APT zenity"; fi
if ! command -v ffmpeg &> /dev/null; then MISSING_APT="$MISSING_APT ffmpeg"; fi
if ! command -v python3 &> /dev/null; then MISSING_APT="$MISSING_APT python3"; fi
if ! command -v wget &> /dev/null; then MISSING_APT="$MISSING_APT wget"; fi

# Force install missing core apt packages
if [ -n "$MISSING_APT" ]; then
    echo "Missing core system packages:$MISSING_APT"
    echo "Installing now. Please enter your sudo password if prompted..."
    sudo apt update && sudo apt install -y $MISSING_APT
fi

# 2. yt-dlp & Python Addon (Impersonation) Check
NEEDS_YTDLP=false

if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp is not installed."
    NEEDS_YTDLP=true
else
    # Test if the installed yt-dlp actually has the curl_cffi Python addon required for impersonation
    if ! yt-dlp --list-impersonate-targets | grep -iq "chrome"; then
        echo "Existing yt-dlp is missing the python dependencies for impersonation."
        NEEDS_YTDLP=true
    fi
fi

# Force install the fully loaded standalone binary globally if needed
if [ "$NEEDS_YTDLP" = true ]; then
    echo "Installing the fully loaded standalone yt-dlp binary to /usr/local/bin/..."
    sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
fi

# 3. GUI Selection for Format (Video vs Audio)
CHOICE=$(zenity --list --radiolist \
    --title="yt-dlp Downloader" \
    --text="What would you like to download?" \
    --column="Select" --column="Format" \
    TRUE "Video (Default)" \
    FALSE "Audio (MP3)" \
    --width=350 --height=200)

if [ -z "$CHOICE" ]; then
    echo "Cancelled format selection."
    exit 0
fi

# 4. GUI Input for URL
URL=$(zenity --entry \
    --title="yt-dlp Downloader" \
    --text="Paste the media URL here:" \
    --width=500)

if [ -z "$URL" ]; then
    echo "Cancelled URL input."
    exit 0
fi

# 5. Prepare Output Directory
mkdir -p ~/Templates/yt/
echo "Downloading to ~/Templates/yt/..."

# 6. Execute Download Based on Choice
if [ "$CHOICE" == "Video (Default)" ]; then
    yt-dlp --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ "$URL"
elif [ "$CHOICE" == "Audio (MP3)" ]; then
    yt-dlp --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ --extract-audio --audio-format mp3 --audio-quality 0 "$URL"
fi

# 7. Completion Notification
zenity --info --title="Download Complete" --text="Successfully saved to ~/Templates/yt/" --width=300

```

*Save and exit by pressing `Ctrl+O`, `Enter`, and then `Ctrl+X`.*


By adding `yt-dlp --list-impersonate-targets | grep -iq "chrome"`, the script now verifies that the Python environment and its addons (`curl_cffi`) are fully intact. If that command fails for any reason, it overwrites the bad file with the correct standalone binary directly in `/usr/local/bin/`.
