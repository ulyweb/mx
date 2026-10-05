#!/bin/bash
# =============================================================================
# mac_dfu_restore.sh  -  Apple silicon DFU restore from MX Linux / Debian (amd64)
# Tool : MAC-DFU-RESTORE  |  Engine: RestoreKit 0.5.10 (restore-kit .deb)
# Does : preflight -> install RestoreKit (checksum verified) -> udev rule ->
#        IPSW pick/download (resumable) -> wait for Mac in DFU -> launch GUI ->
#        plain-text log + telemetry HTML receipt.
# Audit: ~/Mac_DFU_Restore/<timestamp>_run/  (restore.log + receipt.html)
# WARNING: the restore ERASES the target Mac completely.
# Usage : chmod +x mac_dfu_restore.sh && ./mac_dfu_restore.sh
# =============================================================================
set -u

TOOL="MAC-DFU-RESTORE"
TS="$(date +%Y%m%d_%H%M%S)"
BASE="$HOME/Mac_DFU_Restore"
RUN="$BASE/${TS}_run"
IPSW_DIR="$BASE/ipsw"
mkdir -p "$RUN" "$IPSW_DIR" "$HOME/Downloads"
LOG="$RUN/restore.log"
STAGES="$RUN/stages.tsv"
: > "$STAGES"
exec > >(tee -a "$LOG") 2>&1

# ---- RestoreKit package (corporate pin: 0.5.10) ----
RK_VER="0.5.10"
RK_DEB="RestoreKit_${RK_VER}_amd64.deb"
RK_URL="https://github.com/fcjr/restorekit/releases/download/v${RK_VER}/${RK_DEB}"
RK_SHA256="ca57a35980adb3b586dcb316833be0fe6336cdcf14b867e20da10900d6b074b6"
UDEV_URL="https://raw.githubusercontent.com/fcjr/restorekit/main/udev/51-restorekit.rules"

# ---- IPSW catalog (Apple CDN links via mrmacintosh.com IPSW database) ----
IPSW_TAHOE_NAME="UniversalMac_26.6.2_25G83_Restore.ipsw"
IPSW_TAHOE_URL="https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw"
IPSW_GG_NAME="UniversalMac_27.0.1_26A434_Restore.ipsw"
IPSW_GG_URL="https://updates.cdn-apple.com/2026FallFCS/59241290-5d51-4ca8-9df4-31624b9a4eac/UniversalMac_27.0.1_26A434_Restore.ipsw"

START_EPOCH=$(date +%s)
OVERALL="PASS"
IPSW_LABEL="latest signed (RestoreKit downloads)"
IPSW_PATH=""
RESULT="NOT RECORDED"

# ---------------------------------------------------------------- helpers ----
say()  { printf '\n\033[1;33m== %s ==\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
bad()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; }
stage(){ # name status detail
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$STAGES"
  [ "$2" = "FAIL" ] && OVERALL="FAIL"
  [ "$2" = "WARN" ] && [ "$OVERALL" = "PASS" ] && OVERALL="WARN"
}
html_esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

finish() {
  local code="${1:-0}"
  local dur=$(( $(date +%s) - START_EPOCH ))
  write_receipt "$dur"
  echo
  echo "Log     : $LOG"
  echo "Receipt : $RUN/receipt.html"
  command -v xdg-open >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && xdg-open "$RUN/receipt.html" >/dev/null 2>&1 &
  exit "$code"
}

write_receipt() {
  local dur="$1" mins=$(( $1 / 60 )) secs=$(( $1 % 60 ))
  local pillclass="pass"; [ "$OVERALL" = "WARN" ] && pillclass="warn"; [ "$OVERALL" = "FAIL" ] && pillclass="fail"
  local rows="" n=0 name st detail cls
  while IFS=$'\t' read -r name st detail; do
    n=$((n+1))
    cls="pass"; [ "$st" = "WARN" ] && cls="warn"; [ "$st" = "FAIL" ] && cls="fail"
    rows="${rows}<tr style=\"animation-delay:${n}00ms\"><td>$(printf '%s' "$name" | html_esc)</td><td><span class=\"pill $cls\">$st</span></td><td>$(printf '%s' "$detail" | html_esc)</td></tr>"
  done < "$STAGES"
  cat > "$RUN/receipt.html" <<EOF
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>${TOOL} Receipt ${TS}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;font-family:Segoe UI,system-ui,sans-serif;color:#e9e6dc;background:radial-gradient(circle at 20% 10%,#1d1a10,#0a0a0d 60%);padding:32px}
.wrap{max-width:980px;margin:auto}
h1{font-size:28px;margin:0 0 6px;color:#d4af37;letter-spacing:1px}
.sub{color:#9a9684;font-size:13px;margin-bottom:18px}
.bar{height:4px;border-radius:4px;background:linear-gradient(90deg,transparent,#d4af37,transparent);background-size:200% 100%;animation:sh 2.5s linear infinite;margin-bottom:22px}
@keyframes sh{to{background-position:-200% 0}}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:14px;margin-bottom:22px}
.k{background:rgba(255,255,255,.04);backdrop-filter:blur(10px);border:1px solid rgba(212,175,55,.25);border-radius:14px;padding:16px;transition:.25s}
.k:hover{transform:translateY(-4px);box-shadow:0 0 22px rgba(212,175,55,.35)}
.k b{display:block;font-size:11px;letter-spacing:1.5px;color:#9a9684;margin-bottom:8px}.k span{font-size:20px;color:#d4af37}
.card{background:rgba(255,255,255,.04);backdrop-filter:blur(10px);border:1px solid rgba(212,175,55,.2);border-radius:14px;padding:6px 18px 14px}
table{width:100%;border-collapse:collapse;font-size:14px}th{text-align:left;color:#9a9684;font-size:11px;letter-spacing:1.5px;padding:12px 8px}
td{padding:11px 8px;border-top:1px solid rgba(255,255,255,.07);vertical-align:top}
tr{opacity:0;animation:fi .5s forwards}@keyframes fi{to{opacity:1}}
.pill{padding:3px 12px;border-radius:99px;font-size:12px;font-weight:700}
.pass{background:rgba(46,204,113,.15);color:#2ecc71;border:1px solid #2ecc71}
.warn{background:rgba(243,156,18,.15);color:#f39c12;border:1px solid #f39c12}
.fail{background:rgba(231,76,60,.15);color:#e74c3c;border:1px solid #e74c3c}
.foot{margin-top:18px;color:#7d7a6a;font-size:12px}
</style></head><body><div class="wrap">
<h1>${TOOL} // RECEIPT</h1>
<div class="sub">Host: $(hostname) &nbsp;|&nbsp; Run: ${TS} &nbsp;|&nbsp; User: $(whoami)</div>
<div class="bar"></div>
<div class="kpis">
<div class="k"><b>OVERALL</b><span class="pill ${pillclass}">${OVERALL}</span></div>
<div class="k"><b>RESTORE RESULT</b><span>${RESULT}</span></div>
<div class="k"><b>FIRMWARE</b><span style="font-size:13px">$(printf '%s' "$IPSW_LABEL" | html_esc)</span></div>
<div class="k"><b>ELAPSED</b><span>${mins}m ${secs}s</span></div>
<div class="k"><b>ENGINE</b><span>RestoreKit ${RK_VER}</span></div>
</div>
<div class="card"><table><thead><tr><th>STAGE</th><th>STATUS</th><th>DETAIL</th></tr></thead><tbody>
${rows}
</tbody></table></div>
<div class="foot">Plain-text log: ${LOG}</div>
</div></body></html>
EOF
}

trap 'echo; warn "Interrupted."; stage "Run" "WARN" "Interrupted by user"; RESULT="INTERRUPTED"; finish 130' INT TERM

echo "################################################################"
echo "#  ${TOOL}  |  Apple silicon DFU restore from Linux"
echo "#  Run: ${TS}   Host: $(hostname)   User: $(whoami)"
echo "################################################################"

# =========================================================== 1. PREFLIGHT ===
say "1/6  Preflight"
if [ "$(uname -m)" != "x86_64" ]; then bad "This launcher is for x86_64/amd64 only."; stage "Preflight" "FAIL" "Unsupported arch $(uname -m)"; RESULT="ABORTED"; finish 1; fi
command -v apt-get >/dev/null 2>&1 || { bad "apt-get not found (Debian/MX required)."; stage "Preflight" "FAIL" "No apt-get"; RESULT="ABORTED"; finish 1; }
for t in curl lsusb sha256sum; do
  if ! command -v "$t" >/dev/null 2>&1; then
    warn "Missing $t - installing prerequisites"
    sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y curl usbutils coreutils || { bad "prereq install failed"; stage "Preflight" "FAIL" "Prereq install failed"; RESULT="ABORTED"; finish 1; }
    break
  fi
done
sudo -v || { bad "sudo required."; stage "Preflight" "FAIL" "sudo unavailable"; RESULT="ABORTED"; finish 1; }
FREE_KB=$(df --output=avail -k "$IPSW_DIR" | tail -1)
if curl -sI --max-time 10 https://updates.cdn-apple.com >/dev/null 2>&1; then ok "Apple CDN reachable"; NET="Apple CDN reachable"; else warn "Apple CDN not reachable - check internet/proxy/firewall"; NET="Apple CDN NOT reachable"; fi
ok "Free space for IPSW: $((FREE_KB/1024/1024)) GB"
if [ "$FREE_KB" -lt 25000000 ]; then warn "Less than ~25 GB free - IPSW download may fail"; stage "Preflight" "WARN" "Low disk ($((FREE_KB/1024/1024)) GB free); $NET"; else stage "Preflight" "PASS" "x86_64, $((FREE_KB/1024/1024)) GB free; $NET"; fi

# ======================================================= 2. RESTOREKIT ======
say "2/6  RestoreKit install (v${RK_VER})"
if dpkg -s restore-kit >/dev/null 2>&1; then
  INSTALLED="$(dpkg -s restore-kit | awk '/^Version/{print $2}')"
  ok "restore-kit already installed ($INSTALLED)"
  stage "RestoreKit" "PASS" "Already installed ($INSTALLED)"
else
  curl -L -C - --retry 5 --retry-delay 5 -o "$HOME/Downloads/$RK_DEB" "$RK_URL" || { bad "RestoreKit download failed"; stage "RestoreKit" "FAIL" "Download failed"; RESULT="ABORTED"; finish 1; }
  GOT="$(sha256sum "$HOME/Downloads/$RK_DEB" | awk '{print $1}')"
  if [ "$GOT" != "$RK_SHA256" ]; then bad "Checksum mismatch ($GOT)"; stage "RestoreKit" "FAIL" "SHA-256 mismatch"; RESULT="ABORTED"; finish 1; fi
  ok "SHA-256 verified"
  sudo apt-get update -y >/dev/null 2>&1
  sudo apt-get install -y "$HOME/Downloads/$RK_DEB" || { bad "Install failed"; stage "RestoreKit" "FAIL" "apt install failed"; RESULT="ABORTED"; finish 1; }
  stage "RestoreKit" "PASS" "Installed $RK_VER, checksum verified"
fi

say "     USB permissions (udev)"
if [ -f /etc/udev/rules.d/51-restorekit.rules ] || [ -f /lib/udev/rules.d/51-restorekit.rules ] || [ -f /usr/lib/udev/rules.d/51-restorekit.rules ]; then
  ok "udev rule present"
  stage "udev rule" "PASS" "Already present"
else
  if curl -fsSL "$UDEV_URL" | sudo tee /etc/udev/rules.d/51-restorekit.rules >/dev/null; then
    ok "udev rule installed"; stage "udev rule" "PASS" "Installed from RestoreKit repo"
  else
    warn "Could not fetch udev rule; will rely on sudo"; stage "udev rule" "WARN" "Fetch failed"
  fi
fi
sudo udevadm control --reload-rules && sudo udevadm trigger

# ============================================================ 3. IPSW =======
say "3/6  Firmware (macOS) selection"
cat <<'MENU'
  1) macOS Tahoe 26.6.2         (newest Tahoe IPSW listed)   ~17 GB
  2) macOS Golden Gate 27.0.1   (latest, newest)             ~17 GB
  3) Let RestoreKit download "latest signed" itself
  4) I already have an IPSW file (enter path)
MENU
read -r -p "Select 1-4: " PICK
NAME=""; URL=""
case "$PICK" in
  1) NAME="$IPSW_TAHOE_NAME"; URL="$IPSW_TAHOE_URL"; IPSW_LABEL="macOS Tahoe 26.6.2 (25G83)" ;;
  2) NAME="$IPSW_GG_NAME";    URL="$IPSW_GG_URL";    IPSW_LABEL="macOS 27.0.1 (26A434)" ;;
  3) IPSW_LABEL="latest signed (RestoreKit downloads)"; stage "Firmware" "PASS" "RestoreKit will download latest signed" ;;
  4) read -r -p "Full path to .ipsw: " IPSW_PATH
     [ -f "$IPSW_PATH" ] || { bad "File not found: $IPSW_PATH"; stage "Firmware" "FAIL" "Local IPSW not found"; RESULT="ABORTED"; finish 1; }
     IPSW_LABEL="local: $(basename "$IPSW_PATH")"; stage "Firmware" "PASS" "Using local $(basename "$IPSW_PATH")" ;;
  *) bad "Invalid selection"; stage "Firmware" "FAIL" "Invalid menu choice"; RESULT="ABORTED"; finish 1 ;;
esac

if [ -n "$NAME" ]; then
  # reuse an existing copy from our dir, the older macos_ipsw dir, or Downloads
  for d in "$IPSW_DIR" "$HOME/Downloads/macos_ipsw" "$HOME/Downloads"; do
    [ -f "$d/$NAME" ] && { IPSW_PATH="$d/$NAME"; break; }
  done
  [ -n "$IPSW_PATH" ] || IPSW_PATH="$IPSW_DIR/$NAME"
  # wait if another curl is still writing an .ipsw
  while pgrep -f 'curl.*\.ipsw' >/dev/null 2>&1; do warn "Another IPSW download is still running - waiting 15s..."; sleep 15; done
  REMOTE="$(curl -sIL "$URL" | awk 'tolower($1)=="content-length:"{gsub("\r","");v=$2} END{print v}')"
  LOCAL=0; [ -f "$IPSW_PATH" ] && LOCAL="$(stat -c%s "$IPSW_PATH")"
  if [ -n "$REMOTE" ] && [ "$LOCAL" = "$REMOTE" ]; then
    ok "IPSW already complete: $IPSW_PATH"
  else
    echo "Downloading ${NAME} (resumable)..."
    curl -L -C - --retry 5 --retry-delay 5 -o "$IPSW_PATH" "$URL" || { bad "IPSW download failed - re-run to resume"; stage "Firmware" "FAIL" "Download failed"; RESULT="ABORTED"; finish 1; }
    LOCAL="$(stat -c%s "$IPSW_PATH")"
    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then bad "Size mismatch ($LOCAL vs $REMOTE) - re-run to resume"; stage "Firmware" "FAIL" "Size mismatch"; RESULT="ABORTED"; finish 1; fi
    ok "Download verified by size ($LOCAL bytes)"
  fi
  stage "Firmware" "PASS" "$NAME ready ($((LOCAL/1024/1024)) MB)"
fi

# ============================================================ 4. DFU ========
say "4/6  Put the Mac in DFU mode"
cat <<'DFU'
  1. Shut the MacBook Pro fully DOWN. Plug MagSafe power in.
  2. Connect a USB-C DATA cable: Mac LEFT-side port NEXT TO MAGSAFE -> this PC
     (no hubs/docks; try a USB-A to USB-C cable if C-to-C is not detected).
  3. Hold POWER + RIGHT Shift + LEFT Control + LEFT Option for ~10 seconds,
     then release the three keys but KEEP HOLDING POWER ~5 more seconds.
     The Mac screen stays black - that is normal.
DFU
DFU_OK=0
for attempt in 1 2 3; do
  echo; echo "Attempt $attempt/3 - waiting up to 120 s for the Mac in DFU..."
  SEEN_NONDFU=0; T=0
  while [ "$T" -lt 120 ]; do
    L="$(lsusb -d 05ac: 2>/dev/null)"
    if printf '%s' "$L" | grep -qi "DFU"; then DFU_OK=1; break; fi
    if [ -n "$L" ] && [ "$SEEN_NONDFU" = "0" ]; then warn "Apple device present but NOT DFU: $(printf '%s' "$L" | head -1)  -> redo the key sequence"; SEEN_NONDFU=1; fi
    sleep 2; T=$((T+2))
  done
  [ "$DFU_OK" = "1" ] && break
  warn "Not detected."
  echo "--- diagnostics ---"; lsusb; sudo dmesg | tail -8
  echo "Fixes: data-capable cable | USB-A to USB-C | other PC port | other left Mac port | power via MagSafe | redo keys"
  [ "$attempt" -lt 3 ] && read -r -p "Fix it, then press Enter to retry (or Ctrl+C to quit)... " _
done
if [ "$DFU_OK" != "1" ]; then bad "Mac never entered DFU."; stage "DFU detect" "FAIL" "Not detected after 3 attempts"; RESULT="NOT STARTED"; finish 1; fi
DFU_LINE="$(lsusb -d 05ac: | grep -i DFU | head -1)"
ok "DFU confirmed: $DFU_LINE"
stage "DFU detect" "PASS" "$DFU_LINE"

# ======================================================= 5. LAUNCH GUI ======
say "5/6  Launch RestoreKit"
DESKTOP_FILE=""
for f in $(dpkg -L restore-kit 2>/dev/null); do case "$f" in *.desktop) DESKTOP_FILE="$f"; break ;; esac; done
LAUNCHED=0
if [ -n "$DESKTOP_FILE" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  EXEC_CMD="$(grep -m1 '^Exec=' "$DESKTOP_FILE" | sed -e 's/^Exec=//' -e 's/ %[A-Za-z]//g')"
  if [ -n "$EXEC_CMD" ]; then nohup $EXEC_CMD >/dev/null 2>&1 & LAUNCHED=1; fi
fi
if [ "$LAUNCHED" = "1" ]; then ok "RestoreKit window launched"; stage "RestoreKit GUI" "PASS" "Launched from $DESKTOP_FILE"
else warn "Could not auto-launch - open RestoreKit from the application menu"; stage "RestoreKit GUI" "WARN" "Manual launch required"; fi

echo
echo "  +------------------------------ IN THE RESTOREKIT WINDOW ------------------------------+"
echo "  | 1. Select your Mac under Targets (shows 'DFU, ready to restore').                    |"
if [ -n "$IPSW_PATH" ]; then
echo "  | 2. Local IPSW -> browse -> choose:                                                   |"
echo "  |      $IPSW_PATH"
else
echo "  | 2. Leave 'macOS ver.' = latest signed (RestoreKit downloads ~17 GB).                 |"
fi
echo "  | 3. Mode = Erase & restore  (NOT Obliterate).                                          |"
echo "  | 4. Click 'Erase & restore' and confirm. Do NOT unplug anything for ~20-40 min.        |"
echo "  +--------------------------------------------------------------------------------------+"
for c in "xclip -selection clipboard" "xsel -ib" "wl-copy"; do
  if [ -n "$IPSW_PATH" ] && command -v "${c%% *}" >/dev/null 2>&1; then printf '%s' "$IPSW_PATH" | $c 2>/dev/null && ok "IPSW path copied to clipboard (paste in the file dialog)" && break; fi
done

# ======================================================= 6. RESULT ==========
say "6/6  Record the result"
echo "Wait until RestoreKit reports completion and the Mac reboots to Setup Assistant."
read -r -p "Result?  [s] success   [f] failed   [q] quit/not finished : " R
case "$R" in
  s|S) RESULT="SUCCESS"; stage "Restore" "PASS" "Operator confirmed success; Mac reached Setup Assistant" ;;
  f|F) read -r -p "Short failure note: " NOTE; RESULT="FAILED"; stage "Restore" "FAIL" "Operator reported failure: ${NOTE:-no note}" ;;
  *)   RESULT="NOT FINISHED"; stage "Restore" "WARN" "Operator exited before completion" ;;
esac
[ "$RESULT" = "SUCCESS" ] && echo "If Activation Lock / MDM enrollment appears, that is Apple ID / Jamf - the restore cannot bypass it."
finish 0
