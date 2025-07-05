#!/bin/bash

# Define colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error_message() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success_message() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning_message() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_ufw_status() {
    log_message "Checking UFW (Uncomplicated Firewall) status..."
    if ! command -v ufw &> /dev/null; then
        error_message "UFW is not installed. Please install it first: sudo apt install ufw"
        return 1 # Indicate failure
    fi

    UFW_STATUS=$(sudo ufw status | grep Status | awk '{print $2}')
    if [[ "$UFW_STATUS" == "inactive" ]]; then
        warning_message "UFW is currently inactive. It's highly recommended to enable it."
        read -p "$(echo -e "${YELLOW}Do you want to enable UFW now? (y/n): ${NC}")" choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            log_message "Enabling UFW..."
            echo "y" | sudo ufw enable --force # --force to avoid prompts over SSH
            if [ $? -eq 0 ]; then
                success_message "UFW enabled successfully."
                UFW_STATUS="active" # Update status
                return 0 # Indicate success
            else
                error_message "Failed to enable UFW. Please check for errors."
                return 1 # Indicate failure
            fi
        else
            warning_message "UFW remains inactive. Firewall rules will not be enforced."
            return 1 # Indicate UFW is not active
        fi
    else
        success_message "UFW is active and running."
        return 0 # Indicate success
    fi
}

display_current_rules() {
    log_message "Current UFW rules:"
    sudo ufw status numbered
    echo
}

add_samba_rules_app_profile() {
    log_message "Adding Samba firewall rules using the UFW 'Samba' application profile."
    log_message "This will open UDP ports 137, 138 and TCP ports 139, 445 for incoming connections."
    
    local ip_or_network="" # Declare as local to prevent interference
    read -p "$(echo -e "${YELLOW}Do you want to restrict access to a specific IP address or network (e.g., 192.168.1.0/24)? (y/n): ${NC}")" restrict_choice
    
    if [[ "$restrict_choice" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e "${YELLOW}Enter the IP address or network (e.g., 192.168.1.0/24): ${NC}")" ip_or_network
        if [[ -z "$ip_or_network" ]]; then
            error_message "No IP or network provided. Aborting Samba rule addition."
            return 1
        fi
        log_message "Adding rule: Allow Samba from $ip_or_network"
        sudo ufw allow from "$ip_or_network" to any app Samba
    else
        log_message "Adding rule: Allow Samba from any IP address."
        sudo ufw allow Samba
    fi

    if [ $? -eq 0 ]; then
        success_message "Samba rules added successfully."
        return 0
    else
        error_message "Failed to add Samba rules."
        return 1
    fi
}

add_samba_rules_manual_ports() {
    log_message "Manually adding Samba firewall rules for ports:"
    log_message "  - UDP: 137, 138"
    log_message "  - TCP: 139, 445"
    
    local ip_or_network="" # Declare as local
    read -p "$(echo -e "${YELLOW}Do you want to restrict access to a specific IP address or network? (y/n): ${NC}")" restrict_choice
    
    if [[ "$restrict_choice" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e "${YELLOW}Enter the IP address or network (e.g., 192.168.1.0/24): ${NC}")" ip_or_network
        if [[ -z "$ip_or_network" ]]; then
            error_message "No IP or network provided. Aborting."
            return 1
        fi
    fi

    local all_rules_added_successfully=0 # Flag to track success
    local ports=( "137/udp" "138/udp" "139/tcp" "445/tcp" )
    for port_proto in "${ports[@]}"; do
        local port=$(echo "$port_proto" | cut -d'/' -f1)
        local proto=$(echo "$port_proto" | cut -d'/' -f2)

        if [[ -n "$ip_or_network" ]]; then
            log_message "Adding rule: Allow from $ip_or_network to any port $port ($proto)"
            sudo ufw allow from "$ip_or_network" to any port "$port" proto "$proto"
        else
            log_message "Adding rule: Allow any to any port $port ($proto)"
            sudo ufw allow "$port/$proto"
        fi

        if [ $? -ne 0 ]; then
            error_message "Failed to add rule for $port_proto."
            all_rules_added_successfully=1 # Set flag if any rule fails
        fi
    done
    
    if [ "$all_rules_added_successfully" -eq 0 ]; then
        success_message "Manual Samba rules addition process completed successfully."
        return 0
    else
        warning_message "Some manual Samba rules might not have been added successfully. Please review with 'ufw status numbered'."
        return 1
    fi
}

delete_samba_rules() {
    display_current_rules
    log_message "This will attempt to remove existing Samba rules. Be careful!"
    read -p "$(echo -e "${YELLOW}Are you sure you want to delete Samba-related rules? (y/n): ${NC}")" confirm_delete
    if [[ ! "$confirm_delete" =~ ^[Yy]$ ]]; then
        warning_message "Deletion cancelled."
        return 0
    fi

    log_message "Attempting to delete Samba rules by application profile first..."
    sudo ufw delete allow Samba &> /dev/null # Suppress output if rule doesn't exist
    
    log_message "Attempting to delete manual Samba port rules..."
    local ports=( "137/udp" "138/udp" "139/tcp" "445/tcp" )
    local rules_found=0
    for port_proto in "${ports[@]}"; do
        local port=$(echo "$port_proto" | cut -d'/' -f1)
        local proto=$(echo "$port_proto" | cut -d'/' -f2)
        
        # Check if the rule exists (simple grep check)
        if sudo ufw status | grep -q "ALLOW.*$port_proto"; then
            log_message "Deleting rule: $port_proto"
            sudo ufw delete allow "$port/$proto"
            rules_found=1
        fi
    done

    if [ "$rules_found" -eq 0 ]; then
        warning_message "No explicit Samba-related port rules found to delete."
    fi
    
    warning_message "Please review your UFW rules with 'sudo ufw status numbered' to ensure all desired Samba rules are removed."
    success_message "Samba rule deletion attempt completed."
}

refresh_plasma_firewall() {
    log_message "Attempting to refresh Plasma Firewall and its backend to fix 'backend disconnected' error."
    log_message "This usually involves restarting the kcm_firewall KCM and UFW."
    
    # Restart UFW service - this is the backend
    log_message "Restarting UFW service..."
    sudo systemctl restart ufw
    if [ $? -eq 0 ]; then
        success_message "UFW service restarted."
    else
        error_message "Failed to restart UFW service. Check system logs."
        warning_message "This might prevent Plasma Firewall from working correctly."
    fi

    log_message "Please close and reopen System Settings (especially the Firewall section)."
    log_message "This often helps Plasma Firewall re-establish connection with UFW."
}

restart_samba_services() {
    log_message "Restarting Samba services (smbd and nmbd) to apply changes."
    # Check if smbd service exists before trying to restart
    if systemctl list-unit-files | grep -q "smbd.service"; then
        sudo systemctl restart smbd nmbd
        if [ $? -eq 0 ]; then
            success_message "Samba services restarted successfully."
            return 0
        else
            error_message "Failed to restart Samba services. Check system logs."
            return 1
        fi
    else
        warning_message "Samba (smbd) service not found. Is Samba installed?"
        return 1
    fi
}

perform_all_recommended_steps() {
    log_message "Starting the recommended initial Samba firewall setup..."
    log_message "This will:"
    log_message "1. Ensure UFW is active."
    log_message "2. Add Samba firewall rules using the 'Samba' application profile."
    log_message "3. Restart Samba services (smbd, nmbd)."
    log_message "4. Suggest refreshing Plasma Firewall GUI."
    echo
    
    read -p "$(echo -e "${YELLOW}Do you want to proceed with these steps? (y/n): ${NC}")" confirm_all
    if [[ ! "$confirm_all" =~ ^[Yy]$ ]]; then
        warning_message "Recommended steps cancelled."
        return 0
    fi

    # Step 1: Check UFW status and enable if needed
    if ! check_ufw_status; then
        error_message "UFW is not active. Cannot proceed with Samba firewall setup."
        return 1
    fi

    # Step 2: Add Samba Rules
    add_samba_rules_app_profile
    
    # Step 3: Restart Samba Services
    restart_samba_services

    # Step 4: Suggest refreshing Plasma Firewall
    refresh_plasma_firewall
    
    success_message "Recommended Samba firewall setup process completed!"
    display_current_rules
}


main_menu() {
    while true; do
        clear
        echo -e "${GREEN}===========================================${NC}"
        echo -e "${GREEN}  MX Linux Samba Firewall Manager${NC}"
        echo -e "${GREEN}===========================================${NC}"
        echo -e "${BLUE}  1. Check UFW Status & Current Rules${NC}"
        echo -e "${BLUE}  2. Add Samba Firewall Rules (Recommended: UFW App Profile)${NC}"
        echo -e "${BLUE}  3. Add Samba Firewall Rules (Manual Ports)${NC}"
        echo -e "${BLUE}  4. Delete Samba Firewall Rules${NC}"
        echo -e "${BLUE}  5. Restart Samba Services (smbd, nmbd)${NC}"
        echo -e "${BLUE}  6. Perform Recommended Initial Samba Setup (All-in-One)${NC}" # New option
        echo -e "${BLUE}  7. Attempt to Refresh Plasma Firewall (Fix Backend Disconnect)${NC}"
        echo -e "${RED}  8. Exit${NC}"
        echo -e "${GREEN}===========================================${NC}"

        read -p "$(echo -e "${YELLOW}Enter your choice: ${NC}")" choice

        case $choice in
            1)
                check_ufw_status
                display_current_rules
                read -p "Press Enter to continue..."
                ;;
            2)
                add_samba_rules_app_profile
                display_current_rules
                read -p "Press Enter to continue..."
                ;;
            3)
                add_samba_rules_manual_ports
                display_current_rules
                read -p "Press Enter to continue..."
                ;;
            4)
                delete_samba_rules
                read -p "Press Enter to continue..."
                ;;
            5)
                restart_samba_services
                read -p "Press Enter to continue..."
                ;;
            6) # New case for all-in-one
                perform_all_recommended_steps
                read -p "Press Enter to continue..."
                ;;
            7)
                refresh_plasma_firewall
                read -p "Press Enter to continue..."
                ;;
            8)
                log_message "Exiting Samba Firewall Manager. Goodbye!"
                exit 0
                ;;
            *)
                error_message "Invalid choice. Please enter a number between 1 and 8."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    error_message "This script must be run with root privileges. Please use 'sudo ./samba_firewall_manager.sh'"
    exit 1
fi

# Initial check for UFW
check_ufw_status_on_start() {
    if ! command -v ufw &> /dev/null; then
        error_message "UFW is not installed. Please install it first: sudo apt install ufw"
        exit 1
    fi
    UFW_STATUS=$(sudo ufw status | grep Status | awk '{print $2}')
    if [[ "$UFW_STATUS" == "inactive" ]]; then
        warning_message "UFW is currently inactive. Consider enabling it for security."
    fi
}
check_ufw_status_on_start

# Start the main menu loop
main_menu
