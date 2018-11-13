#!/bin/bash

NAME="$1"
VBOXMANAGE="/usr/bin/VBoxManage"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit
fi

$VBOXMANAGE unregistervm --delete "$NAME"
