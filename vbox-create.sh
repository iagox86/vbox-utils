#!/bin/bash

NAME="$1"
ISO="$2"

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
VBOXADDITIONS="/vmware/iso/VBoxGuestAdditions_4.1.18.iso"
MEMORY="1024" # Set 1gb ram
HDD_SIZE="32000" # Set 32gb harddrive
VM_DIR="/vmware/VirtualBox/$NAME"
HDD_FILE="$VM_DIR/hdd.vmi"
BRIDGE="eth0" # Set the bridged interface to eth0

die()
{
  $VBOX unregistervm "$NAME" --delete
  rm "$HDD_FILE"
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

echo ">>> Checking if this VM already exists..."
$VBOX showvminfo "$NAME" > /dev/null 2>&1 && alreadyexists

# Create the directory where we're gonna be storing the harddrive
echo ">>> Creating a directory for the VM $VM_DIR..."
/bin/mkdir -p "$VM_DIR"

# Create and register the VM
echo ">>> Creating and registering the VM $NAME..."
$VBOX createvm --name "$NAME" --register || die "Failed to create VM"

# Set the memory to $MEMORY
echo ">>> Setting the memory to $MEMORY"
$VBOX modifyvm "$NAME" --memory $MEMORY || die "Failed to set memory"

# Set the first nic as bridged to eth0
echo ">>> Creating a network bridge to $BRIDGE..."
$VBOX modifyvm "$NAME" --nic1 bridged --bridgeadapter1 $BRIDGE || die "Failed to set NIC"

# Enable APIC
echo ">>> Enabling APIC..."
$VBOX modifyvm "$NAME" --ioapic on || die "Failed to enable APIC"


# Create a SCSI and a IDE interface
#$VBOX storagectl "$NAME" --name scsi --add scsi || die "Failed to create SCSI interface}"
echo ">>> Creating an IDE interface..."
$VBOX storagectl "$NAME" --name ide  --add ide || die "Failed to create IDE interface"

# Create a harddrive file
echo ">>> Cearing a harddrive: $HDD_FILE..."
$VBOX createhd --filename "$HDD_FILE" --size "$HDD_SIZE" || die "Failed to crate harddrive file: $HDD_FILE"

# Attach the Harddrive
echo ">>> Attaching the harddrive"
$VBOX storageattach "$NAME" --storagectl ide --type hdd --medium "$HDD_FILE" --port 0 --device 0 || die "Failed to attach $HDD_FILE"

# Attach the requested ISO
echo ">>> Attaching $ISO..."
$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$ISO" --port 0 --device 1 || die "Failed to attach the cdrom ISO"

# Turn the VM on, in the background
echo "Starting the UI and waiting..."
$VBOXUI --startvm "$NAME" --hostkey 306 308 320 > /dev/null 2>&1 &

echo "--------------------------------------------------------------------------------"
echo "Press <ENTER> when you're ready to take a base snapshot"
echo "(You should do it the first time the login screen is up or when it's"
echo "activated successfully)"
echo "(Press ctrl+alt to release mouse)"
echo "--------------------------------------------------------------------------------"
read
echo ">>> Pausing the VM..."
$VBOX controlvm "$NAME" pause || echo "Failed to pause"

echo ">>> Taking snapshot..."
$VBOX snapshot "$NAME" take "base install" || echo "Failed to take snapshot"

echo ">>> Resuming the VM..."
$VBOX controlvm "$NAME" resume || echo "Failed to resume"

echo "--------------------------------------------------------------------------------"
echo "Press <ENTER> when you're ready to install drivers"
echo "(Press ctrl+alt to release mouse)"
echo "--------------------------------------------------------------------------------"
read

echo "Attaching the ISO $VBOXADDITIONS..."
$VBOX storageattach "$NAME" --storagectl ide --type dvddrive --medium "$VBOXADDITIONS" --port 0 --device 1 || echo "Failed to attach the cdrom iso"

