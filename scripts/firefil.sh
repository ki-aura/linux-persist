##backup / restor

sudo lsblk -o name,size,model,serial,mountpoint

sudo dd if=/dev/sdX bs=4M status=progress | gzip -1 > usb-backup.img.gz

gunzip -c usb-backup.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
sync

##JUST PERSIST

sudo dd if=/dev/sdX4 bs=4M status=progress | gzip -1 > persist.img.gz

gunzip -c persist.img.gz | sudo dd of=/dev/sdX4 bs=4M status=progress



##firejail



