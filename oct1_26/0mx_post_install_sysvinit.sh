#!/bin/bash
# MX Linux KDE 25.2 — Merged Post-Install Automation Script (SysVinit Edition)
# Merges mx_post_install_sysVinit.sh + mx_sysvinit_airgap.sh.
# kdialog GUI, normal-user + sudo-per-action, live HTML telemetry dashboard.

MODULE_TAGS=(update firewall utilities virtualization python pythonlibs nodejs keepassxc veracrypt gnupg timeshift firmware browserext media docker zsh localsend airgaptoggle)

declare -A MODULE_DESC=(
  [update]="System update (apt update && upgrade && autoremove)"
  [firewall]="Firewall configuration (profile chosen next)"
  [utilities]="General utilities (curl, git, htop, tree, rsync, etc.)"
  [virtualization]="Virtualization (QEMU/KVM, libvirt, virt-manager)"
  [python]="Python build toolchain"
  [pythonlibs]="Python libraries (pandas, numpy, flask, etc.)"
  [nodejs]="Node.js LTS + pm2/nodemon"
  [keepassxc]="KeePassXC password manager"
  [veracrypt]="VeraCrypt disk encryption"
  [gnupg]="GnuPG + Kleopatra"
  [timeshift]="Timeshift system snapshots"
  [firmware]="fwupd firmware updates"
  [browserext]="Browser extension policy (uBlock/Ghostery)"
  [media]="Media tools (yt-dlp, ffmpeg, vlc, Spectacle, Celluloid, OBS)"
  [docker]="Docker + Compose"
  [zsh]="Zsh + Oh-My-Zsh"
  [localsend]="LocalSend"
  [airgaptoggle]="Airgap network-toggle utility (Desktop shortcut)"
)

# Firewall always applied last: airgap-toggle/docker rules must not be undone by a later module's ufw interaction.
EXEC_ORDER=(update utilities virtualization python pythonlibs nodejs keepassxc veracrypt gnupg timeshift firmware browserext media docker zsh localsend airgaptoggle firewall)

# ===========================================================================
# Function definitions
# ===========================================================================

require_tty(){
  if [ ! -t 0 ]; then
    if command -v konsole &>/dev/null; then
      exec konsole --hold -e "$0" "$@"
    fi
    echo "[ERROR] No controlling terminal and konsole not found. Run this script from a terminal." >&2
    exit 1
  fi
}

check_root(){
  if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Do not run this script as root. Run as your normal user (it calls sudo per action)." >&2
    exit 1
  fi
}

check_sysvinit(){
  local init_comm
  init_comm=$(cat /proc/1/comm 2>/dev/null)
  if [ "$init_comm" = "systemd" ] || pidof systemd &>/dev/null; then
    echo "[ERROR] systemd is the active init system. This script targets SysVinit only." >&2
    exit 1
  fi
}

log(){
  local level="$1"; shift
  printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

record_state(){
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(date -Iseconds)" "$4" >> "$STATE_FILE"
}

html_escape(){
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

pkg_installed(){ dpkg -s "$1" &>/dev/null; }
pkg_available(){ apt-cache show "$1" &>/dev/null; }

# ensure_pkg <module> <primary> [fallback] — installs primary, or fallback if primary
# doesn't exist in the repo (covers packages renamed/removed since trixie).
ensure_pkg(){
  local module="$1" primary="$2" fallback="${3:-}"
  local pkg="$primary"

  if pkg_installed "$primary"; then
    log OK "$primary already installed."
    record_state "$module" "$primary" OK "already installed"
    return 0
  fi
  if [ -n "$fallback" ] && pkg_installed "$fallback"; then
    log OK "$fallback already installed (fallback for $primary)."
    record_state "$module" "$fallback" OK "already installed (fallback for $primary)"
    return 0
  fi

  if ! pkg_available "$primary"; then
    if [ -n "$fallback" ] && pkg_available "$fallback"; then
      pkg="$fallback"
    else
      log WARN "$primary${fallback:+ and fallback $fallback} not available in repos — skipping."
      record_state "$module" "$primary" SKIP "not available in repos"
      return 1
    fi
  fi

  log INFO "Installing $pkg..."
  if sudo env DEBIAN_FRONTEND=noninteractive apt-get -y \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      -o DPkg::Lock::Timeout=300 install "$pkg"; then
    log OK "$pkg installed."
    record_state "$module" "$pkg" OK "installed"
  else
    log ERROR "$pkg failed to install."
    record_state "$module" "$pkg" ERROR "apt-get install failed"
    return 1
  fi
}

ensure_group_membership(){
  local module="$1" group="$2"
  if id -nG "$USER" | grep -qw "$group"; then
    log OK "User $USER already in group $group."
  else
    log INFO "Adding $USER to group $group..."
    if sudo usermod -aG "$group" "$USER"; then
      log OK "Added $USER to group $group (log out/in to take effect)."
      record_state "$module" "group:$group" OK "added — relogin required"
    else
      log WARN "Failed to add $USER to group $group."
      record_state "$module" "group:$group" WARN "usermod failed"
    fi
  fi
}

start_service(){
  local module="$1" svc="$2"
  log INFO "Starting service $svc..."
  sudo service "$svc" start &>/dev/null || log WARN "Could not start $svc (may already be running or not installed)."
  sudo update-rc.d "$svc" defaults &>/dev/null || log WARN "Could not enable $svc on boot."
  record_state "$module" "service:$svc" OK "start+enable attempted"
}

check_connectivity(){
  if timeout 5 bash -c '</dev/tcp/deb.debian.org/443' 2>/dev/null; then
    log OK "Internet connectivity confirmed."
  else
    echo "[ERROR] No internet connectivity detected (deb.debian.org:443 unreachable). Aborting." >&2
    exit 1
  fi
}

sudo_keepalive(){
  sudo -v
  (
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true
      sleep 60
    done
  ) &
  KEEPALIVE_PID=$!
}

find_qdbus(){
  local c
  for c in qdbus qdbus6 /usr/lib/qt6/bin/qdbus /usr/lib/qt5/bin/qdbus /usr/lib/x86_64-linux-gnu/qt5/bin/qdbus; do
    if command -v "$c" &>/dev/null; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

ensure_runtime_deps(){
  local m="preflight"
  ensure_pkg "$m" kdialog
  ensure_pkg "$m" curl
  ensure_pkg "$m" wget
  ensure_pkg "$m" git
  ensure_pkg "$m" xdg-utils
  ensure_pkg "$m" dbus

  QDBUS_BIN="$(find_qdbus || true)"
  if [ -z "$QDBUS_BIN" ]; then
    ensure_pkg "$m" qdbus-qt5
    QDBUS_BIN="$(find_qdbus || true)"
  fi
  if [ -z "$QDBUS_BIN" ]; then
    log WARN "No qdbus binary found — progress bar will use dbus-send fallback."
  else
    log OK "Using qdbus binary: $QDBUS_BIN"
  fi

  if ! command -v kdialog &>/dev/null; then
    echo "[ERROR] kdialog still not available after install attempt — cannot continue in GUI mode." >&2
    exit 1
  fi
}

# --- kdialog progress bar (dbus-driven; dbus-send is the guaranteed fallback
# since `dbus` itself is always installed in ensure_runtime_deps) ---

open_progress(){
  local text="$1" total="$2"
  local ref
  ref=$(kdialog --title "MX Linux Post-Install" --progressbar "$text" "$total")
  PROGRESS_SERVICE="${ref%% *}"
  PROGRESS_OBJECT="${ref#* }"
}

pb_set_value(){
  local pct="$1"
  if [ -n "$QDBUS_BIN" ]; then
    "$QDBUS_BIN" "$PROGRESS_SERVICE" "$PROGRESS_OBJECT" Set "" value "$pct" &>/dev/null
  else
    dbus-send --dest="$PROGRESS_SERVICE" "$PROGRESS_OBJECT" org.freedesktop.DBus.Properties.Set \
      string:"org.kde.kdialog.ProgressDialog" string:"value" variant:int32:"$pct" &>/dev/null
  fi
}

pb_set_label(){
  local text="$1"
  if [ -n "$QDBUS_BIN" ]; then
    "$QDBUS_BIN" "$PROGRESS_SERVICE" "$PROGRESS_OBJECT" setLabelText "$text" &>/dev/null
  else
    dbus-send --dest="$PROGRESS_SERVICE" "$PROGRESS_OBJECT" org.kde.kdialog.ProgressDialog.setLabelText string:"$text" &>/dev/null
  fi
}

pb_was_cancelled(){
  local out
  if [ -n "$QDBUS_BIN" ]; then
    out=$("$QDBUS_BIN" "$PROGRESS_SERVICE" "$PROGRESS_OBJECT" wasCancelled 2>/dev/null)
  else
    out=$(dbus-send --print-reply --dest="$PROGRESS_SERVICE" "$PROGRESS_OBJECT" org.kde.kdialog.ProgressDialog.wasCancelled 2>/dev/null)
  fi
  [[ "$out" == *"true"* ]]
}

pb_close(){
  if [ -n "$QDBUS_BIN" ]; then
    "$QDBUS_BIN" "$PROGRESS_SERVICE" "$PROGRESS_OBJECT" close &>/dev/null
  else
    dbus-send --dest="$PROGRESS_SERVICE" "$PROGRESS_OBJECT" org.kde.kdialog.ProgressDialog.close &>/dev/null
  fi
}

# --- Live HTML dashboard ---

render_summary_section(){
  local ok warn err skip runtime
  ok=$(awk -F'\t' '$3=="OK"' "$STATE_FILE" 2>/dev/null | wc -l)
  warn=$(awk -F'\t' '$3=="WARN"' "$STATE_FILE" 2>/dev/null | wc -l)
  err=$(awk -F'\t' '$3=="ERROR"' "$STATE_FILE" 2>/dev/null | wc -l)
  skip=$(awk -F'\t' '$3=="SKIP"' "$STATE_FILE" 2>/dev/null | wc -l)
  runtime=$(( $(date +%s) - START_EPOCH ))
  echo "<h2>Telemetry Summary</h2>"
  echo "<ul>"
  echo "<li>OK: $ok &nbsp; WARN: $warn &nbsp; ERROR: $err &nbsp; SKIP: $skip</li>"
  echo "<li>Total runtime: ${runtime}s</li>"
  echo "<li>Full text log: $(html_escape "$LOGFILE")</li>"
  echo "<li>Firewall profile: $(html_escape "$(cat "$UFW_PROFILE_FILE" 2>/dev/null || echo none)")</li>"
  echo "</ul>"
  echo "<h2>Firewall Status</h2>"
  echo "<pre>$(html_escape "$(sudo ufw status verbose 2>/dev/null || echo 'ufw not installed/configured')")</pre>"
}

render_dashboard(){
  local final="${1:-false}"
  local pct="${LAST_PCT:-0}"
  local refresh_tag=""
  [ "$final" = false ] && refresh_tag='<meta http-equiv="refresh" content="2">'

  {
    cat <<HTMLHEAD
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
$refresh_tag
<title>MX Linux Post-Install Dashboard</title>
<style>
  body{background:#12151c;color:#d8dee9;font-family:'Segoe UI',sans-serif;margin:0;padding:2rem;}
  .wrap{max-width:960px;margin:0 auto;}
  h1{color:#88c0d0;font-size:1.6rem;margin-bottom:.25rem;}
  .meta{color:#7a8296;font-size:.85rem;margin-bottom:1.5rem;}
  .progress-outer{background:#232838;border-radius:6px;height:22px;overflow:hidden;margin-bottom:2rem;}
  .progress-inner{background:linear-gradient(90deg,#5e81ac,#88c0d0);height:100%;color:#0b0d12;font-size:.8rem;line-height:22px;text-align:center;font-weight:600;transition:width .3s ease;}
  table{width:100%;border-collapse:collapse;margin-bottom:2rem;}
  th,td{padding:.5rem .75rem;text-align:left;border-bottom:1px solid #232838;font-size:.9rem;}
  th{color:#7a8296;text-transform:uppercase;font-size:.75rem;letter-spacing:.05em;}
  .badge{padding:.15rem .55rem;border-radius:999px;font-size:.75rem;font-weight:600;}
  .badge.ok{background:#2f4d3a;color:#a3d9a5;}
  .badge.warn{background:#4d4630;color:#e0c46c;}
  .badge.error{background:#4d2f34;color:#e08a94;}
  .badge.skip{background:#2c3140;color:#8b93a8;}
  h2{color:#88c0d0;font-size:1.15rem;border-bottom:1px solid #232838;padding-bottom:.4rem;}
  ul{font-size:.9rem;line-height:1.6;}
  pre{background:#1a1d27;padding:1rem;border-radius:6px;font-size:.8rem;overflow-x:auto;white-space:pre-wrap;}
</style>
</head><body><div class="wrap">
<h1>MX Linux Post-Install — Live Dashboard</h1>
<div class="meta">Started: $RUN_STARTED &nbsp;|&nbsp; Log: $(html_escape "$LOGFILE")</div>
<div class="progress-outer"><div class="progress-inner" style="width:${pct}%">${pct}%</div></div>
<h2>Modules</h2>
<table>
<tr><th>Module</th><th>Item</th><th>Status</th><th>Time</th><th>Note</th></tr>
HTMLHEAD

    if [ -f "$STATE_FILE" ]; then
      while IFS=$'\t' read -r module pkg status ts note; do
        [ -z "$module" ] && continue
        cls="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"
        printf '<tr><td>%s</td><td>%s</td><td><span class="badge %s">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
          "$(html_escape "$module")" "$(html_escape "$pkg")" "$cls" "$status" "$ts" "$(html_escape "$note")"
      done < "$STATE_FILE"
    fi

    echo "</table>"
    [ "$final" = true ] && render_summary_section
    echo "</div></body></html>"
  } > "$DASHBOARD.tmp"
  mv -f "$DASHBOARD.tmp" "$DASHBOARD"
}

# ===========================================================================
# Modules (merged from both source scripts; trixie package-name fallbacks applied)
# ===========================================================================

system_update(){
  local m="update"
  log INFO "=== System Update ==="
  if sudo apt-get update && sudo apt-get -y upgrade && sudo apt-get -y autoremove; then
    record_state "$m" "apt-upgrade" OK "system updated"
  else
    record_state "$m" "apt-upgrade" ERROR "update/upgrade failed"
  fi
}

configure_firewall(){
  local profile="$1" m="firewall"
  ensure_pkg "$m" ufw
  echo "$profile" > "$UFW_PROFILE_FILE"

  if [ "$profile" = "lan" ]; then
    sudo ufw allow Samba
    sudo ufw allow 137/udp
    sudo ufw allow 138/udp
    sudo ufw allow 139/tcp
    sudo ufw allow 445/tcp
    sudo ufw --force enable
    sudo ufw reload
    if pkg_installed samba; then
      start_service "$m" smbd
      start_service "$m" nmbd
    fi
    record_state "$m" "ufw-profile" OK "lan/samba profile applied"
  else
    # Fixes a script2 bug: `default deny outgoing` does not retroactively
    # revoke allow-out rules added earlier, so reset first, then add only
    # the rules this profile actually wants.
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default deny outgoing
    sudo ufw allow out 53/tcp
    sudo ufw allow out 53/udp
    sudo ufw allow out 80/tcp
    sudo ufw allow out 443/tcp
    sudo ufw --force enable
    record_state "$m" "ufw-profile" OK "strict airgap profile applied"
  fi
}

install_utilities(){
  local m="utilities" p
  for p in mtools curl wget git unzip zip qrencode htop tree rsync; do
    ensure_pkg "$m" "$p"
  done
  ensure_pkg "$m" neofetch fastfetch
}

install_virtualization(){
  local m="virtualization" p
  if ! grep -qE 'vmx|svm' /proc/cpuinfo; then
    log WARN "Hardware virtualization (VT-x/AMD-V) not detected. VMs may not run."
  fi
  ensure_pkg "$m" qemu-kvm qemu-system-x86
  for p in libvirt-clients libvirt-daemon-system virt-manager ovmf swtpm swtpm-tools bridge-utils virtinst virtiofsd; do
    ensure_pkg "$m" "$p"
  done
  ensure_group_membership "$m" libvirt
  ensure_group_membership "$m" kvm
  start_service "$m" libvirtd
  [ -f /etc/init.d/libvirt-guests ] && start_service "$m" libvirt-guests
}

install_python_stack(){
  local m="python" p
  for p in python3 python3-full python3-pip python3-venv build-essential libssl-dev \
           zlib1g-dev libsqlite3-dev libffi-dev libbz2-dev libreadline-dev tk-dev \
           libxml2-dev libxslt1-dev libjpeg-dev; do
    ensure_pkg "$m" "$p"
  done
  ensure_pkg "$m" libncursesw5-dev libncurses-dev
  ensure_pkg "$m" libfreetype6-dev libfreetype-dev
}

install_python_libraries(){
  local m="pythonlibs" p
  for p in python3-cryptography python3-tk python3-psutil python3-pandas python3-numpy \
           python3-openpyxl python3-flask python3-bcrypt python3-requests python3-yaml \
           python3-lxml python3-sqlalchemy python3-pil python3-paramiko python3-dotenv; do
    ensure_pkg "$m" "$p"
  done
}

install_nodejs(){
  local m="nodejs"
  if command -v node &>/dev/null; then
    record_state "$m" node OK "already installed: $(node --version)"
    return
  fi
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  if sudo apt-get install -y nodejs; then
    record_state "$m" nodejs OK "installed $(node --version 2>/dev/null)"
  else
    record_state "$m" nodejs ERROR "install failed"
    return
  fi
  sudo npm install -g pm2 nodemon || log WARN "npm globals failed (non-critical)."
  pm2 startup 2>/dev/null | grep sudo | bash || log INFO "Run 'pm2 startup' manually later."
}

install_keepassxc(){
  local m="keepassxc"
  if command -v keepassxc &>/dev/null; then
    record_state "$m" keepassxc OK "already installed"
    return
  fi
  ensure_pkg "$m" keepassxc
  if ! command -v keepassxc &>/dev/null && command -v flatpak &>/dev/null; then
    flatpak install -y flathub org.keepassxc.KeePassXC || log WARN "Flatpak KeePassXC install failed."
  fi
}

install_veracrypt(){
  local m="veracrypt"
  if command -v veracrypt &>/dev/null; then
    record_state "$m" veracrypt OK "already installed"
    return
  fi

  local raw major tmp asset_url deb
  raw=$(cat /etc/debian_version 2>/dev/null)
  if [[ "$raw" =~ ^([0-9]+)\. ]]; then
    major="${BASH_REMATCH[1]}"
  else
    major=13
  fi

  asset_url=$(curl -s https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest \
    | grep browser_download_url | grep -i "Debian-${major}-amd64.deb" | cut -d'"' -f4 | head -n1)
  if [ -z "$asset_url" ]; then
    asset_url=$(curl -s https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest \
      | grep browser_download_url | grep -i "Debian-12-amd64.deb" | cut -d'"' -f4 | head -n1)
  fi
  if [ -z "$asset_url" ]; then
    log WARN "No matching VeraCrypt release asset found for Debian $major (or fallback 12) — skipping."
    record_state "$m" veracrypt SKIP "no matching release asset found"
    return 1
  fi

  tmp=$(mktemp -d)
  deb="$tmp/veracrypt.deb"
  if wget -q -O "$deb" "$asset_url" && sudo apt-get install -y "$deb"; then
    record_state "$m" veracrypt OK "installed from $asset_url"
  else
    log WARN "VeraCrypt download/install failed."
    record_state "$m" veracrypt WARN "download/install failed"
  fi
  rm -rf "$tmp"
}

install_gnupg(){
  local m="gnupg" p
  for p in gnupg gnupg2 gpg-agent pinentry-qt kleopatra; do
    ensure_pkg "$m" "$p"
  done
}

install_timeshift(){
  local m="timeshift"
  ensure_pkg "$m" timeshift
  command -v timeshift &>/dev/null && record_state "$m" timeshift OK "run 'sudo timeshift-gtk' to configure snapshots before locking down your USB"
}

update_firmware(){
  local apply="$1" m="firmware"
  ensure_pkg "$m" fwupd
  [ -f /etc/init.d/fwupd ] && start_service "$m" fwupd
  sudo fwupdmgr refresh --force &>/dev/null || log WARN "Could not refresh firmware metadata."
  sudo fwupdmgr get-updates &>/dev/null || log INFO "No firmware updates available or device not supported."
  if [ "$apply" = "yes" ]; then
    sudo fwupdmgr update || log WARN "Firmware update encountered issues."
    record_state "$m" fwupdmgr OK "update applied"
  else
    record_state "$m" fwupdmgr SKIP "user chose not to apply now"
  fi
}

install_browser_extensions(){
  local m="browserext" ext_script="$SCRIPT_DIR/install_extensions.py"
  if [ ! -f "$ext_script" ]; then
    log WARN "install_extensions.py not found next to script — skipping."
    record_state "$m" install_extensions.py SKIP "file not present alongside script"
    return
  fi
  if ! command -v python3 &>/dev/null; then
    record_state "$m" install_extensions.py ERROR "python3 not installed"
    return
  fi
  if sudo python3 "$ext_script"; then
    record_state "$m" install_extensions.py OK "policy installed"
  else
    record_state "$m" install_extensions.py ERROR "script failed"
  fi
}

install_media_tools(){
  local m="media" p
  for p in yt-dlp ffmpeg vlc kde-spectacle celluloid obs-studio; do
    ensure_pkg "$m" "$p"
  done
}

install_docker(){
  local variant="$1" m="docker"
  if command -v docker &>/dev/null; then
    record_state "$m" docker OK "already installed: $(docker --version)"
    return
  fi

  if [ "$variant" = "ce" ]; then
    sudo apt-get install -y ca-certificates curl gnupg
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      # lsb_release -cs reports MX's own codename, not Debian's — use os-release instead.
      local codename
      codename=$(. /etc/os-release; echo "$VERSION_CODENAME")
      [ -z "$codename" ] && codename="trixie"
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $codename stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    sudo apt-get install -y docker.io docker-compose containerd
  fi

  ensure_group_membership "$m" docker
  start_service "$m" containerd
  start_service "$m" docker
  local compose_ver
  compose_ver=$(docker compose version 2>/dev/null || docker-compose version 2>/dev/null)
  record_state "$m" docker OK "installed ($variant) — compose: ${compose_ver:-unknown}"
}

install_zsh_ohmyzsh(){
  local m="zsh" current_shell
  ensure_pkg "$m" zsh
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  if [ "$current_shell" != "$(command -v zsh)" ]; then
    sudo chsh -s "$(command -v zsh)" "$USER"
    record_state "$m" shell OK "default shell changed to zsh — relogin required"
  fi
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    record_state "$m" oh-my-zsh OK "installed"
  fi
}

install_localsend(){
  local m="localsend"
  if command -v localsend &>/dev/null; then
    record_state "$m" localsend OK "already installed"
    return
  fi
  local url tmp
  url=$(curl -sL https://api.github.com/repos/localsend/localsend/releases/latest \
    | grep browser_download_url | grep '\.deb' | grep -iE 'x86_64|amd64' | cut -d'"' -f4 | head -n1)
  if [ -z "$url" ]; then
    log WARN "Could not resolve LocalSend download URL — skipping."
    record_state "$m" localsend SKIP "release asset not found"
    return
  fi
  tmp=$(mktemp -d)
  if wget -q -O "$tmp/localsend.deb" "$url" && sudo apt-get install -y "$tmp/localsend.deb"; then
    record_state "$m" localsend OK "installed from $url"
  else
    record_state "$m" localsend WARN "download/install failed"
  fi
  rm -rf "$tmp"
}

setup_airgap_toggle(){
  local m="airgaptoggle" desktop_dir
  desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
  mkdir -p "$desktop_dir"
  TOGGLE_PATH="$desktop_dir/toggle_network.sh"

  cat > "$TOGGLE_PATH" <<'TOGGLE_EOF'
#!/bin/bash
# Airgap network kill-switch (generated by mx_post_install_sysvinit.sh).
# Uses sudo -A/kdialog --password so it works with no controlling terminal
# (e.g. double-clicked from the desktop), unlike running kdialog itself as root.
WORKDIR="$HOME/.mx_post_install"
mkdir -p "$WORKDIR"
ASKPASS="$WORKDIR/kdialog_askpass.sh"
STATE_FILE="$WORKDIR/ufw_profile"

if [ ! -f "$ASKPASS" ]; then
  cat > "$ASKPASS" <<'ASKPASS_EOF'
#!/bin/bash
kdialog --password "Enter your sudo password:"
ASKPASS_EOF
  chmod +x "$ASKPASS"
fi
export SUDO_ASKPASS="$ASKPASS"

run_privileged(){ sudo -A "$@"; }

if service network-manager status &>/dev/null; then
  run_privileged service network-manager stop
  run_privileged update-rc.d network-manager disable
  run_privileged ufw delete allow out 53/tcp
  run_privileged ufw delete allow out 53/udp
  run_privileged ufw delete allow out 80/tcp
  run_privileged ufw delete allow out 443/tcp
  run_privileged ufw default deny outgoing
  echo "airgap" > "$STATE_FILE"
  kdialog --title "Airgap Enabled" --msgbox "Network-manager disabled.
Outgoing traffic blocked.
System is isolated."
else
  run_privileged update-rc.d network-manager enable
  run_privileged service network-manager start
  run_privileged ufw allow out 53/tcp
  run_privileged ufw allow out 53/udp
  run_privileged ufw allow out 80/tcp
  run_privileged ufw allow out 443/tcp
  echo "lan" > "$STATE_FILE"
  kdialog --title "Network Enabled" --msgbox "Network-manager enabled.
DNS/HTTP/HTTPS ports opened."
fi
TOGGLE_EOF
  chmod +x "$TOGGLE_PATH"
  record_state "$m" toggle_network.sh OK "generated at $TOGGLE_PATH"
}

# ===========================================================================
# Menus
# ===========================================================================

contains(){
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

menu_preset(){
  kdialog --title "MX Linux Post-Install" --menu "Choose a setup preset:" \
    core "Core setup (recommended baseline)" \
    everything "Everything (adds firmware, Docker, Zsh, media extras, airgap toolkit)" \
    airgap "Airgap workstation (security/media focused, strict firewall)" \
    custom "Custom (pick modules yourself)" \
    exit "Exit"
}

checklist_default(){
  local tag="$1"
  case "$PRESET" in
    everything) echo on ;;
    core)
      case "$tag" in
        update|firewall|utilities|virtualization|python|pythonlibs|nodejs|keepassxc|veracrypt|gnupg|timeshift|browserext|media) echo on ;;
        *) echo off ;;
      esac ;;
    airgap)
      case "$tag" in
        update|firewall|utilities|gnupg|timeshift|keepassxc|veracrypt|media|localsend|airgaptoggle) echo on ;;
        *) echo off ;;
      esac ;;
    *) echo off ;;
  esac
}

menu_checklist(){
  local args=() tag
  for tag in "${MODULE_TAGS[@]}"; do
    args+=("$tag" "${MODULE_DESC[$tag]}" "$(checklist_default "$tag")")
  done
  kdialog --separate-output --title "MX Linux Post-Install" --checklist "Select modules to run:" "${args[@]}"
}

menu_firewall_radio(){
  kdialog --title "Firewall Profile" --radiolist "Choose a firewall profile:" \
    lan "LAN / Samba-permissive (recommended for a normal desktop)" on \
    airgap "Strict outbound-only (airgap workstation)" off
}

menu_docker_radio(){
  kdialog --title "Docker Variant" --radiolist "Choose Docker install method:" \
    default "docker.io + docker-compose (simple, Debian repo)" on \
    ce "docker-ce upstream repo (advanced)" off
}

run_module(){
  local tag="$1"
  case "$tag" in
    update) system_update ;;
    firewall) configure_firewall "$FIREWALL_PROFILE" ;;
    utilities) install_utilities ;;
    virtualization) install_virtualization ;;
    python) install_python_stack ;;
    pythonlibs) install_python_libraries ;;
    nodejs) install_nodejs ;;
    keepassxc) install_keepassxc ;;
    veracrypt) install_veracrypt ;;
    gnupg) install_gnupg ;;
    timeshift) install_timeshift ;;
    firmware) update_firmware "$FIRMWARE_APPLY" ;;
    browserext) install_browser_extensions ;;
    media) install_media_tools ;;
    docker) install_docker "$DOCKER_VARIANT" ;;
    zsh) install_zsh_ohmyzsh ;;
    localsend) install_localsend ;;
    airgaptoggle) setup_airgap_toggle ;;
  esac
}

main(){
  while true; do
    PRESET=$(menu_preset)
    if [ $? -ne 0 ] || [ "$PRESET" = "exit" ] || [ -z "$PRESET" ]; then
      break
    fi

    local selected_raw
    selected_raw=$(menu_checklist)
    if [ $? -ne 0 ]; then
      continue
    fi
    local -a selected_modules=()
    [ -n "$selected_raw" ] && mapfile -t selected_modules <<< "$selected_raw"
    if [ ${#selected_modules[@]} -eq 0 ]; then
      kdialog --sorry "No modules selected."
      continue
    fi

    FIREWALL_PROFILE="lan"
    if contains firewall "${selected_modules[@]}"; then
      FIREWALL_PROFILE=$(menu_firewall_radio) || { kdialog --sorry "Cancelled."; continue; }
    fi

    DOCKER_VARIANT="default"
    if contains docker "${selected_modules[@]}"; then
      DOCKER_VARIANT=$(menu_docker_radio) || { kdialog --sorry "Cancelled."; continue; }
    fi

    FIRMWARE_APPLY="no"
    if contains firmware "${selected_modules[@]}"; then
      kdialog --title "Firmware Updates" --yesno "Apply available firmware updates now (via fwupdmgr)?" && FIRMWARE_APPLY="yes"
    fi

    local -a to_run=() tag
    for tag in "${EXEC_ORDER[@]}"; do
      contains "$tag" "${selected_modules[@]}" && to_run+=("$tag")
    done

    local total=${#to_run[@]} idx=0 cancelled=false
    open_progress "Starting install..." "$total"
    for tag in "${to_run[@]}"; do
      idx=$((idx+1))
      pb_set_label "${MODULE_DESC[$tag]}"
      if pb_was_cancelled; then
        cancelled=true
        break
      fi
      run_module "$tag"
      LAST_PCT=$(( idx * 100 / total ))
      pb_set_value "$LAST_PCT"
      render_dashboard
    done
    pb_close
    render_dashboard true

    if [ "$cancelled" = true ]; then
      kdialog --sorry "Installation cancelled by user."
    else
      kdialog --title "Complete" --msgbox "Run complete.
Dashboard: $DASHBOARD
Log: $LOGFILE"
    fi

    if [ "$cancelled" != true ] && contains airgaptoggle "${to_run[@]}"; then
      kdialog --title "Airgap" --yesno "Enable airgap mode now (disable networking)?" && "$TOGGLE_PATH"
    fi
  done
}

cleanup(){
  local rc=$?
  [ -n "${KEEPALIVE_PID:-}" ] && kill "$KEEPALIVE_PID" 2>/dev/null
  [ -n "${PROGRESS_SERVICE:-}" ] && pb_close 2>/dev/null
  if [ "$COMPLETED" != true ]; then
    record_state "script" "run" WARN "script exited before completion (rc=$rc)"
  fi
  render_dashboard true 2>/dev/null
}

# ===========================================================================
# Main execution
# ===========================================================================

require_tty "$@"
check_root
check_sysvinit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$HOME/.mx_post_install"
mkdir -p "$WORKDIR/logs"
LOGFILE="$WORKDIR/logs/run_$(date +%Y%m%d_%H%M%S).log"
DASHBOARD="$WORKDIR/dashboard.html"
STATE_FILE="$WORKDIR/state.tsv"
UFW_PROFILE_FILE="$WORKDIR/ufw_profile"
: > "$STATE_FILE"
START_EPOCH=$(date +%s)
RUN_STARTED="$(date '+%Y-%m-%d %H:%M:%S')"
LAST_PCT=0
COMPLETED=false
QDBUS_BIN=""
PROGRESS_SERVICE=""
PROGRESS_OBJECT=""
TOGGLE_PATH=""

exec > >(tee -a "$LOGFILE") 2>&1

echo "=== MX Linux Post-Install (SysVinit, KDE Plasma) Started ==="
echo "Log: $LOGFILE"
echo

trap cleanup EXIT

sudo_keepalive
check_connectivity

log INFO "Refreshing package index..."
sudo apt-get update

ensure_runtime_deps
render_dashboard
setsid -f xdg-open "$DASHBOARD" >/dev/null 2>&1 &

main

COMPLETED=true
echo "=== MX Linux Post-Install Finished ==="
exit 0
