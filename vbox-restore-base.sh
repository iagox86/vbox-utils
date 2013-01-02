#!/bin/bash

NAME="$1"
VBOX="/usr/bin/VBoxManage"

if [ $# -ne 1 ]; then
  echo "Usage: vbox-restore-base.sh <vm name>"
  exit
fi

echo ">>> Stopping the VM..."
$VBOX controlvm "$NAME" poweroff || echo "Failed to poweroff vm"

echo ">>> Restoring snapshot "
$VBOX snapshot "$NAME" restore "head" || echo "Failed to resture snapshot"

