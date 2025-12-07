#!/bin/bash


# --- Configuration ---
MOUNT_POINT="/mnt/hgfs"
FSTAB_ENTRY=".host:/    ${MOUNT_POINT}    fuse.vmhgfs-fuse    defaults,allow_other,_netdev    0    0"

# Function to check if a command executed successfully
check_success() {
    if [ $? -ne 0 ]; then
        echo "🚨 ERROR: $1 failed. Exiting."
        exit 1
    fi
}

echo "--- 🛠️ Starting VMware Shared Folder Setup ---"

# 1. Install open-vm-tools
echo "1. Installing or updating 'open-vm-tools'..."
sudo apt update
check_success "apt update"
sudo apt install open-vm-tools open-vm-tools-desktop -y
check_success "open-vm-tools installation"

# Check if a reboot is needed after installation
if dpkg -l | grep -q "open-vm-tools"; then
    echo "   Installation complete. A **reboot** is highly recommended to start all services."
else
    echo "   open-vm-tools seem to be installed, continuing..."
fi

# 2. Configure Persistent Mount Point
echo "2. Configuring persistent mount point in ${MOUNT_POINT}..."

# Create the mount point directory if it doesn't exist
if [ ! -d "${MOUNT_POINT}" ]; then
    echo "   Creating mount directory: ${MOUNT_POINT}"
    sudo mkdir -p "${MOUNT_POINT}"
    check_success "Creating mount directory"
fi

# 3. Modify /etc/fstab
echo "3. Modifying /etc/fstab for persistent mounting..."

# Check if the fstab entry already exists to ensure idempotency
if ! grep -q "$FSTAB_ENTRY" /etc/fstab; then
    echo "   Adding fstab entry: $FSTAB_ENTRY"
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    check_success "fstab modification"
else
    echo "   fstab entry already exists. Skipping modification."
fi

# 4. Reload systemd daemon
echo "4. Reloading systemd daemon to process new fstab entry..."
sudo systemctl daemon-reload
check_success "systemctl daemon-reload"

# 5. Attempt to mount the shared folders
echo "5. Attempting to mount shared folders..."
sudo mount -a
check_success "mount -a command"

# 6. Verification
if mount | grep -q "${MOUNT_POINT}"; then
    echo "✅ SUCCESS! Shared folders are now mounted at ${MOUNT_POINT}"
    echo "   Available folders (from host machine):"
    ls -l "${MOUNT_POINT}"
else
    echo "⚠️ WARNING: Shared folders did not mount successfully. Please check VMware settings on your Mac."
fi

echo "--- 🎉 Setup Complete ---"

