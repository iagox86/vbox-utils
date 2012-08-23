#!/bin/bash

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
VBOXADDITIONS="/vmware/iso/VBoxGuestAdditions_4.1.18.iso"
MEMORY="1024" # Set 1gb ram
HARDDRIVE="32000" # Set 32gb harddrive
BRIDGE="eth0" # Set the bridged interface to eth0
NAME="$1"
ISO="$2"

die()
{
  $VBOX unregistervm "$NAME" --delete
  echo "ERROR: ${1}"
  exit
}

alreadyexists()
{
  echo "--------------------------------------------------------------------------------"
  echo "VM already exists; to remove, run:"
  echo "$VBOX unregistervm \"$NAME\" --delete"
  echo "--------------------------------------------------------------------------------"
  exit
}

if [ $# -ne 2 ]; then
  echo "Usage: create.sh <name> <iso>"
  exit
fi

$VBOX showvminfo "$NAME" > /dev/null && alreadyexists

# Create and register the VM
$VBOX createvm --name "$NAME" --register || die "Failed to create VM"

# Set the memory to $MEMORY
$VBOX modifyvm "$NAME" --memory $MEMORY || die "Failed to set memory"

# Set the first nic as bridged to eth0
$VBOX modifyvm "$NAME" --nic1 bridged --bridgeadapter1 $BRIDGE || die "Failed to set NIC"

# Create a SCSI and a IDE interface
$VBOX storagectl "$NAME" --name scsi --add scsi || die "Failed to create SCSI interface}"
$VBOX storagectl "$NAME" --name ide  --add ide || die "Failed to create IDE interface"

# Create a harddrive file
$VBOX createhd --filename hdd.vmi --size $HARDDRIVE || die "Failed to crate harddrive file: $HARDDRIVE"

# Attach the SCSI interface
$VBOX storageattach "$NAME" --storagectl scsi --type hdd --medium hdd.vmi --port 0 || die "Failed to attach hdd.vmi"

# Attach the requested ISO
$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$ISO" --port 0 --device 0 || die "Failed to attach the cdrom ISO"

# Turn the VM on, in the background
$VBOXUI --startvm "$NAME" --hostkey 306 308 320 > /dev/null 2>&1 &

echo "--------------------------------------------------------------------------------"
echo "Press <ENTER> when you're ready to install drivers"
echo "(Press ctrl+alt to release mouse)"
echo "--------------------------------------------------------------------------------"
read

$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$VBOXADDITIONS" --port 0 --device 0 || die "Failed to attach VBoxAdditions"

