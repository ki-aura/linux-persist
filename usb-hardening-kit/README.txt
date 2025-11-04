USB Persistence Hardening Kit
=============================

This kit reduces persistent overlay writes and greatly extends USB life.

Contents:
- apply.sh (automation script)
- zramswap (zram configuration)
- volatile.conf (journald RAM-only config)
- apt-cache.conf (APT cache tmpfs directive)
- thumbnails.conf (thumbnail tmpfs redirect)
- services-to-mask.txt (background chatter reduction)

Required packages (installed automatically):
- util-linux
- zram-tools
- iotop

Usage:
------
1. boot persistent USB
2. copy this directory to ~/
3. cd ~/usb-hardening-kit
4. ./apply.sh
5. reboot

Safe, idempotent, reversible.
