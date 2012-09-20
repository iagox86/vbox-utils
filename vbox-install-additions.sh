#!/bin/bash

NAME="$1"

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
VBOXADDITIONS="/vmware/iso/VBoxGuestAdditions_4.1.18.iso"
VM_DIR="/vmware/VirtualBox/$NAME"

die()
{
  $VBOX unregistervm "$NAME" --delete
  echo "ERROR: ${1}"
  exit
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit
fi

$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$VBOXADDITIONS" --port 0 --device 1 || die "Failed to attach VBoxAdditions"

