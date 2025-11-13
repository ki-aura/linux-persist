#!/bin/bash
# apply-xubuntu-optim.sh
# Minimal, one-shot optimiser for Xubuntu 24.04 persistent-live.
# Assumes the live interactive user is named "xubuntu".
set -euo pipefail

if [[ "$(id -un)" != "root" ]]; then
  echo "ERROR: run this script as root (sudo ./apply-xubuntu-optim.sh)"
  exit 1
fi

USER_NAME="xubuntu"
HOME_DIR="/home/${USER_NAME}"
USER_UID="$(id -u "${USER_NAME}")"
USER_GID="$(id -g "${USER_NAME}")"

echo "[*] Starting Xubuntu one-shot optimisation for user ${USER_NAME}..."

# Install minimal packages
echo "[*] Installing packages: zram-tools iotop util-linux"
apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
apt-get install -y zram-tools iotop util-linux >/dev/null

# Enable zram swap
echo "[*] Enabling zram swap (zram-tools default config)"
systemctl enable --now zramswap.service 2>/dev/null || true

# journald: volatile, tighter caps
echo "[*] Writing journald volatile config"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/volatile.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
RuntimeMaxFileSize=2M
Compress=yes
EOF
systemctl restart systemd-journald

# apt tmpfiles: keep apt caches small
echo "[*] Installing apt tmpfiles rules"
cat > /etc/tmpfiles.d/apt-cache.conf <<'EOF'
d /var/cache/apt/archives 0755 root root -
d /var/lib/apt/lists 0755 root root -
EOF
# ensure tmpfiles rules applied now
systemd-tmpfiles --create

# Services to mask (write-heavy / noisy)
echo "[*] Masking noisy services"
cat > /tmp/services-to-mask.txt <<'EOF'
avahi-daemon.service
cups.service
cups.socket
cups.path
fwupd.service
ModemManager.service
geoclue.service
packagekit.service
tumblerd.service
systemd-coredump.socket
systemd-coredump.service
man-db.timer
update-notifier.service
update-notifier.timer
# tracker miners (if present)
tracker-miner-fs-3.service
tracker-extract-3.service
tracker-miner-rss-3.service
EOF

while read -r svc; do
  [[ -z "$svc" || "$svc" == \#* ]] && continue
  systemctl mask --now "$svc" 2>/dev/null || true
done < /tmp/services-to-mask.txt
rm -f /tmp/services-to-mask.txt

# Ensure /tmp is tmpfs (append to /etc/fstab; this file is single-use)
echo "[*] Appending /tmp tmpfs to /etc/fstab"
cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,nosuid,nodev,mode=1777,size=1024M 0 0
EOF

# Mount user's ~/.cache on tmpfs to reduce overlay writes
echo "[*] Appending user .cache tmpfs to /etc/fstab"
mkdir -p "${HOME_DIR}/.cache"
chown "${USER_UID}:${USER_GID}" "${HOME_DIR}/.cache"
cat >> /etc/fstab <<EOF
tmpfs ${HOME_DIR}/.cache tmpfs nosuid,nodev,uid=${USER_UID},gid=${USER_GID},mode=0755,size=256M 0 0
EOF

# Apply mounts immediately
echo "[*] Mounting fstab entries now"
mount -a

# Disable snap aggressive writes (limit refresh window)
if command -v snap >/dev/null 2>&1; then
  echo "[*] Tuning snap refresh window (no hard-disable)"
  snap set system refresh.timer=00:00-01:00 2>/dev/null || true
  systemctl stop snapd.seeded.service 2>/dev/null || true
fi

# Chrome/Chromium: small wrappers to put disk caches in /tmp and move Crashpad
echo "[*] Installing browser wrappers (if Chrome/Chromium present)"
install_wrapper() {
  wrapper_path="/usr/local/bin/$1"
  real_path="$2"
  cat > "${wrapper_path}" <<WRAP
#!/bin/sh
exec "${real_path}" --disk-cache-dir=/tmp --media-cache-dir=/tmp "\$@"
WRAP
  chmod 0755 "${wrapper_path}"
  echo "[+] Installed wrapper: ${wrapper_path}"
}

# helper to relocate Crashpad dir for a profile (move to /tmp and symlink)
relocate_crashpad() {
  profile_dir="$1"
  cp_from="$profile_dir/Crashpad"
  if [ -e "$cp_from" ] && [ ! -L "$cp_from" ]; then
    mv "$cp_from" "/tmp/Crashpad-$(basename "$profile_dir")" 2>/dev/null || true
  fi
  mkdir -p "/tmp/Crashpad-$(basename "$profile_dir")"
  ln -snf "/tmp/Crashpad-$(basename "$profile_dir")" "$cp_from"
  chown -R "${USER_UID}:${USER_GID}" "/tmp/Crashpad-$(basename "$profile_dir")" 2>/dev/null || true
}

# Google Chrome (deb)
if [ -x /usr/bin/google-chrome ]; then
  install_wrapper google-chrome /usr/bin/google-chrome
  if [ -d "${HOME_DIR}/.config/google-chrome" ]; then
    relocate_crashpad "${HOME_DIR}/.config/google-chrome"
  fi
fi

# Chromium (deb)
if [ -x /usr/bin/chromium ]; then
  install_wrapper chromium /usr/bin/chromium
  if [ -d "${HOME_DIR}/.config/chromium" ]; then
    relocate_crashpad "${HOME_DIR}/.config/chromium"
  fi
fi

# Snap Chromium (common): create wrapper if snap binary exists
if [ -x /snap/bin/chromium ] && [ ! -x /usr/local/bin/chromium ]; then
  install_wrapper chromium /snap/bin/chromium
  if [ -d "${HOME_DIR}/snap/chromium/current/.config/chromium" ]; then
    relocate_crashpad "${HOME_DIR}/snap/chromium/current/.config/chromium"
  fi
fi

# Note: Firefox disk-cache change is left to the user (about:config)
# Mask systemd-coredump and man-db already done above.

echo
echo "[✓] Done — Xubuntu one-shot optimisation applied."
echo "Reboot recommended to ensure mounts and masks persist across the live session."
