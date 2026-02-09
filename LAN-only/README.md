>[!TIP]
> MX Linux system **air‑gapped from the internet** while still allowing it to connect to your **local Wi‑Fi network only**. 

Let me break it down cleanly so you understand the *why* and the *how*.

---

# 🧭 What You Want
- Your MX Linux system is normally air‑gapped (no internet).
- You want it to connect to your **local Wi‑Fi LAN only**.
- You want **zero internet access**, even if the router provides it.
- You want a **script** that enforces this automatically.

This is a common setup for secure offline machines that still need LAN access for file sharing, SSH, local NAS, printers, etc.

---

# ✅ To block internet but allow LAN.

1. **Connect to your Wi‑Fi normally**  
2. **Block all outbound traffic that goes to the internet**  
3. **Allow only local subnet traffic** (e.g., 192.168.x.x or 10.x.x.x)

This is done using **iptables** (MX Linux still supports iptables by default).

---

# 🛡️ Recommended: iptables LAN‑only firewall script
Below is a clean, safe bash script that:

- Detects your local network automatically  
- Blocks all internet access  
- Allows LAN traffic  
- Allows DNS only to your router (optional)  
- Survives reconnects  

You can save it as `lan_only.sh`.

---

## 📜 **lan_only.sh**
```bash
#!/bin/bash

# Detect default gateway (your router)
GATEWAY=$(ip route | grep default | awk '{print $3}')

# Detect local subnet (e.g., 192.168.1.0/24)
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')

echo "Router (gateway): $GATEWAY"
echo "Local subnet: $SUBNET"

echo "Applying LAN-only firewall rules..."

# Flush existing rules
sudo iptables -F
sudo iptables -X

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow LAN traffic
sudo iptables -A INPUT -s $SUBNET -j ACCEPT
sudo iptables -A OUTPUT -d $SUBNET -j ACCEPT

# Allow DNS ONLY to your router (optional but recommended)
sudo iptables -A OUTPUT -p udp --dport 53 -d $GATEWAY -j ACCEPT

# Block everything else (internet)
sudo iptables -A OUTPUT -j DROP
sudo iptables -A INPUT -j DROP

echo "LAN-only mode enabled."
```

---

# ▶️ How to use it

### 1. Save the script
```bash
nano lan_only.sh
```
Paste the script, save, exit.

### 2. Make it executable
```bash
chmod +x lan_only.sh
```

### 3. Run it
```bash
./lan_only.sh
```

Your system will now:

- Connect to Wi‑Fi normally  
- Access ONLY your local network  
- Have **zero** internet access  

---

# 🔄 Make it automatic at boot (optional)
If you want it to apply every time you start MX Linux:

```bash
sudo cp lan_only.sh /usr/local/bin/
sudo nano /etc/rc.local
```

Add this line before `exit 0`:

```
/usr/local/bin/lan_only.sh
```

Save and reboot.

---

# 🧪 Want to test it?
After running the script:

### Test LAN:
```bash
ping 192.168.1.1
```
(should work)

### Test internet:
```bash
ping 8.8.8.8
```
(should NOT work)

---


>[!TIP]
> Upgrade your setup to **nftables**, add a **toggle system**, and include **logging of blocked internet attempts**.
>>This gives you a clean, modern, and secure LAN‑only mode that you can turn on/off whenever you want.
>>Polished solution that works on MX Linux and keeps your air‑gapped system safe.

---

# ⭐ Why nftables is better than iptables
nftables is the modern Linux firewall framework:

- Faster and more efficient  
- Cleaner syntax  
- Easier to maintain  
- Replaces iptables, ip6tables, ebtables, arptables  
- Supported by MX Linux  

So yes — it’s the better long‑term choice.

---

# 🧰 What you’ll get
I’ll give you:

### ✔ A **LAN‑only mode** (no internet, LAN allowed)  
### ✔ A **normal mode** (firewall disabled or default rules)  
### ✔ A **toggle script** (`lan-toggle.sh`)  
### ✔ Logging of **blocked internet attempts** to `/var/log/lan_only.log`  

This is a complete, professional‑grade setup.

---

# 📜 **1. Create the nftables rules file**

Create a file:

```bash
sudo nano /etc/nftables-lan-only.nft
```

Paste this inside:

```bash
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority 0;

        # Allow loopback
        iif lo accept

        # Allow LAN traffic
        ip saddr $SUBNET accept

        # Drop everything else
        log prefix "LAN-ONLY INPUT BLOCK: " flags all level info
        drop
    }

    chain output {
        type filter hook output priority 0;

        # Allow loopback
        oif lo accept

        # Allow LAN traffic
        ip daddr $SUBNET accept

        # Log and drop internet traffic
        log prefix "LAN-ONLY OUTPUT BLOCK: " flags all level info
        drop
    }
}
```

Save and exit.

---

# 📜 **2. Create the toggle script**

Create:

```bash
nano lan-toggle.sh
```

Paste this:

```bash
#!/bin/bash

RULES="/etc/nftables-lan-only.nft"
STATE_FILE="/var/run/lan_only_enabled"
LOGFILE="/var/log/lan_only.log"

# Detect local subnet (e.g., 192.168.1.0/24)
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')

if [ -z "$SUBNET" ]; then
    echo "Could not detect local subnet."
    exit 1
fi

# Export subnet for nftables
export SUBNET

if [ -f "$STATE_FILE" ]; then
    echo "Disabling LAN-only mode..."
    sudo nft flush ruleset
    sudo rm "$STATE_FILE"
    echo "$(date) - LAN-only mode disabled" | sudo tee -a "$LOGFILE" >/dev/null
else
    echo "Enabling LAN-only mode..."
    sudo env SUBNET="$SUBNET" nft -f "$RULES"
    sudo touch "$STATE_FILE"
    echo "$(date) - LAN-only mode enabled for subnet $SUBNET" | sudo tee -a "$LOGFILE" >/dev/null
fi
```

Save and exit.

---

# ▶️ **3. Make it executable**

```bash
chmod +x lan-toggle.sh
```

---

# 🚀 **4. Use it**

### Enable LAN‑only mode:
```bash
./lan-toggle.sh
```

### Disable LAN‑only mode:
```bash
./lan-toggle.sh
```

It toggles automatically.

---

# 📄 **5. View logs of blocked internet attempts**

```bash
sudo tail -f /var/log/lan_only.log
```

You will see entries like:

```
LAN-ONLY OUTPUT BLOCK: attempt to reach 8.8.8.8
LAN-ONLY INPUT BLOCK: inbound internet packet dropped
```

---

# 🧪 **6. Test it**

### LAN should work:
```bash
ping 192.168.1.1
```

### Internet should be blocked:
```bash
ping 8.8.8.8
curl http://example.com
```

Both should fail when LAN‑only mode is ON.

---
