cat > apply.sh << 'EOF'
#!/bin/bash
set -e

echo "[*] Applying persistent USB hardening…"

# --- Ensure required packages ---
echo "[*] Installing prerequisites…"
sudo apt-get update -o Dir::Cache::pkgcache="" -o Dir::Cache::srcpkgcache="" >/dev/null
sudo apt-get install -y util-linux zram-tools iotop >/dev/null

# --- Enable zram ---
echo "[*] Configuring zram swap…"
sudo install -D -m 644 zramswap /etc/default/zramswap
sudo systemctl enable --now zramswap.service

# --- Make journald volatile ---
echo "[*] Configuring volatile journal…"
sudo install -D -m 644 volatile.conf /etc/systemd/journald.conf.d/volatile.conf
sudo systemctl daemon-reload
sudo systemctl restart systemd-journald

# --- tmpfs mounts ---
echo "[*] Adding tmpfs mounts to /etc/fstab…"
sudo cp /etc/fstab /etc/fstab.bak.hardening
grep -q '/tmp' /etc/fstab || echo "tmpfs  /tmp  tmpfs  defaults,noatime,mode=1777  0  0" | sudo tee -a /etc/fstab
grep -q '/var/log ' /etc/fstab || echo "tmpfs  /var/log  tmpfs  defaults,noatime,mode=0755  0  0" | sudo tee -a /etc/fstab
grep -q '/var/cache/apt/archives' /etc/fstab || echo "tmpfs  /var/cache/apt/archives  tmpfs  defaults,noatime,mode=0755  0  0" | sudo tee -a /etc/fstab
grep -q '/var/lib/apt/lists' /etc/fstab || echo "tmpfs  /var/lib/apt/lists  tmpfs  defaults,noatime,mode=0755  0  0" | sudo tee -a /etc/fstab

# --- noatime ---
echo "[*] Enabling noatime,nodiratime on overlay root…"
sudo sed -i 's/overlay \/ overlay rw/overlay \/ overlay rw,noatime,nodiratime/' /etc/fstab

# --- tmpfiles drop-ins ---
echo "[*] Installing tmpfiles drop-ins…"
sudo install -D -m 644 thumbnails.conf /etc/tmpfiles.d/thumbnails.conf
sudo install -D -m 644 apt-cache.conf /etc/tmpfiles.d/apt-cache.conf

# --- Mask noisy services ---
echo "[*] Masking unnecessary services…"
while read svc; do
  sudo systemctl mask --now "$svc" 2>/dev/null || true
done < services-to-mask.txt

echo "[*] Remounting filesystems…"
sudo mount -a

echo "[*] Persistent USB hardening complete!"
echo "Reboot recommended."
EOF
