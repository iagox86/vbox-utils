#!/bin/bash

VBOX="/usr/bin/VBoxManage"
NAME="$1"
SHARE="$2"

die()
{
  echo "ERROR: ${1}"
  exit
}

if [ $# -ne 2 ]; then
  echo "Usage: $0 <name> <public|private>"
fi

echo ">>> Removing the old share that we don't use anymore..."
$VBOX sharedfolder remove "$NAME" --name "shared" 2>/dev/null

echo ">>> Removing the share..."
$VBOX sharedfolder remove "$NAME" --name "$SHARE" 2>/dev/null

echo ">>> Adding new share..."
$VBOX sharedfolder add "$NAME" --name "$SHARE" --hostpath "/vmware/shared/$SHARE" --automount || die "Couldn't add the share; make sure the VM is turned off"
