#!/bin/bash

NAME="$1"

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
VBOXADDITIONS="/vmware/iso/VBoxGuestAdditions.iso"
VM_DIR="/vmware/VirtualBox/$NAME"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit
fi

$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$VBOXADDITIONS" --port 0 --device 1 || echo "Failed to attach VBoxAdditions"

