#!/bin/bash

NAME="$1"
VBOX="/usr/bin/VBoxManage"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <vm name>"
  exit
fi

echo ">>> Setting the card to 82540EM..."
$VBOX modifyvm "$NAME" --nictype1 82540EM || echo "Failed to set the card"

