#!/bin/bash

# 1. Core System Dependencies Check
MISSING_APT=""

if ! command -v zenity &> /dev/null; then MISSING_APT="$MISSING_APT zenity"; fi
if ! command -v ffmpeg &> /dev/null; then MISSING_APT="$MISSING_APT ffmpeg"; fi
if ! command -v python3 &> /dev/null; then MISSING_APT="$MISSING_APT python3"; fi
if ! command -v wget &> /dev/null; then MISSING_APT="$MISSING_APT wget"; fi

if [ -n "$MISSING_APT" ]; then
    echo "Missing core system packages:$MISSING_APT"
    echo "Installing now. Please enter your sudo password if prompted..."
    sudo apt update && sudo apt install -y $MISSING_APT
fi

# 2. Explicit Path Check and Impersonation GUI Prompt
YTDLP_PATH="/usr/local/bin/yt-dlp"

if [ ! -f "$YTDLP_PATH" ]; then
    # Prompt to install if not found in the explicit path
    if zenity --question --title="Missing yt-dlp" --text="yt-dlp was not found in $YTDLP_PATH.\n\nWould you like to download and install the standalone binary now?" --width=400; then
        echo "Downloading yt-dlp standalone binary..."
        sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O "$YTDLP_PATH"
        sudo chmod a+rx "$YTDLP_PATH"
    else
        echo "Installation cancelled."
        exit 1
    fi
else
    # Prompt the user to verify impersonation targets
    if zenity --question --title="Verify Impersonation" --text="yt-dlp is installed at $YTDLP_PATH.\n\nWould you like to test if it supports Chrome impersonation?" --width=400; then
        if ! "$YTDLP_PATH" --list-impersonate-targets | grep -iq "chrome"; then
            if zenity --question --title="Impersonation Missing" --text="Your yt-dlp does NOT support Chrome impersonation.\n\nWould you like to overwrite it with the fully loaded standalone binary?" --width=450; then
                echo "Overwriting yt-dlp..."
                sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O "$YTDLP_PATH"
                sudo chmod a+rx "$YTDLP_PATH"
                zenity --info --title="Success" --text="yt-dlp updated successfully." --width=300
            fi
        else
            zenity --info --title="All Good" --text="Chrome impersonation is fully supported!" --width=300
        fi
    fi
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
    "$YTDLP_PATH" --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ "$URL"
elif [ "$CHOICE" == "Audio (MP3)" ]; then
    "$YTDLP_PATH" --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ --extract-audio --audio-format mp3 --audio-quality 0 "$URL"
fi

# 7. Completion Notification
zenity --info --title="Download Complete" --text="Successfully saved to ~/Templates/yt/" --width=300
