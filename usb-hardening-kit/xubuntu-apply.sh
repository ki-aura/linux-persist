#!/bin/bash
set -euo pipefail

echo "[*] Xubuntu 24.04 persistent-live optimisation starting…"

# --- Detect the primary login user and home directory ---
TARGET_USER="${SUDO_USER:-$USER}"
read -r _ _ _ UID _ HOME_DIR _ < <(getent passwd "$TARGET_USER")
if [[ -z "${HOME_DIR:-}" || -z "${UID:-}" ]]; then
  echo "[-] Could not resolve home/uid for $TARGET_USER" >&2
  exit 1
fi

echo "[*] Operating on user: $TARGET_USER (uid $UID), home: $HOME_DIR"

# --- Helper: append a line to a file once ---
append_once() { # file, pattern, line
  local file="$1" pattern="$2" line="$3"
  sudo touch "$file"
  if ! sudo grep -qE "$pattern" "$file"; then
    echo "$line" | sudo tee -a "$file" >/dev/null
    echo "[+] Added to $file: $line"
  else
    echo "[=] Already present in $file: $line"
  fi
}

# --- Packages we need ---
echo "[*] Installing prerequisites…"
sudo apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
sudo apt-get install -y util-linux zram-tools iotop >/dev/null

# --- zram (uses your local ./zramswap if present) ---
if [[ -f zramswap ]]; then
  echo "[*] Installing zram config…"
  sudo install -D -m 0644 zramswap /etc/default/zramswap
fi
echo "[*] Enabling zram swap…"
sudo systemctl enable --now zramswap.service

# --- journald: volatile + tighter caps (1f) ---
echo "[*] Enforcing volatile journald with smaller runtime caps…"
sudo install -d -m 0755 /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/volatile.conf >/dev/null <<'JCONF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
RuntimeMaxFileSize=2M
Compress=yes
JCONF
sudo systemctl restart systemd-journald

# --- apt tmpfiles (keeps indices light) ---
if [[ -f apt-cache.conf ]]; then
  echo "[*] Installing apt tmpfiles rules…"
  sudo install -D -m 0644 apt-cache.conf /etc/tmpfiles.d/apt-cache.conf
  sudo systemd-tmpfiles --create
fi

# --- Mask your existing service list if provided ---
if [[ -f services-to-mask.txt ]]; then
  echo "[*] Masking services from services-to-mask.txt…"
  while read -r svc; do
    [[ -z "$svc" || "$svc" =~ ^# ]] && continue
    sudo systemctl mask --now "$svc" 2>/dev/null || true
  done < services-to-mask.txt
fi

# --- 1a: Disable XFCE thumbnailer (tumblerd) ---
echo "[*] Disabling XFCE thumbnailer (tumblerd)…"
sudo systemctl mask --now tumblerd.service 2>/dev/null || true

# --- 1e: Disable PackageKit metadata polling ---
echo "[*] Disabling PackageKit…"
sudo systemctl mask --now packagekit.service 2>/dev/null || true

# --- 3b: Disable systemd coredumps entirely ---
echo "[*] Disabling systemd coredumps…"
sudo systemctl mask --now systemd-coredump.socket 2>/dev/null || true
sudo systemctl mask --now systemd-coredump.service 2>/dev/null || true

# --- 3c: Disable man-db timer (no index rebuilds) ---
echo "[*] Disabling man-db.timer…"
sudo systemctl mask --now man-db.timer 2>/dev/null || true

# --- 7: Disable update-notifier (no background update checks) ---
echo "[*] Disabling update-notifier…"
sudo systemctl mask --now update-notifier.service 2>/dev/null || true
sudo systemctl mask --now update-notifier.timer 2>/dev/null || true

# --- 7 (optional): Disable Tracker miners if present ---
for svc in tracker-miner-fs-3.service tracker-extract-3.service tracker-mine
