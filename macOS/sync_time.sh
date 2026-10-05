#!/bin/bash
# Check and fix system clock before running the macOS installer
echo "Current date: $(date)"
echo "Trying network time sync..."
/usr/sbin/ntpdate -u time.apple.com 2>&1 || sntp -sS time.apple.com 2>&1 || echo "Network sync unavailable."
echo "Date now: $(date)"
echo
echo "If the date above is NOT today (Oct 5 2026), set it manually."
echo "Format: date MMDDhhmmYY  (24-hour clock, local time)"
echo "Example for Oct 5 2026 at 2:30 PM:  date 1005143026"
