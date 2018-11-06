#!/bin/bash

NAME="$1"
ISO="$2"

VBOX="/usr/bin/VBoxManage"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <name> <iso>"
  exit
fi

echo ">>> Attaching $ISO..."
$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$ISO" --port 0 --device 1 || echo "Failed to attach $ISO"
