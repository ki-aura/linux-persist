#!/bin/sh
# Toggle UFW: enable if disabled, disable if enabled
if sudo ufw status | grep -q "Status: active"; then
  sudo ufw disable
  echo "ufw disabled"
else
  sudo ufw enable
  echo "ufw enabled"
fi
sudo ufw status verbose
