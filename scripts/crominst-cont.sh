# --- Install helper script to open vault (user-run, uses sudo) ---
echo "[*] Installing open-chrome-vault helper..."
cat > /usr/local/bin/open-chrome-vault <<'EOF'
#!/bin/bash
MAPPER_NAME="chromevault"
MOUNT_POINT="/secure-chrome"
VAULT_IMG="${HOME}/chrome-vault.img"

if [ ! -f "${VAULT_IMG}" ]; then
  echo "Vault image not found at ${VAULT_IMG}"
  exit 1
fi

sudo cryptsetup open "${VAULT_IMG}" "${MAPPER_NAME}" || exit 1
sudo mkdir -p "${MOUNT_POINT}"
sudo mount "/dev/mapper/${MAPPER_NAME}" "${MOUNT_POINT}" || exit 1
sudo chown "${USER}:${USER}" "${MOUNT_POINT}"
echo "Vault opened and mounted at ${MOUNT_POINT}"
EOF

chmod 755 /usr/local/bin/open-chrome-vault
chown root:root /usr/local/bin/open-chrome-vault

# --- Install root-only helper to close vault (called via pkexec) ---
echo "[*] Installing close-chrome-vault-helper..."
cat > /usr/local/bin/close-chrome-vault-helper <<'EOF'
#!/bin/bash
MAPPER_NAME="chromevault"
MOUNT_POINT="/secure-chrome"

if mountpoint -q "${MOUNT_POINT}"; then
  umount "${MOUNT_POINT}" || exit 1
fi

if [ -e "/dev/mapper/${MAPPER_NAME}" ]; then
  cryptsetup close "${MAPPER_NAME}" || exit 1
fi

exit 0
EOF

chmod 755 /usr/local/bin/close-chrome-vault-helper
chown root:root /usr/local/bin/close-chrome-vault-helper

# --- Install secure-chrome launcher (user-level) ---
echo "[*] Installing /usr/local/bin/secure-chrome..."
cat > /usr/local/bin/secure-chrome <<'EOF'
#!/bin/bash
MAPPER_NAME="chromevault"
MOUNT_POINT="/secure-chrome"

# Check vault mounted
if ! mountpoint -q "${MOUNT_POINT}"; then
  if command -v zenity >/dev/null 2>&1; then
    zenity --error --text="Chrome vault is not mounted.\n\nOpen a terminal and run: open-chrome-vault" 2>/dev/null
  else
    echo "Chrome vault is not mounted. Run: open-chrome-vault"
  fi
  exit 1
fi

# Ensure firejail exists
if ! command -v firejail >/dev/null 2>&1; then
  echo "firejail is not installed."
  exit 1
fi

# Prepare RAM-based cache
mkdir -p /tmp/chrome-cache /tmp/chrome-media

# Run Chrome under Firejail, no internal sandbox (broken on persistent USB)
firejail --quiet google-chrome-stable --no-sandbox \
  --disk-cache-dir=/tmp/chrome-cache \
  --media-cache-dir=/tmp/chrome-media "$@"

# After Chrome exits: try to auto-close the vault via pkexec
if command -v pkexec >/dev/null 2>&1; then
  pkexec /usr/local/bin/close-chrome-vault-helper
else
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Chrome vault still open" "Run: sudo umount ${MOUNT_POINT} && sudo cryptsetup close ${MAPPER_NAME}"
  else
    echo "Chrome vault still open. Run: sudo umount ${MOUNT_POINT} && sudo cryptsetup close ${MAPPER_NAME}"
  fi
fi
EOF

chmod 755 /usr/local/bin/secure-chrome
chown root:root /usr/local/bin/secure-chrome

# --- Separate desktop launcher for Secure Chrome ---
echo "[*] Creating desktop launcher for Secure Chrome..."
USER_APPS_DIR="${USER_HOME}/.local/share/applications"
mkdir -p "${USER_APPS_DIR}"

cat > "${USER_APPS_DIR}/secure-chrome.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Secure Chrome (Firejail + Vault)
Comment=Chrome with encrypted profile and Firejail sandbox
Exec=/usr/local/bin/secure-chrome
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

chown "${TARGET_USER}:${TARGET_USER}" "${USER_APPS_DIR}/secure-chrome.desktop"

echo
echo "[✓] Install complete."
echo "Usage per session:"
echo "  1) Open a terminal and run:  open-chrome-vault"
echo "  2) Use the menu entry:      Secure Chrome (Firejail + Vault)"
echo "  3) When Chrome exits, you'll get a pkexec prompt to auto-close the vault."
echo
