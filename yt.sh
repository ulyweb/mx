#!/bin/bash

# 1. Dependency Checks & Auto-Install
MISSING_APT=""

# Check for GUI tool (Zenity), Python, and Audio converter (FFmpeg)
if ! command -v zenity &> /dev/null; then MISSING_APT="$MISSING_APT zenity"; fi
if ! command -v ffmpeg &> /dev/null; then MISSING_APT="$MISSING_APT ffmpeg"; fi
if ! command -v python3 &> /dev/null; then MISSING_APT="$MISSING_APT python3"; fi

# If any apt packages are missing, force install them
if [ -n "$MISSING_APT" ]; then
    echo "Missing required system packages:$MISSING_APT"
    echo "Forcing installation now. Please enter your sudo password if prompted."
    sudo apt update && sudo apt install -y $MISSING_APT
fi

# Check if yt-dlp is missing, and download the standalone binary if so
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp is missing. Forcing installation of the latest standalone binary..."
    sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
fi

# 2. GUI Selection for Format (Video vs Audio)
CHOICE=$(zenity --list --radiolist \
    --title="yt-dlp Downloader" \
    --text="What would you like to download?" \
    --column="Select" --column="Format" \
    TRUE "Video (Default)" \
    FALSE "Audio (MP3)" \
    --width=350 --height=200)

# Exit cleanly if the user clicks Cancel or closes the window
if [ -z "$CHOICE" ]; then
    echo "Cancelled format selection."
    exit 0
fi

# 3. GUI Input for URL
URL=$(zenity --entry \
    --title="yt-dlp Downloader" \
    --text="Paste the media URL here:" \
    --width=500)

# Exit cleanly if the user clicks Cancel or leaves the box blank
if [ -z "$URL" ]; then
    echo "Cancelled URL input."
    exit 0
fi

# 4. Prepare Output Directory
mkdir -p ~/Templates/yt/
echo "Downloading to ~/Templates/yt/..."

# 5. Execute Download Based on Choice
if [ "$CHOICE" == "Video (Default)" ]; then
    yt-dlp --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ "$URL"
elif [ "$CHOICE" == "Audio (MP3)" ]; then
    # --extract-audio and --audio-format mp3 convert the stream, --audio-quality 0 forces the highest VBR
    yt-dlp --cookies-from-browser brave --impersonate chrome -P ~/Templates/yt/ --extract-audio --audio-format mp3 --audio-quality 0 "$URL"
fi

# 6. Completion Notification
zenity --info --title="Download Complete" --text="Successfully saved to ~/Templates/yt/" --width=300
