#!/bin/bash

NAME="$1"

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
VM_DIR="/vmware/VirtualBox/$NAME"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit
fi

$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium emptydrive --port 0 --device 1 || echo "Failed to attach $ISO"

