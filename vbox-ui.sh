#!/bin/bash

NAME="$1"
VBOXUI="/usr/bin/VBoxSDL"
VBOXMANAGE="/usr/bin/VBoxManage"

if [ $# -ne 1 ]; then
  echo "Usage: vbox-ui <name>"
  exit
fi

$VBOXMANAGE controlvm "$NAME" --resume ||
  $VBOXMANAGE startvm "$NAME"
#$VBOXUI --startvm "$NAME" --hostkey 306 308 320

