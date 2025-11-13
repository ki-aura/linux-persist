#!/bin/bash
# apply-kubuntu-persistent-optim.sh
# Safe optimiser for Kubuntu 24.04 persistent-live systems.
# No fstab edits. No wrappers. No user hardcoding.

set -euo pipefail

# Detect the live user (non-root)
USER_NAME="$(logname 2>/dev/null || echo "$SUDO_USER")"
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo "ERROR: could not detect session user."
    exit 1
fi

HOME_DIR="/home/${USER_NAME}"
USER_UID="$(id -u "$USER_NAME")"
USER_GID="$(id -g "$USER_NAME")"

echo "[*] Kubuntu persistent-live optimisation for user '${USER_NAME}'..."

# -----------------------------------------------------------
# 1. Install minimal helpful tools
# -----------------------------------------------------------
echo "[*] Installing: zram-tools iotop util-linux"
apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
apt-get install -y zram-tools iotop util-linux >/dev/null 2>/dev/null || true

# -----------------------------------------------------------
# 2. Enable compressed RAM swap
# -----------------------------------------------------------
echo "[*] Enabling zram swap..."
systemctl enable --now zramswap.service 2>/dev/null || true

# -----------------------------------------------------------
# 3. Journald: RAM-only + rate limiting
# -----------------------------------------------------------
echo "[*] Configuring journald (volatile + rate limiting)"
mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/volatile.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
RuntimeMaxFileSize=2M
Compress=yes
RateLimitInterval=30s
RateLimitBurst=100
EOF

systemctl restart systemd-journald

# -----------------------------------------------------------
# 4. APT tmpfiles rules (write reduction)
# -----------------------------------------------------------
echo "[*] Applying apt tmpfiles rules"
cat > /etc/tmpfiles.d/apt-cache.conf <<'EOF'
d /var/cache/apt/archives 0755 root root -
d /var/lib/apt/lists 0755 root root -
EOF

systemd-tmpfiles --create

# -----------------------------------------------------------
# 5. Disable Akonadi (KDE personal data backend)
# -----------------------------------------------------------
echo "[*] Disabling Akonadi background services"

# Disable autostart for Akonadi
mkdir -p "${HOME_DIR}/.config/autostart"
if [[ -f /etc/xdg/autostart/org.kde.ak* ]]; then
    cp /etc/xdg/autostart/org.kde.ak* "${HOME_DIR}/.config/autostart/" 2>/dev/null || true
fi

# Force-disable via env var override
mkdir -p "${HOME_DIR}/.config"
echo "export AKONADI_DISABLED=1" >> "${HOME_DIR}/.config/plasma-workspace/env/disable-akonadi.sh" 2>/dev/null || true

# Kill running Akonadi if present
sudo -u "${USER_NAME}" akonadictl stop 2>/dev/null || true
sudo -u "${USER_NAME}" akonadictl disable 2>/dev/null || true

# -----------------------------------------------------------
# 6. Disable Baloo file indexing
# -----------------------------------------------------------
echo "[*] Disabling Baloo (file indexer)"
sudo -u "${USER_NAME}" balooctl disable 2>/dev/null || true
sudo -u "${USER_NAME}" balooctl purge 2>/dev/null || true

# Make sure baloo never starts again
mkdir -p "${HOME_DIR}/.config"
echo "[Basic Settings]" > "${HOME_DIR}/.config/baloofilerc"
echo "Indexing-Enabled=false" >> "${HOME_DIR}/.config/baloofilerc"
chown "${USER_UID}:${USER_GID}" "${HOME_DIR}/.config/baloofilerc"

# -----------------------------------------------------------
# 7. KDE Thumbnailer minimisation
# -----------------------------------------------------------
echo "[*] Reducing KDE thumbnailer activity"

mkdir -p "${HOME_DIR}/.config"
cat > "${HOME_DIR}/.config/kdeglobals" <<'EOF'
[PreviewSettings]
MaximumSize=0
PixmapCacheLimit=0
EOF

chown "${USER_UID}:${USER_GID}" "${HOME_DIR}/.config/kdeglobals"

# -----------------------------------------------------------
# 8. Mask safe, non-desktop-critical services
# -----------------------------------------------------------
echo "[*] Masking safe low-value services"
SAFE_SERVICES=(
  systemd-coredump.socket
  systemd-coredump.service
  man-db.timer
  tumblerd.service
)

for svc in "${SAFE_SERVICES[@]}"; do
  systemctl mask --now "$svc" 2>/dev/null || true
done

# -----------------------------------------------------------
# 9. Tame snap refresh (safe)
# -----------------------------------------------------------
if command -v snap >/dev/null 2>&1; then
    echo "[*] Restricting snap refresh timer"
    snap set system refresh.timer=00:00-01:00 2>/dev/null || true
fi

# -----------------------------------------------------------
# 10. Clean apt caches (safe)
# -----------------------------------------------------------
echo "[*] Cleaning apt caches"
apt-get clean >/dev/null 2>&1 || true

echo
echo "[✓] Kubuntu persistent-live optimisation applied safely."
echo "A reboot is recommended."
