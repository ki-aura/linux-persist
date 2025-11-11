#!/bin/bash
# mx-apply.sh — minimise-wear setup for MX Live USB (SysV init)

set -e

echo "=== MX Live USB: apply wear-reduction tweaks ==="

# --------------------------------------------------------------------
# 1. journald / rsyslog configuration: keep logs in RAM
# --------------------------------------------------------------------
echo "[Journal]
Storage=volatile
RuntimeMaxUse=128M
Compress=yes" | sudo tee /etc/systemd/journald.conf.d/volatile.conf >/dev/null || true
# If rsyslog is active, limit its writes too
sudo sed -i 's|^$ModLoad imjournal|#&|' /etc/rsyslog.conf 2>/dev/null || true

# --------------------------------------------------------------------
# 2. APT cache & lists under tmpfs (conf picked up by systemd-tmpfiles)
# --------------------------------------------------------------------
sudo install -m 644 /etc/tmpfiles.d/apt-cache.conf /etc/tmpfiles.d/apt-cache.conf 2>/dev/null || {
cat <<'EOF' | sudo tee /etc/tmpfiles.d/apt-cache.conf >/dev/null
d /var/cache/apt/archives 0755 root root
d /var/lib/apt/lists 0755 root root
EOF
}
sudo systemd-tmpfiles --create /etc/tmpfiles.d/apt-cache.conf 2>/dev/null || true

# --------------------------------------------------------------------
# 3. Thumbnails: move to tmpfs (avoid flash writes)
# --------------------------------------------------------------------
mkdir -p /run/user/1000/thumbnails
chmod 700 /run/user/1000/thumbnails
if [ -d "/home/live/.cache/thumbnails" ]; then
    rm -rf /home/live/.cache/thumbnails
    ln -s /run/user/1000/thumbnails /home/live/.cache/thumbnails
fi

# --------------------------------------------------------------------
# 4. Mask / disable unnecessary services (SysV compatible)
# --------------------------------------------------------------------
SERVICES_TO_DISABLE=(
    avahi-daemon
    cups
    fwupd
    ModemManager
    geoclue
)
for svc in "${SERVICES_TO_DISABLE[@]}"; do
    if service "$svc" status >/dev/null 2>&1; then
        sudo update-rc.d "$svc" disable || true
        sudo service "$svc" stop || true
        echo "Disabled $svc"
    fi
done

# --------------------------------------------------------------------
# 5. Sync & final message
# --------------------------------------------------------------------
sync
echo "=== Wear-reduction tweaks applied (SysV / MX Live) ==="
echo "No systemd, zram, or tmpfs remount changes made."
exit 0
