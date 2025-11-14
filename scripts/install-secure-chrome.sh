#!/bin/bash
# install-secure-chrome.sh
# One-shot setup: 8G LUKS vault + Firejail-secured Chrome launcher.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run this script with: sudo ./install-secure-chrome.sh"
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "Could not detect non-root user (SUDO_USER)."
  exit 1
fi

USER_HOME="$(eval echo "~${TARGET_USER}")"
VAULT_IMG="${USER_HOME}/chrome-vault.img"
MAPPER_NAME="chromevault"
MOUNT_POINT="/secure-chrome"
PROFILE_DIR="${USER_HOME}/.config/google-chrome"

echo "[*] User: ${TARGET_USER}"
echo "[*] Home: ${USER_HOME}"

# --- Ensure firejail is installed ---
echo "[*] Installing firejail (if needed)..."
apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
apt-get install -y firejail >/dev/null

# --- Create 8G LUKS vault if it doesn't exist ---
if [ -e "${VAULT_IMG}" ]; then
  echo "[*] Vault image already exists at ${VAULT_IMG}, skipping creation."
else
  echo "[*] Creating 8G LUKS2 vault at ${VAULT_IMG} (this may take a while)..."
  dd if=/dev/zero of="${VAULT_IMG}" bs=1M count=8192 status=progress
  echo "[*] Initialising LUKS on ${VAULT_IMG} (you'll be asked for a passphrase)..."
  cryptsetup luksFormat "${VAULT_IMG}"
fi

# --- Open and mount vault ---
if ! [ -e "/dev/mapper/${MAPPER_NAME}" ]; then
  echo "[*] Opening LUKS vault..."
  cryptsetup open "${VAULT_IMG}" "${MAPPER_NAME}"
fi

mkdir -p "${MOUNT_POINT}"
if ! mountpoint -q "${MOUNT_POINT}"; then
  echo "[*] Mounting vault on ${MOUNT_POINT}..."
  mount "/dev/mapper/${MAPPER_NAME}" "${MOUNT_POINT}"
fi

chown "${TARGET_USER}:${TARGET_USER}" "${MOUNT_POINT}"

# --- Create filesystem if needed (first run only) ---
if ! blkid "/dev/mapper/${MAPPER_NAME}" >/dev/null 2>&1; then
  echo "[*] Creating ext4 filesystem inside the vault..."
  mkfs.ext4 "/dev/mapper/${MAPPER_NAME}"
  # remount after mkfs
  umount "${MOUNT_POINT}" || true
  mount "/dev/mapper/${MAPPER_NAME}" "${MOUNT_POINT}"
  chown "${TARGET_USER}:${TARGET_USER}" "${MOUNT_POINT}"
fi

# --- Move Chrome profile into vault and symlink it ---
sudo -u "${TARGET_USER}" mkdir -p "${USER_HOME}/.config"

if [ -d "${PROFILE_DIR}" ] && [ ! -L "${PROFILE_DIR}" ]; then
  echo "[*] Moving existing Chrome profile into encrypted vault..."
  mv "${PROFILE_DIR}" "${MOUNT_POINT}/chrome-profile"
elif [ ! -e "${MOUNT_POINT}/chrome-profile" ]; then
  echo "[*] Creating new Chrome profile directory inside vault..."
  mkdir -p "${MOUNT_POINT}/chrome-profile"
  chown "${TARGET_USER}:${TARGET_USER}" "${MOUNT_POINT}/chrome-profile"
fi

# Ensure symlink points from ~/.config/google-chrome -> /secure-chrome/chrome-profile
if [ -e "${PROFILE_DIR}" ] && [ ! -L "${PROFILE_DIR}" ]; then
  echo "ERROR: ${PROFILE_DIR} exists and is not a symlink. Please inspect manually."
else
  rm -rf "${PROFILE_DIR}" 2>/dev/null || true
  ln -s "${MOUNT_POINT}/chrome-profile" "${PROFILE_DIR}"
fi

chown -h "${TARGET_USER}:${TARGET_USER}" "${PROFILE_DIR}"
chown -R "${TARGET_USER}:${TARGET_USER}" "${MOUNT_POINT}/chrome-profile"

echo "[*] Chrome profile is now inside encrypted vault and symlinked."

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
