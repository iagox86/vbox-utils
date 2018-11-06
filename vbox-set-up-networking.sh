#!/bin/bash

NAME="$1"

VBOX="/usr/bin/VBoxManage"

die()
{
  echo "ERROR: ${1}"
  exit
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit
fi

# Set the first nic as bridged
echo ">>> Setting up nic1 as NAT..."
$VBOX modifyvm "$NAME" --nic1 nat --nictype1 82540EM --cableconnected1 on || die "Failed to set first NIC to NAT"

# Set the second nic as bridged
echo ">>> Bridging nic2 to enp0s31f6..."
$VBOX modifyvm "$NAME" --nic2 bridged --bridgeadapter2 enp0s31f6 --nictype2 82540EM --cableconnected2 on || die "Failed to set second NIC to bridged"

# Set the third nic as hostonly
echo ">>> Hooking up nic3 to the hostonly network vboxnet0..."
$VBOX modifyvm "$NAME" --nic3 hostonly --hostonlyadapter3 vboxnet0 --nictype3 82540EM --cableconnected3 on || die "Failed to set third NIC to hostonly"
