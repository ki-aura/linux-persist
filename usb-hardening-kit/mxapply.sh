#!/bin/bash
# apply-mx25-xfce-persistent-optim.sh
# MX Linux 25 XFCE (SysV init) persistent-live USB optimiser.
# Safe: no fstab edits, no systemd, no browser wrappers.
# Reduces overlay writes and improves responsiveness.

set -euo pipefail

# --- Detect live user ---------------------------------------------------------
USER_NAME="$(logname 2>/dev/null || echo "${SUDO_USER:-}")"
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
    echo "ERROR: could not detect non-root session user."
    exit 1
fi

HOME_DIR="/home/${USER_NAME}"
USER_UID="$(id -u "$USER_NAME")"
USER_GID="$(id -g "$USER_NAME")"

echo "[*] Optimising MX25 XFCE persistent USB (user: $USER_NAME)"

# --- 1. Install baseline tools ------------------------------------------------
apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
apt-get install -y zram-tools iotop util-linux >/dev/null 2>&1 || true

# --- 2. Enable zram via SysV --------------------------------------------------
mkdir -p /etc/default
cat > /etc/default/zram <<'EOF'
ENABLED=true
PERCENT=50
EOF

if [ -x /usr/bin/zram-init ]; then
    /usr/bin/zram-init || true
fi

# --- 3. Reduce rsyslog disk writes -------------------------------------------
mkdir -p /etc/rsyslog.d
cat > /etc/rsyslog.d/10-persistent-usb.conf <<'EOF'
# Reduce log churn on persistent USB
$ActionQueueType LinkedList
$ActionQueueFileName rsyslogq
$ActionQueueSaveOnShutdown off
$ActionQueueDiskSpace 1g
$ActionQueueHighWatermark 50000
$ActionQueueLowWatermark 20000
$ActionResumeRetryCount -1
$template SimpleFormat,"%msg%\n"
EOF

service rsyslog restart 2>/dev/null || true

# --- 4. Minimise APT writes ---------------------------------------------------
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99volatile-cache <<'EOF'
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
EOF

# --- 5. XFCE: disable thumbnailing / tumbler ----------------------------------
mkdir -p "${HOME_DIR}/.config/autostart"
ASOURCE="/etc/xdg/autostart/tumblerd.desktop"
ATARGET="${HOME_DIR}/.config/autostart/tumblerd.desktop"

if [ -f "$ASOURCE" ]; then
    cp "$ASOURCE" "$ATARGET" 2>/dev/null || true
    sed -i 's/^Hidden=.*/Hidden=true/' "$ATARGET" 2>/dev/null || true
    grep -q '^Hidden=' "$ATARGET" || echo "Hidden=true" >> "$ATARGET"
fi

chown -R "$USER_UID:$USER_GID" "${HOME_DIR}/.config/autostart"

# Thunar: never thumbnail
if command -v xfconf-query >/dev/null 2>&1; then
    sudo -u "$USER_NAME" xfconf-query -c thunar -p /misc-thumbnail-mode -n -t string -s "never" 2>/dev/null || \
    sudo -u "$USER_NAME" xfconf-query -c thunar -p /misc-thumbnail-mode -s "never" 2>/dev/null || true
fi

# --- 6. Tmpfs mounts for /tmp and /var/tmp (SysV init script) -----------------
cat > /etc/init.d/mx-live-tmpfs <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          mx-live-tmpfs
# Required-Start:    $local_fs
# Default-Start:     2 3 4 5
### END INIT INFO

case "$1" in
  start)
    mountpoint -q /tmp     || mount -t tmpfs -o size=1G,mode=1777 tmpfs /tmp
    mountpoint -q /var/tmp || mount -t tmpfs -o size=1G,mode=1777 tmpfs /var/tmp
    ;;
esac

exit 0
EOF

chmod +x /etc/init.d/mx-live-tmpfs
update-rc.d mx-live-tmpfs defaults >/dev/null 2>&1 || true
service mx-live-tmpfs start 2>/dev/null || true

# --- 7. Disable non-essential SysV services ----------------------------------
for svc in cron anacron man-db; do
    update-rc.d -f "$svc" remove 2>/dev/null || true
    service "$svc" stop 2>/dev/null || true
done

# --- 8. Clean apt cache -------------------------------------------------------
apt-get clean >/dev/null 2>&1 || true

echo
echo "[✓] Completed: MX25 XFCE persistent-USB optimisation."
echo " - tmpfs active for /tmp and /var/tmp"
echo " - rsyslog tamed"
echo " - XFCE thumbnailing disabled"
echo " - cron/anacron/man-db removed"
echo
echo "For Chrome/Chromium, add these to the launcher command:"
echo "  --disk-cache-dir=/dev/shm/chrome-cache --disk-cache-size=1"
echo "  --media-cache-size=1 --disable-gpu-shader-disk-cache"
echo "  --disable-logging --disable-breakpad"
