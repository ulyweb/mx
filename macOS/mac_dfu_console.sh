#!/bin/bash
# =============================================================================
# mac_dfu_console.sh - Smart preflight + auto-fix + dashboard launcher
# Tool  : MAC-DFU-CONSOLE   |  MX Linux / Debian (amd64)
# Does  : 1) SCANS everything the restore needs (RestoreKit package + .deb,
#            udev rule, required tools, *Restore.ipsw files, check_dfu.sh,
#            mac_dfu_restore.sh, network, disk, Apple device on USB)
#         2) FIXES what is missing (checksum-verified RestoreKit install,
#            udev rule, check_dfu.sh / restore launcher extracted from the
#            dashboard, missing tools) - asks once, or use --yes
#         3) WRITES preflight.json (+ SHA-256), a plain-text log and an HTML
#            receipt, then OPENS the dashboard with the results embedded so it
#            shows READY / NOT READY the moment it opens, with audit entries.
# Audit : ~/Mac_DFU_Restore/<timestamp>_preflight/
# Usage : chmod +x mac_dfu_console.sh && ./mac_dfu_console.sh [options]
#   --scan-only        report only; change nothing
#   --yes              apply fixes without asking
#   --get-ipsw 1|2     also download an IPSW (1 = Tahoe 26.6.2, 2 = 27.0.1)
#   --html PATH        path to Mac_DFU_Restore_Dashboard.html (auto-found if omitted)
#   --no-open          do not open the dashboard
#   --help
# Nothing is transmitted; network is used only to reach Apple's CDN / GitHub.
# =============================================================================
set -u

TOOL="MAC-DFU-CONSOLE"
CON_VER="1.0.0"
TS="$(date +%Y%m%d_%H%M%S)"
BASE="$HOME/Mac_DFU_Restore"
BIN="$BASE/bin"
IPSW_DIR="$BASE/ipsw"
RUN="$BASE/${TS}_preflight"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
mkdir -p "$BIN" "$IPSW_DIR" "$RUN"
LOG="$RUN/preflight.log"
exec > >(tee -a "$LOG") 2>&1

# keep a copy of this script in ~/Mac_DFU_Restore/bin so it can be re-run any time
SELF="${BASH_SOURCE[0]:-$0}"
if [ -f "$SELF" ]; then
  SELF_ABS="$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")"
  [ "$SELF_ABS" != "$BIN/mac_dfu_console.sh" ] && cp -f "$SELF_ABS" "$BIN/mac_dfu_console.sh" 2>/dev/null && chmod +x "$BIN/mac_dfu_console.sh"
fi

MODE="fix"; ASSUME_YES=0; NOOPEN=0; HTML=""; GET_IPSW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scan-only) MODE="scan" ;;
    --yes|-y) ASSUME_YES=1 ;;
    --no-open) NOOPEN=1 ;;
    --html) shift; HTML="${1:-}" ;;
    --get-ipsw) shift; GET_IPSW="${1:-}" ;;
    --help|-h) sed -n '2,28p' "${BASH_SOURCE[0]:-$0}"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
  esac
  shift
done

# ---- pins (corporate-approved versions, not vendor-latest) ----
RK_VER="0.5.10"
RK_DEB="RestoreKit_${RK_VER}_amd64.deb"
RK_URL="https://github.com/fcjr/restorekit/releases/download/v${RK_VER}/${RK_DEB}"
RK_SHA256="ca57a35980adb3b586dcb316833be0fe6336cdcf14b867e20da10900d6b074b6"
UDEV_URL="https://raw.githubusercontent.com/fcjr/restorekit/main/udev/51-restorekit.rules"
IPSW_TAHOE_NAME="UniversalMac_26.6.2_25G83_Restore.ipsw"
IPSW_TAHOE_URL="https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw"
IPSW_GG_NAME="UniversalMac_27.0.1_26A434_Restore.ipsw"
IPSW_GG_URL="https://updates.cdn-apple.com/2026FallFCS/59241290-5d51-4ca8-9df4-31624b9a4eac/UniversalMac_27.0.1_26A434_Restore.ipsw"
# placeholder tokens are split so this script never contains them contiguously
TOK_DATA="__PREFLIGHT_""DATA__"
TOK_SHA="__PREFLIGHT_""SHA__"

SEP=$'\x1f'
START_EPOCH=$(date +%s)
CHECKS=(); FILES=(); NET_OK=0
declare -A PRE

# ---------------------------------------------------------------- helpers ----
say()  { printf '\n\033[1;33m== %s ==\033[0m\n' "$*"; }
note() { printf '\033[0;36m%s\033[0m\n' "$*"; }
rel()  { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
jstr() { printf '%s' "$1" | tr '\n\t\r' '   ' | tr -d '\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
add() { # id name status detail [fixhint]
  CHECKS+=("$1${SEP}$2${SEP}$3${SEP}$4${SEP}${5:-}")
  local c=32; case "$3" in WARN) c=33 ;; FAIL) c=31 ;; INFO) c=36 ;; FIXED) c=35 ;; esac
  printf '\033[1;%sm[%-5s]\033[0m %-24s %s\n' "$c" "$3" "$2" "$4"
}
addfile() { FILES+=("$1${SEP}$2${SEP}$3${SEP}$4"); } # kind path bytes state
status_of() { local l; for l in "${CHECKS[@]}"; do case "$l" in "$1${SEP}"*) l="${l#*"$SEP"}"; l="${l#*"$SEP"}"; printf '%s' "${l%%"$SEP"*}"; return ;; esac; done; }
find_tool() { local d; for d in "$BIN" "$HOME/Downloads" "$SCRIPT_DIR" "$PWD"; do [ -f "$d/$1" ] && { printf '%s' "$d/$1"; return 0; }; done; return 1; }
find_html() {
  local c
  for c in "$HTML" "$SCRIPT_DIR/Mac_DFU_Restore_Dashboard.html" "$HOME/Downloads/Mac_DFU_Restore_Dashboard.html" "$BASE/Mac_DFU_Restore_Dashboard.html" "$PWD/Mac_DFU_Restore_Dashboard.html"; do
    if [ -n "$c" ] && [ -f "$c" ] && grep -q 'id="launcher-src"' "$c" 2>/dev/null; then
      if grep -q "$TOK_DATA" "$c" 2>/dev/null; then HTML="$c"; return 0; fi
    fi
  done
  HTML=""; return 1
}
extract() { # id file  -> prints the embedded text/plain script byte-for-byte
  awk -v id="$1" '
    BEGIN{p=0}
    { line=$0
      if(!p && index(line,"id=\"" id "\"")){ sub(/^.*id="[^"]*"[^>]*>/,"",line); p=1 }
      if(p){
        k=index(line,"<" "/script>")
        if(k){ pre=substr(line,1,k-1); if(pre!="") print pre; exit }
        print line
      }
    }' "$2"
}
remote_len() { curl -sIL --max-time 12 "$1" 2>/dev/null | awk 'tolower($1)=="content-length:"{gsub("\r","");v=$2} END{print v}'; }
sudo_ok() { [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1; }

write_check_dfu() { cat > "$1" <<'CHK_EOF'
#!/bin/bash
# =============================================================================
# check_dfu.sh - watch for an Apple device in DFU mode (MX Linux / Debian)
# Part of MAC-DFU-RESTORE. Safe/read-only: only runs lsusb (+ dmesg on timeout).
# Audit: ~/Mac_DFU_Restore/dfu_check_<timestamp>.log
# Usage : ./check_dfu.sh [seconds]      (default 90)
# Exit  : 0 = DFU confirmed, 1 = Apple device but NOT DFU, 2 = nothing detected
# =============================================================================
set -u
MAXWAIT="${1:-90}"
BASE="$HOME/Mac_DFU_Restore"
mkdir -p "$BASE"
LOG="$BASE/dfu_check_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

command -v lsusb >/dev/null 2>&1 || { echo "ERROR: lsusb missing -> sudo apt-get install usbutils"; exit 2; }

echo "Waiting up to ${MAXWAIT}s for an Apple USB device (vendor 05ac)..."
echo "NOW: Mac OFF, USB-C data cable in the LEFT port next to MagSafe, MagSafe plugged in."
echo "Hold POWER + RIGHT Shift + LEFT Ctrl + LEFT Option ~10s, release the 3 keys, keep holding POWER ~5s."
echo

sudo -n dmesg -C 2>/dev/null
SEEN_NONDFU=0
for _ in $(seq 1 $((MAXWAIT / 2))); do
  L="$(lsusb -d 05ac: 2>/dev/null)"
  if [ -n "$L" ]; then
    if printf '%s' "$L" | grep -qi "DFU"; then
      echo "DETECTED:"; printf '%s\n' "$L"
      echo ">>> DFU MODE CONFIRMED. Open RestoreKit now."
      exit 0
    fi
    if [ "$SEEN_NONDFU" = "0" ]; then
      echo "Apple device present but NOT DFU: $(printf '%s' "$L" | head -1)"
      echo "  -> shut the Mac fully down and redo the key sequence."
      SEEN_NONDFU=1
    fi
  fi
  sleep 2
done

echo
if [ "$SEEN_NONDFU" = "1" ]; then
  echo "RESULT: Apple device seen but never entered DFU."
else
  echo "RESULT: NOT DETECTED. USB bus snapshot:"
  lsusb
  echo
  echo "Kernel USB messages (empty = PC saw nothing = cable/port/Mac issue):"
  sudo -n dmesg 2>/dev/null | tail -20 || echo "(run with sudo for dmesg)"
  echo
  echo "Try next: 1) data-capable cable  2) USB-A to USB-C cable  3) other PC port  4) other left-side Mac port  5) redo key sequence."
fi
echo "Log: $LOG"
[ "$SEEN_NONDFU" = "1" ] && exit 1
exit 2
CHK_EOF
chmod +x "$1"; }

# ================================================================== SCAN ======
scan_all() {
  CHECKS=(); FILES=(); NET_OK=0
  local arch os t missing ca gh free_kb free_gb rkver f sz name remote state ok_n any_n

  arch="$(uname -m)"
  os="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown OS}")"
  [ -r /etc/mx-version ] && os="$os / $(head -1 /etc/mx-version)"
  OS_STR="$os"; ARCH_STR="$arch"
  if [ "$arch" = "x86_64" ] && command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
    add platform "Platform" PASS "$os | $arch | apt + dpkg present"
  else
    add platform "Platform" FAIL "$os | $arch - needs Debian-based x86_64 (apt + dpkg)" "Use an MX Linux / Debian amd64 host"
  fi

  if [ "$(id -u)" -eq 0 ]; then add sudo "Privileges" WARN "running as root - run as your normal user (sudo is used only where needed)"
  elif command -v sudo >/dev/null 2>&1 && id -nG | tr ' ' '\n' | grep -qx sudo; then add sudo "Privileges" PASS "sudo available (member of group sudo)"
  elif command -v sudo >/dev/null 2>&1; then add sudo "Privileges" WARN "sudo present but user not in group sudo (may still work via sudoers)"
  else add sudo "Privileges" FAIL "sudo not installed" "su -c 'apt-get install sudo'"; fi

  missing=""
  for t in curl lsusb sha256sum awk base64; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
  if [ -z "$missing" ]; then add tools "Required tools" PASS "curl lsusb sha256sum awk base64 present"
  else add tools "Required tools" FAIL "missing:$missing" "apt-get install curl usbutils coreutils gawk"; fi

  if command -v curl >/dev/null 2>&1; then
    ca="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -I https://updates.cdn-apple.com 2>/dev/null)"; ca="${ca:-000}"
    gh="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -I https://github.com 2>/dev/null)"; gh="${gh:-000}"
    if [ "$ca" != "000" ] && [ "$gh" != "000" ]; then NET_OK=1; add network "Network" PASS "Apple CDN (HTTP $ca) and GitHub (HTTP $gh) reachable"
    elif [ "$ca" != "000" ] || [ "$gh" != "000" ]; then NET_OK=1; add network "Network" WARN "Apple CDN HTTP $ca | GitHub HTTP $gh - one is unreachable (proxy/firewall?)"
    else add network "Network" WARN "Apple CDN and GitHub unreachable - downloads and size-verification disabled" "Check internet / proxy / firewall"; fi
  else add network "Network" WARN "cannot test - curl missing"; fi

  free_kb="$(df --output=avail -k "$HOME" 2>/dev/null | tail -1 | tr -d ' ')"; free_kb="${free_kb:-0}"; free_gb=$((free_kb/1024/1024))
  if [ "$free_kb" -ge 25000000 ]; then add disk "Disk space" PASS "${free_gb} GB free in home (IPSW needs ~17 GB; 25 GB recommended)"
  else add disk "Disk space" WARN "${free_gb} GB free in home - IPSW needs ~17 GB; 25 GB recommended" "Free up space before downloading firmware"; fi

  rkver=""; dpkg -s restore-kit >/dev/null 2>&1 && rkver="$(dpkg -s restore-kit 2>/dev/null | awk '/^Version:/{print $2}')"
  if [ -n "$rkver" ]; then
    case "$rkver" in
      "$RK_VER"*) add restorekit "RestoreKit package" PASS "restore-kit $rkver installed (corporate pin $RK_VER)" ;;
      *) add restorekit "RestoreKit package" WARN "restore-kit $rkver installed; corporate pin is $RK_VER" "Version differs from the pin - not changed automatically" ;;
    esac
  else add restorekit "RestoreKit package" FAIL "restore-kit not installed" "Fix installs $RK_DEB (checksum verified)"; fi

  ok_n=0; any_n=0
  for f in "$HOME"/Downloads/RestoreKit_*_amd64.deb "$BASE"/RestoreKit_*_amd64.deb; do
    [ -f "$f" ] || continue; any_n=$((any_n+1)); sz="$(stat -c%s "$f")"; name="$(basename "$f")"
    if [ "$name" = "$RK_DEB" ]; then
      if [ "$(sha256sum "$f" | awk '{print $1}')" = "$RK_SHA256" ]; then state="SHA-256 verified (pinned)"; ok_n=$((ok_n+1)); else state="SHA-256 MISMATCH"; fi
    else state="different version - checksum not pinned"; fi
    addfile deb "$(rel "$f")" "$sz" "$state"
  done
  if [ "$any_n" -eq 0 ]; then add debfile "RestoreKit .deb file" INFO "no RestoreKit_*_amd64.deb in ~/Downloads (fetched on fix if needed)"
  elif [ "$ok_n" -ge 1 ]; then add debfile "RestoreKit .deb file" PASS "$RK_DEB present, SHA-256 verified"
  else add debfile "RestoreKit .deb file" WARN "$any_n .deb file(s) found but none match the pinned $RK_DEB checksum" "Re-download the pinned package"; fi

  if [ -f /etc/udev/rules.d/51-restorekit.rules ] || [ -f /lib/udev/rules.d/51-restorekit.rules ] || [ -f /usr/lib/udev/rules.d/51-restorekit.rules ]; then
    add udev "USB udev rule" PASS "51-restorekit.rules present (no sudo needed for USB access)"
  else add udev "USB udev rule" WARN "51-restorekit.rules missing - USB may need sudo / replug" "Fix installs it from the RestoreKit repo"; fi

  if [ -n "$rkver" ]; then
    f="$(dpkg -L restore-kit 2>/dev/null | grep '\.desktop$' | head -1)"
    if [ -n "$f" ]; then add gui "RestoreKit GUI entry" PASS "desktop entry: $f"; else add gui "RestoreKit GUI entry" WARN "no .desktop entry found - open RestoreKit from a terminal/menu manually"; fi
  fi

  if f="$(find_tool check_dfu.sh)"; then add checkdfu "check_dfu.sh" PASS "found at $(rel "$f")"
  else add checkdfu "check_dfu.sh" FAIL "not found (checked ~/Mac_DFU_Restore/bin, ~/Downloads, script dir)" "Fix writes it to ~/Mac_DFU_Restore/bin/"; fi

  if f="$(find_tool mac_dfu_restore.sh)"; then add launcher "mac_dfu_restore.sh" PASS "found at $(rel "$f")"
  elif find_html; then add launcher "mac_dfu_restore.sh" FAIL "not found - can be extracted from the dashboard" "Fix extracts it to ~/Mac_DFU_Restore/bin/"
  else add launcher "mac_dfu_restore.sh" WARN "not found and dashboard HTML not located to extract it from" "Download it from the dashboard's Launcher panel"; fi

  if find_html; then add dashboard "Dashboard HTML" PASS "template found: $(rel "$HTML")"
  else add dashboard "Dashboard HTML" WARN "Mac_DFU_Restore_Dashboard.html not found - results will not be embedded (use --html PATH)" "Keep the HTML next to this script or in ~/Downloads"; fi

  ok_n=0; any_n=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue; any_n=$((any_n+1)); sz="$(stat -c%s "$f")"; name="$(basename "$f")"; remote=""
    if [ "$NET_OK" = "1" ]; then
      case "$name" in "$IPSW_TAHOE_NAME") remote="$(remote_len "$IPSW_TAHOE_URL")" ;; "$IPSW_GG_NAME") remote="$(remote_len "$IPSW_GG_URL")" ;; esac
    fi
    if [ -n "$remote" ]; then
      if [ "$sz" = "$remote" ]; then state="complete (size = Apple Content-Length)"; ok_n=$((ok_n+1))
      else state="PARTIAL ($((sz*100/remote))% of $((remote/1024/1024)) MB)"; fi
    else state="size not verifiable (unknown file name or offline)"; fi
    addfile ipsw "$(rel "$f")" "$sz" "$state"
  done < <(find "$HOME/Downloads" "$IPSW_DIR" -maxdepth 3 -type f -iname '*restore.ipsw' 2>/dev/null | sort -u)
  if [ "$ok_n" -ge 1 ]; then add ipsw "Firmware (*Restore.ipsw)" PASS "$ok_n verified complete IPSW file(s) of $any_n found"
  elif [ "$any_n" -ge 1 ]; then add ipsw "Firmware (*Restore.ipsw)" WARN "$any_n IPSW file(s) found but none verified complete" "Re-run with --get-ipsw to resume, or use 'latest signed' in RestoreKit"
  else add ipsw "Firmware (*Restore.ipsw)" WARN "no *Restore.ipsw found in ~/Downloads or ~/Mac_DFU_Restore/ipsw" "Use --get-ipsw 1|2, or pick 'latest signed' in RestoreKit"; fi
  if pgrep -f 'curl.*\.ipsw' >/dev/null 2>&1; then add ipswdl "IPSW download" INFO "a curl download of an .ipsw is currently running - wait before restoring"; fi

  if command -v lsusb >/dev/null 2>&1; then
    f="$(lsusb -d 05ac: 2>/dev/null)"
    if printf '%s' "$f" | grep -qi DFU; then add usb "Apple device on USB" PASS "DFU mode detected: $(printf '%s' "$f" | head -1 | sed 's/^Bus [0-9]* Device [0-9]*: //')"
    elif [ -n "$f" ]; then add usb "Apple device on USB" WARN "Apple device present but NOT DFU: $(printf '%s' "$f" | head -1 | sed 's/^Bus [0-9]* Device [0-9]*: //')" "Shut the Mac down fully and redo the key sequence"
    else add usb "Apple device on USB" INFO "no Apple device yet (expected before you enter DFU)"; fi
  fi
}

# ================================================================== FIX =======
fix_count() {
  local i s n=0
  for i in tools restorekit udev checkdfu launcher; do
    s="$(status_of "$i")"
    case "$i:$s" in tools:FAIL|restorekit:FAIL|udev:WARN|checkdfu:FAIL|launcher:FAIL) n=$((n+1)) ;; esac
  done
  echo "$n"
}

apply_fixes() {
  local f
  say "APPLYING FIXES"
  if [ "$(status_of tools)" = "FAIL" ] && sudo_ok; then
    note "Installing prerequisite packages..."
    sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y curl usbutils coreutils gawk
  fi
  if [ "$(status_of restorekit)" = "FAIL" ]; then
    f="$HOME/Downloads/$RK_DEB"
    if [ -f "$f" ] && [ "$(sha256sum "$f" | awk '{print $1}')" = "$RK_SHA256" ]; then note "Reusing verified $RK_DEB from ~/Downloads"
    else
      note "Downloading $RK_DEB ..."
      curl -L -C - --retry 5 --retry-delay 5 -o "$f" "$RK_URL" || note "Download failed"
    fi
    if [ -f "$f" ] && [ "$(sha256sum "$f" | awk '{print $1}')" = "$RK_SHA256" ]; then
      note "SHA-256 verified - installing..."
      sudo apt-get install -y "$f" || note "apt install failed"
    else note "Checksum mismatch or missing file - NOT installing"; fi
  fi
  if [ "$(status_of udev)" != "PASS" ] && sudo_ok; then
    if curl -fsSL "$UDEV_URL" | sudo tee /etc/udev/rules.d/51-restorekit.rules >/dev/null; then note "udev rule installed"; else note "udev rule download failed"; fi
    sudo udevadm control --reload-rules 2>/dev/null; sudo udevadm trigger 2>/dev/null
  fi
  if [ "$(status_of checkdfu)" = "FAIL" ]; then write_check_dfu "$BIN/check_dfu.sh" && note "check_dfu.sh written to $(rel "$BIN")/"; fi
  if [ "$(status_of launcher)" = "FAIL" ] && [ -n "$HTML" ]; then
    extract launcher-src "$HTML" > "$BIN/mac_dfu_restore.sh" && chmod +x "$BIN/mac_dfu_restore.sh" && note "mac_dfu_restore.sh extracted to $(rel "$BIN")/"
  fi
}

get_ipsw() { # 1|2
  local name url dest remote
  case "$1" in 1) name="$IPSW_TAHOE_NAME"; url="$IPSW_TAHOE_URL" ;; 2) name="$IPSW_GG_NAME"; url="$IPSW_GG_URL" ;; *) return 1 ;; esac
  dest="$IPSW_DIR/$name"
  while pgrep -f 'curl.*\.ipsw' >/dev/null 2>&1; do note "Another IPSW download is running - waiting 15s..."; sleep 15; done
  remote="$(remote_len "$url")"
  if [ -n "$remote" ] && [ -f "$dest" ] && [ "$(stat -c%s "$dest")" = "$remote" ]; then note "IPSW already complete: $(rel "$dest")"; return 0; fi
  note "Downloading $name (resumable, ~17 GB)..."
  curl -L -C - --retry 5 --retry-delay 5 -o "$dest" "$url" || { note "IPSW download failed - re-run to resume"; return 1; }
  [ -z "$remote" ] || [ "$(stat -c%s "$dest")" = "$remote" ] || { note "Size mismatch - re-run to resume"; return 1; }
  note "IPSW verified by size."
}

# =============================================================== REPORTING ====
mark_fixed() { # compare with PRE; upgrade previously failing -> FIXED
  local i l id rest st new=()
  for l in "${CHECKS[@]}"; do
    id="${l%%"$SEP"*}"; rest="${l#*"$SEP"}"; rest="${rest#*"$SEP"}"; st="${rest%%"$SEP"*}"
    if [ "$st" = "PASS" ] && { [ "${PRE[$id]:-}" = "FAIL" ] || [ "${PRE[$id]:-}" = "WARN" ]; }; then
      l="${l/${SEP}PASS${SEP}/${SEP}FIXED${SEP}}"
    fi
    new+=("$l")
  done
  CHECKS=("${new[@]}")
}
count() { local l n=0 rest st; for l in "${CHECKS[@]}"; do rest="${l#*"$SEP"}"; rest="${rest#*"$SEP"}"; st="${rest%%"$SEP"*}"; [ "$st" = "$1" ] && n=$((n+1)); done; echo "$n"; }

write_json() {
  local out="$RUN/preflight.json" l id name st detail fix kind path bytes state first=1
  local p w f x fx info; p=$(count PASS); w=$(count WARN); f=$(count FAIL); fx=$(count FIXED); info=$(count INFO)
  VERDICT="READY"; [ "$w" -gt 0 ] && VERDICT="READY WITH WARNINGS"; [ "$f" -gt 0 ] && VERDICT="NOT READY"
  {
    printf '{\n  "schema": 1,\n  "tool": "%s",\n  "version": "%s",\n' "$TOOL" "$CON_VER"
    printf '  "generated": "%s",\n  "host": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(jstr "$(hostname)")"
    printf '  "os": "%s",\n  "arch": "%s",\n  "mode": "%s",\n  "runDir": "%s",\n' "$(jstr "$OS_STR")" "$ARCH_STR" "$MODE" "$(jstr "$(rel "$RUN")")"
    printf '  "summary": {"pass": %d, "fixed": %d, "warn": %d, "fail": %d, "info": %d},\n' "$p" "$fx" "$w" "$f" "$info"
    printf '  "verdict": "%s",\n  "checks": [\n' "$VERDICT"
    for l in "${CHECKS[@]}"; do
      IFS="$SEP" read -r id name st detail fix <<<"$l"
      [ $first -eq 1 ] || printf ',\n'; first=0
      printf '    {"id": "%s", "name": "%s", "status": "%s", "detail": "%s", "fix": "%s"}' "$id" "$(jstr "$name")" "$st" "$(jstr "$detail")" "$(jstr "$fix")"
    done
    printf '\n  ],\n  "files": [\n'
    first=1
    for l in "${FILES[@]}"; do
      IFS="$SEP" read -r kind path bytes state <<<"$l"
      [ $first -eq 1 ] || printf ',\n'; first=0
      printf '    {"kind": "%s", "path": "%s", "bytes": %s, "state": "%s"}' "$kind" "$(jstr "$path")" "${bytes:-0}" "$(jstr "$state")"
    done
    printf '\n  ]\n}\n'
  } > "$out"
  ( cd "$RUN" && sha256sum preflight.json > preflight.json.sha256 )
  JSON_SHA="$(sha256sum "$out" | awk '{print $1}')"
}

make_console() {
  [ -n "$HTML" ] || { note "Dashboard template not found - skipping embedded console."; return 1; }
  local b64 out="$RUN/Mac_DFU_Restore_Console.html"
  b64="$(base64 -w0 "$RUN/preflight.json")"
  awk -v td="$TOK_DATA" -v ts="$TOK_SHA" -v b="$b64" -v s="$JSON_SHA" '{ gsub(td,b); gsub(ts,s); print }' "$HTML" > "$out" || return 1
  cp -f "$out" "$BASE/Mac_DFU_Restore_Console.html" 2>/dev/null
  [ -f "$BASE/Mac_DFU_Restore_Dashboard.html" ] || cp -f "$HTML" "$BASE/Mac_DFU_Restore_Dashboard.html" 2>/dev/null
  CONSOLE_OUT="$out"; return 0
}

write_receipt() {
  local dur=$(( $(date +%s) - START_EPOCH )) rows="" n=0 l id name st detail fix cls
  for l in "${CHECKS[@]}"; do
    IFS="$SEP" read -r id name st detail fix <<<"$l"; n=$((n+1))
    cls="pass"; case "$st" in WARN) cls="warn" ;; FAIL) cls="fail" ;; INFO) cls="info" ;; esac
    rows="${rows}<tr style=\"animation-delay:${n}00ms\"><td>$(printf '%s' "$name" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')</td><td><span class=\"pill $cls\">$st</span></td><td>$(printf '%s' "$detail" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')</td></tr>"
  done
  local vc="pass"; [ "$VERDICT" = "READY WITH WARNINGS" ] && vc="warn"; [ "$VERDICT" = "NOT READY" ] && vc="fail"
  cat > "$RUN/receipt.html" <<EOF
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>${TOOL} Receipt ${TS}</title><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;font-family:"Segoe UI Variable Text","Segoe UI",system-ui,sans-serif;color:#cddbe9;background:radial-gradient(1000px 700px at 80% -10%,rgba(47,230,208,.08),transparent 60%),#05080d;padding:32px}
.wrap{max-width:980px;margin:auto}h1{font-family:"Cascadia Mono",Consolas,monospace;font-size:26px;margin:0 0 6px;color:#2fe6d0;letter-spacing:.04em}
.sub{color:#8ba2b8;font-size:12px;margin-bottom:16px;font-family:"Cascadia Mono",Consolas,monospace}
.bar{height:4px;border-radius:4px;background:linear-gradient(90deg,transparent,#2fe6d0,#7dff9b,transparent);background-size:200% 100%;animation:sh 2.4s linear infinite;margin-bottom:20px}@keyframes sh{to{background-position:-200% 0}}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:20px}
.k{background:rgba(12,22,34,.68);border:1px solid rgba(255,255,255,.09);border-radius:12px;padding:14px;transition:.25s}.k:hover{transform:translateY(-4px);box-shadow:0 0 24px rgba(47,230,208,.25)}
.k b{display:block;font:600 9px "Cascadia Mono",Consolas,monospace;letter-spacing:.12em;color:#5b7186;margin-bottom:8px}.k span{font:800 20px "Cascadia Mono",Consolas,monospace;color:#2fe6d0}
.card{background:rgba(12,22,34,.68);border:1px solid rgba(255,255,255,.09);border-radius:12px;padding:6px 16px 12px}
table{width:100%;border-collapse:collapse;font-size:12.5px}th{text-align:left;color:#5b7186;font:600 9.5px "Cascadia Mono",Consolas,monospace;letter-spacing:.1em;padding:10px 8px}
td{padding:9px 8px;border-top:1px solid #152534;vertical-align:top}tr{opacity:0;animation:fi .5s forwards}@keyframes fi{to{opacity:1}}
.pill{padding:2px 10px;border-radius:99px;font:700 10px "Cascadia Mono",Consolas,monospace;border:1px solid}
.pass{color:#7dff9b;background:rgba(125,255,155,.10)}.warn{color:#ffb547;background:rgba(255,181,71,.10)}.fail{color:#ff5165;background:rgba(255,81,101,.10)}.info{color:#59b4ff;background:rgba(89,180,255,.10)}
.foot{margin-top:16px;color:#5b7186;font:11px "Cascadia Mono",Consolas,monospace;word-break:break-all}
</style></head><body><div class="wrap">
<h1>${TOOL} // PREFLIGHT RECEIPT</h1>
<div class="sub">Host: $(hostname) | Run: ${TS} | Mode: ${MODE} | Elapsed: ${dur}s</div><div class="bar"></div>
<div class="kpis">
<div class="k"><b>VERDICT</b><span class="pill ${vc}">${VERDICT}</span></div>
<div class="k"><b>PASS / FIXED</b><span>$(count PASS) / $(count FIXED)</span></div>
<div class="k"><b>WARN</b><span>$(count WARN)</span></div>
<div class="k"><b>FAIL</b><span>$(count FAIL)</span></div>
</div>
<div class="card"><table><thead><tr><th>CHECK</th><th>STATUS</th><th>DETAIL</th></tr></thead><tbody>${rows}</tbody></table></div>
<div class="foot">preflight.json SHA-256: ${JSON_SHA}<br>Log: $(rel "$LOG")</div>
</div></body></html>
EOF
}

open_console() {
  local target="$1" b
  [ "$NOOPEN" = "1" ] && return 0
  [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || { note "No display - open $(rel "$target") manually in a Chromium browser."; return 0; }
  for b in google-chrome google-chrome-stable chromium chromium-browser brave-browser microsoft-edge; do
    if command -v "$b" >/dev/null 2>&1; then nohup "$b" "file://$target" >/dev/null 2>&1 & note "Opened in $b (Chromium - WebUSB live detect available)"; return 0; fi
  done
  command -v xdg-open >/dev/null 2>&1 && { nohup xdg-open "$target" >/dev/null 2>&1 & note "Opened with the default browser (WebUSB needs Chrome/Chromium/Brave)"; }
}

finish() {
  local code="${1:-0}"
  echo; echo "Log      : $(rel "$LOG")"; echo "JSON     : $(rel "$RUN")/preflight.json  (sha256 ${JSON_SHA:-n/a})"
  echo "Receipt  : $(rel "$RUN")/receipt.html"; [ -n "${CONSOLE_OUT:-}" ] && echo "Console  : $(rel "$BASE")/Mac_DFU_Restore_Console.html  (bookmark this)"
  exit "$code"
}
trap 'echo; note "Interrupted."; exit 130' INT TERM

# ================================================================== MAIN ======
echo "################################################################"
echo "#  ${TOOL} v${CON_VER}  |  smart preflight for Apple silicon DFU restore"
echo "#  Run: ${TS}   Host: $(hostname)   Mode: ${MODE}"
echo "################################################################"

say "1/4  SCAN"
scan_all
for l in "${CHECKS[@]}"; do PRE["${l%%"$SEP"*}"]="$(status_of "${l%%"$SEP"*}")"; done

NFIX="$(fix_count)"
if [ "$MODE" = "fix" ] && [ "$NFIX" -gt 0 ]; then
  say "2/4  FIX ($NFIX item(s) can be fixed automatically)"
  DO="y"
  if [ "$ASSUME_YES" != "1" ] && [ -t 0 ]; then read -r -p "Apply fixes now (needs sudo for packages)? [Y/n] " DO; DO="${DO:-y}"; fi
  case "$DO" in y|Y|yes|YES) apply_fixes ;; *) note "Fixes skipped." ;; esac
else
  say "2/4  FIX"; [ "$MODE" = "scan" ] && note "Scan-only mode - nothing changed." || note "Nothing to fix."
fi

if [ "$MODE" = "fix" ]; then
  if [ -n "$GET_IPSW" ]; then get_ipsw "$GET_IPSW"
  elif [ "$(status_of ipsw)" != "PASS" ] && [ -t 0 ] && [ "$ASSUME_YES" != "1" ]; then
    echo; echo "No verified firmware found. Download one now?"
    echo "  1) macOS Tahoe 26.6.2 (~17 GB)   2) macOS 27.0.1 (~17 GB)   3) Skip (RestoreKit can fetch 'latest signed')"
    read -r -p "Select 1-3 [3]: " P; case "${P:-3}" in 1|2) get_ipsw "$P" ;; esac
  fi
fi

if [ "$MODE" = "fix" ]; then
  say "3/4  VERIFY (final scan)"
  scan_all
  mark_fixed
else
  say "3/4  VERIFY"; note "Scan-only: first scan is the final result."
fi

say "4/4  REPORT"
write_json
echo
printf 'VERDICT: %s   (PASS %s | FIXED %s | WARN %s | FAIL %s | INFO %s)\n' "$VERDICT" "$(count PASS)" "$(count FIXED)" "$(count WARN)" "$(count FAIL)" "$(count INFO)"
write_receipt
CONSOLE_OUT=""
if make_console; then open_console "$CONSOLE_OUT"; fi

if [ "$VERDICT" != "NOT READY" ] && [ -t 0 ] && [ "$MODE" = "fix" ]; then
  RL="$(find_tool mac_dfu_restore.sh)" && { echo; read -r -p "Start the restore flow now ($(rel "$RL"))? [y/N] " GO; case "${GO:-n}" in y|Y) bash "$RL" ;; esac; }
fi
finish 0
