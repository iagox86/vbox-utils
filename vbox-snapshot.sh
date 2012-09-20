#!/bin/bash

NAME="$1"
SNAPSHOT="$2"
VBOX="/usr/bin/VBoxManage"

if [ $# -ne 2 ]; then
  echo "Usage: vbox-snapshot.sh <vm name> <snapshot name>"
  exit
fi

echo ">>> Pausing the VM..."
$VBOX controlvm "$NAME" pause || echo "Failed to pause"

echo ">>> Taking snapshot '$SNAPSHOT'..."
$VBOX snapshot "$NAME" take "$SNAPSHOT" || echo "Failed to take snapshot"

echo ">>> Resuming the VM..."
$VBOX controlvm "$NAME" resume || echo "Failed to resume"

