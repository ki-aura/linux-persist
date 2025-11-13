#!/bin/bash

# --- VARIABLES ---
# Change 'psmouse' to 'i2c_hid' or whatever module you found in Step 1
TOUCHPAD_MODULE="psmouse"

# --- CHECK FOR ROOT PRIVILEGES ---
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run with sudo/root privileges."
  echo "Usage: sudo ./reset_touchpad.sh"
  exit 1
fi

echo "Attempting to reset the $TOUCHPAD_MODULE kernel module..."

# 1. REMOVE THE MODULE (This disables the touchpad)
echo "1. Removing module: $TOUCHPAD_MODULE"
if ! rmmod "$TOUCHPAD_MODULE"; then
  echo "ERROR: Failed to remove module. Is the module currently loaded?"
  exit 1
fi
sleep 1 # Wait a moment

# 2. LOAD THE MODULE (This re-enables the touchpad)
echo "2. Loading module: $TOUCHPAD_MODULE"
if ! modprobe "$TOUCHPAD_MODULE"; then
  echo "ERROR: Failed to load module. Check if the module name is correct."
  exit 1
fi
echo "✅ Touchpad module reset complete. Check if the touchpad is working."

