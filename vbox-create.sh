#!/bin/bash

NAME="$1"
ISO="$2"

VBOX="/usr/bin/VBoxManage"
VBOXUI="/usr/bin/VBoxSDL"
MEMORY="1024" # Set 1gb ram
HDD_SIZE="32000" # Set 32gb harddrive
VM_DIR="/vmware/VirtualBox/$NAME"
HDD_FILE="$VM_DIR/hdd.vmi"
BRIDGE="wlp4s0" # Set the bridged interface to eth0

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

# Set up the networking
$(dirname $0)/vbox-set-up-networking.sh "$NAME"

# Set up shared folders
$(dirname $0)/vbox-add-shared-folders.sh "$NAME" "public"

# Enable APIC
echo ">>> Enabling APIC..."
$VBOX modifyvm "$NAME" --ioapic on || die "Failed to enable APIC"

# Setting video memory to 48 MB
$VBOX modifyvm "$NAME" --vram 48

# Setting the OS to Windows 64-bit
$VBOX modifyvm "$NAME" --ostype "WindowsNT_64"

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
$(dirname $0)/vbox-mount-cd.sh "$NAME" "$ISO"

# Turn the VM on, in the background
echo "Starting the UI in the background and waiting..."
$(dirname $0)/vbox-ui.sh "$NAME" &

echo "--------------------------------------------------------------------------------"
echo "Press <ENTER> when you're ready to install drivers (this will disconnect"
echo "the currenly loaded ISO)"
echo ""
echo "(Press ctrl+alt to release mouse from VM UI)"
echo "--------------------------------------------------------------------------------"

read

echo "Attaching guest additions CD..."
$(dirname $0)/vbox-install-additions.sh "$NAME"


echo "--------------------------------------------------------------------------------"
echo "Press <ENTER> when you're ready to take a base snapshot"
echo "(Press ctrl+alt to release mouse)"
echo "--------------------------------------------------------------------------------"

read

$(dirname $0)/vbox-snapshot.sh "$NAME" "base install"

echo "--------------------------------------------------------------------------------"
echo "Everything should be set up!"
echo "Here are a couple helpful commands:"
echo
echo "Linux:"
echo "  sudo mkdir /mnt/public; sudo mount -t vboxsf -o uid=ron public /mnt/public"
echo
echo "Windows:"
echo '  net use z: \\vboxsrv\public'
echo
echo "Once you've mounted the share, you can find some helpful scripts in"
echo " /mnt/public/scripts/<linux|windows>"
echo
echo "--------------------------------------------------------------------------------"
