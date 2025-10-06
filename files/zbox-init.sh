#!/bin/zsh

# Protect from history expansion (!xyz)
setopt NO_HIST_EXPAND

# Path to the temporary OVF environment file
ZBOX_OVFENV_FILE="/tmp/ovfenv.xml"
# Path to the configuration file
ZBOX_CONFIG_FILE="/etc/zbox.config"

# Parse command line arguments
EXTEND_DISK_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --extend-disk)
            EXTEND_DISK_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--extend-disk]"
            exit 1
            ;;
    esac
done


log() {
    local message="$1"                           # The message to log
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S') # Current timestamp

    echo "$message"
    # Append the timestamp and message to the CONFIG_FILE
    echo "[$timestamp] $message" >>$ZBOX_CONFIG_FILE
}


# Function to fetch OVF settings
appliance_config_ovf_settings() {
    log "Fetching OVF settings..."
    # Get OVF environment and save to file
    vmtoolsd --cmd 'info-get guestinfo.ovfEnv' >$ZBOX_OVFENV_FILE

    # Parse OVF properties using sed
    OVF_HOSTNAME=$(sed -n 's/.*Property oe:key="guestinfo.hostname" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_DNS=$(sed -n 's/.*Property oe:key="guestinfo.dns" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_DOMAIN=$(sed -n 's/.*Property oe:key="guestinfo.domain" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_GATEWAY=$(sed -n 's/.*Property oe:key="guestinfo.gateway" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_IPADDRESS=$(sed -n 's/.*Property oe:key="guestinfo.ipaddress" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_NETPREFIX=$(sed -n 's/.*Property oe:key="guestinfo.netprefix" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    OVF_PASSWORD=$(sed -n 's/.*Property oe:key="guestinfo.password" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)
    # Set default password if OVF_PASSWORD is not set
    OVF_PASSWORD=${OVF_PASSWORD:-"VMware1!"}
    OVF_SSHKEY=$(sed -n 's/.*Property oe:key="guestinfo.sshkey" oe:value="\([^"]*\).*/\1/p' $ZBOX_OVFENV_FILE)

    # Check for cloud-init configuration conflict using direct vmtoolsd queries
    OVF_METADATA=$(vmtoolsd --cmd 'info-get guestinfo.metadata' 2>/dev/null)
    OVF_USERDATA=$(vmtoolsd --cmd 'info-get guestinfo.userdata' 2>/dev/null)

    # Check for cloud-init configuration conflict
    if [[ -n "$OVF_METADATA" ]] || [[ -n "$OVF_USERDATA" ]]; then
        log "=========================================="
        log "CLOUD-INIT DEPLOYMENT DETECTED"
        log "=========================================="
        log "Executing cloud-init..."
        log "=========================================="

        # Clean up cloud-init
        cloud-init clean --logs | tee -a $ZBOX_CONFIG_FILE

        # Init cloud-init
        cloud-init init --local | tee -a $ZBOX_CONFIG_FILE
        cloud-init init | tee -a $ZBOX_CONFIG_FILE

        # As we are bypassing "normal" systemd/cloud-init initialization
        # we need to bring up the network manually
        ifup eth0 | tee -a $ZBOX_CONFIG_FILE

        # Run cloud-init modules
        cloud-init modules --mode=config | tee -a $ZBOX_CONFIG_FILE
        cloud-init modules --mode=final | tee -a $ZBOX_CONFIG_FILE

        # Disable cloud-init
        touch /etc/cloud/cloud-init.disabled

        # Clean up tty1 service (cosmetic artefacts on console)
        systemctl restart getty@tty1.service

        # Clean up temporary file before exiting
        if [[ -f "$ZBOX_OVFENV_FILE" ]]; then
            rm -f "$ZBOX_OVFENV_FILE"
        fi

        exit 0
    else
        log "=========================================="
        log "ZBOX-INIT DEPLOYMENT DETECTED"
        log "=========================================="
        log "FQDN: $OVF_HOSTNAME.$OVF_DOMAIN"
        log "DNS: $OVF_DNS"
        log "Network: $OVF_IPADDRESS/$OVF_NETPREFIX"
        log "Gateway: $OVF_GATEWAY"
        log "SSH Key: $OVF_SSHKEY"
        log "=========================================="
    fi
}


# Function to configure the network
appliance_config_network() {
    log "Configuring network..."

    # Stop networking service first
    systemctl stop networking

    # Create /etc/network/interfaces file
    if [[ -n "$OVF_IPADDRESS" ]]; then
        # Static network configuration
        cat <<EOF >/etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
    address $OVF_IPADDRESS/$OVF_NETPREFIX
    gateway $OVF_GATEWAY
    dns-nameservers $OVF_DNS
EOF
    else
        # DHCP configuration
        cat <<EOF >/etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
EOF
    fi

    # Start networking service
    systemctl start networking
    log "Networking configured and restarted."
}


# Function to configure the host
appliance_config_host() {
    log "Configuring hostname..."

    # Set the hostname
    hostnamectl set-hostname $OVF_HOSTNAME

    # Create /etc/hosts file for dnsmasq expand-hosts directive
    if [[ -n "$OVF_HOSTNAME" && -n "$OVF_IPADDRESS" && -n "$OVF_DOMAIN" ]]; then
        cat <<EOF >/etc/hosts
127.0.0.1       localhost
$OVF_IPADDRESS  $OVF_HOSTNAME.$OVF_DOMAIN    $OVF_HOSTNAME
EOF
        log "Hostname and /etc/hosts configured."
    else
        log "Warning: Missing hostname, IP address, or domain for /etc/hosts configuration."
    fi
}


# Function to configure storage
appliance_config_storage() {
    log "Configuring storage..."

    # Display disk usage before extending partitions
    log "Disk usage before extending partitions:"
    duf -only local

    # Rescan the disk (detect size change)
    echo 1 > /sys/class/block/sda/device/rescan

    # Grow partition 2 on /dev/sda
    if growpart /dev/sda 2; then
        log "Successfully extended partition 2 on /dev/sda."
    else
        log "Failed to extend partition 2 on /dev/sda. Exiting..."
        return 1
    fi

    # Grow partition 5 on /dev/sda
    if growpart /dev/sda 5; then
        log "Successfully extended partition 5 on /dev/sda."
    else
        log "Failed to extend partition 5 on /dev/sda. Exiting..."
        return 1
    fi

    # Resize the physical volume
    if pvresize /dev/sda5; then
        log "Successfully resized physical volume /dev/sda5."
    else
        log "Failed to resize physical volume /dev/sda5. Exiting..."
        return 1
    fi

    # Extend the logical volume to use all available free space
    if lvextend -l +100%FREE /dev/vg/root; then
        log "Successfully extended logical volume /dev/vg/root."
    else
        log "Failed to extend logical volume /dev/vg/root. Exiting..."
        return 1
    fi

    # Resize the filesystem
    if resize2fs /dev/vg/root; then
        log "Successfully resized filesystem on /dev/vg/root."
    else
        log "Failed to resize filesystem on /dev/vg/root. Exiting..."
        return 1
    fi

    # Display disk usage
    log "Disk usage after resizing:"
    duf -only local
}


# Function to configure credentials
appliance_config_credentials() {
    log "Configuring credentials..."

    # Update root password
    if [[ -n "$OVF_PASSWORD" ]]; then
        echo "root:$OVF_PASSWORD" | chpasswd
        log "Root password updated."
    else
        log "Warning: No password provided in OVF properties."
    fi

    # Add SSH key
    if [[ -n "$OVF_SSHKEY" ]]; then
        echo "$OVF_SSHKEY" >> /root/.ssh/authorized_keys
        log "SSH key added to authorized_keys."
    else
        log "Warning: No SSH key provided in OVF properties."
    fi
}

# Function to configure the zbox admin user
appliance_config_user() {
    local ZADMIN_USER="zadmin"

    # Create user if not exists
    if id "$ZADMIN_USER" &>/dev/null; then
        log "User $ZADMIN_USER already exists, skipping configuration"
        return 0
    else
        log "Creating user $ZADMIN_USER..."
        useradd -m -s /bin/zsh "$ZADMIN_USER"
        echo "$ZADMIN_USER:$OVF_PASSWORD" | chpasswd
        usermod -aG sudo "$ZADMIN_USER"
    fi

    # Configure passwordless sudo
    local SUDO_FILE="/etc/sudoers.d/$ZADMIN_USER"
    if [ ! -f "$SUDO_FILE" ]; then
        echo "$ZADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
        chmod 440 "$SUDO_FILE"
        log "Passwordless sudo configured for $ZADMIN_USER"
    else
        log "Sudo config already exists for $ZADMIN_USER"
    fi

    # Copy shell and development environment configurations from root
    log "Copying shell configurations to $ZADMIN_USER..."

    # Copy .zshrc
    if [ -f $HOME/.zshrc ]; then
        cp -vf $HOME/.zshrc /home/$ZADMIN_USER/.zshrc
        log "Copied .zshrc"
    fi

    # Copy .zshenv (for atuin)
    if [ -f $HOME/.zshenv ]; then
        cp -vf $HOME/.zshenv /home/$ZADMIN_USER/.zshenv
        log "Copied .zshenv"
    fi

    # Copy oh-my-zsh directory
    if [ -d $HOME/.oh-my-zsh ]; then
        cp -rf $HOME/.oh-my-zsh /home/$ZADMIN_USER/.oh-my-zsh
        log "Copied .oh-my-zsh directory"
    fi

    # Copy posh themes
    if [ -d $HOME/.poshthemes ]; then
        cp -rf $HOME/.poshthemes /home/$ZADMIN_USER/.poshthemes
        log "Copied .poshthemes directory"
    fi

    # Copy cache directory (for oh-my-posh)
    if [ -d $HOME/.cache ]; then
        cp -rf $HOME/.cache /home/$ZADMIN_USER/.cache
        log "Copied .cache directory"
    fi

    # Copy tmux configuration
    if [ -d $HOME/.config/tmux ]; then
        mkdir -p /home/$ZADMIN_USER/.config
        cp -rf $HOME/.config/tmux /home/$ZADMIN_USER/.config/tmux
        log "Copied tmux configuration"
    fi

    # Copy tmux plugins
    if [ -d $HOME/.tmux ]; then
        cp -rf $HOME/.tmux /home/$ZADMIN_USER/.tmux
        log "Copied .tmux directory"
    fi

    # Copy atuin directory
    if [ -d $HOME/.atuin ]; then
        cp -rf $HOME/.atuin /home/$ZADMIN_USER/.atuin
        log "Copied .atuin directory"
    fi

    # Copy atuin config if it exists
    if [ -d $HOME/.local/share/atuin ]; then
        mkdir -p /home/$ZADMIN_USER/.local/share
        cp -rf $HOME/.local/share/atuin /home/$ZADMIN_USER/.local/share/atuin
        log "Copied atuin data directory"
    fi

    # Set ownership of entire home directory to the user
    chown -R $ZADMIN_USER:$ZADMIN_USER /home/$ZADMIN_USER
    log "Set ownership of /home/$ZADMIN_USER to $ZADMIN_USER"

    log "Shell configuration setup complete for $ZADMIN_USER"
}


# Main execution logic
main() {
    if [[ "$EXTEND_DISK_MODE" == "true" ]]; then
        appliance_config_storage
        return
    fi

    # Check if the configuration file already exists
    if [[ -f "$ZBOX_CONFIG_FILE" ]]; then
        echo "$ZBOX_CONFIG_FILE exists. This script has already been executed. Exiting..."
        exit 0
    fi

    # Execute configuration functions
    appliance_config_ovf_settings
    appliance_config_network
    appliance_config_host
    appliance_config_storage
    appliance_config_credentials
    appliance_config_user

    # Clean up temporary files
    if [[ -f "$ZBOX_OVFENV_FILE" ]]; then
        rm -vf "$ZBOX_OVFENV_FILE"
        log "Cleaned up temporary OVF environment file."
    fi

    echo "zBoxDesktop Setup complete"
}

# Invoke the main function
main