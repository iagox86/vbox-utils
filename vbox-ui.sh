#!/bin/bash

NAME="$1"
VBOXUI="/usr/bin/VBoxSDL"

if [ $# -ne 1 ]; then
  echo "Usage: vbox-ui <name>"
  exit
fi

$VBOXUI --startvm "$NAME" --hostkey 306 308 320

