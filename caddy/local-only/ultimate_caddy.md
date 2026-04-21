Here is the automated bash script that will handle the complete installation, directory setup, and configuration for a local homelab environment on MX Linux.
## 🛠️ The Ultimate Caddy Homelab Script
This script automatically updates your repositories, installs Caddy via the official repository, sets up a secure and standard directory for your static files, and writes a local configuration on port 8080 that requires zero DNS mapping.
Copy and paste this code into your terminal:

cat << 'EOF' > setup_caddy.sh
#!/bin/bash
# Exit on any error
set -e

echo "🚀 Starting Automated Caddy Installation for MX Linux..."

# 1. Install required repository helper packages
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# 2. Grab official GPG key and add official repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# 3. Update and install Caddy
sudo apt update
sudo apt install -y caddy

# 4. Set up ideal isolated directory for the web files
# Note: systemd caddy cannot serve out of /home due to safety permissions
sudo mkdir -p /var/www/html/homelab
sudo chown -R caddy:caddy /var/www/html/homelab

# 5. Create a test homepage
echo "<h1>🏠 Welcome to your MX Linux Homelab!</h1><p>Served automatically by Caddy on port 8080.</p>" | sudo tee /var/www/html/homelab/index.html > /dev/null

# 6. Overwrite the default Caddyfile configuration
sudo tee /etc/caddy/Caddyfile > /dev/null << 'CADFILE'
:8080 {
    root * /var/www/html/homelab
    file_server
}
CADFILE

# 7. Start and enable systemd background service
sudo systemctl daemon-reload
sudo systemctl enable caddy
sudo systemctl restart caddy

echo "✨ All Done! Access your server at: http://localhost:8080"
echo "Or using your local IP from another device (e.g. http://192.168.1.50:8080)"
EOF
# Make script executable and run it
chmod +x setup_caddy.sh
./setup_caddy.sh

------------------------------
## Why this structure is better for your Homelab

* Security Permission: The script places files in /var/www/html/ because the standard systemd Caddy service is blocked from looking inside standard user /home directories by default Linux security protocols.
* True Background Service: It handles the background service for you. You do not need to keep a terminal window open running caddy run.
* Port 8080: Using port 8080 allows the server to run locally without interfering with any standard system web interfaces that might automatically grab port 80 or 443. [1] 

Would you like to extend this script to include a reverse proxy configuration for any existing self-hosted apps on your server? [2] 

[1] [https://www.linode.com](https://www.linode.com/docs/guides/how-to-install-and-configure-caddy-on-debian-10/)
[2] [https://lysrt.net](https://lysrt.net/blog/using-caddy/)
