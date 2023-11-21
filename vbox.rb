# frozen_string_literal: true

require 'optparse'

# Things to look into:
# * Unattended install
# * Clipboard

UUID_REGEX = '[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}'

options = {}

global_opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] [subcommand [options]]"

  opts.on('-vPATH', '--vbox=PATH to the VBox binary') do |v|
    options[:vbox] = v
  end

  opts.separator ''

  opts.separator <<~HELP
    Commands:
       list        : List VMs
       info        : Info about a VM
       create      : Create a VM
       delete      : Delete a VM
       snapshot    : Snapshot a VM
       restore     : Restore a snapshot
       boot        : Boot a VM
       stop        : Stop a VM
       suspend     : Suspend a VM
       suspendall  : Suspend _all_ VMs

    Run '#{$PROGRAM_NAME} <command> --help' for more information on a specific command.
  HELP
end
global_opts.order!() # .order() is required to parse subcommands correctly

# Set some globals
VBOX = options[:vbox] || '/usr/bin/VBoxManage'
unless File.exist?(VBOX)
  warn "#{VBOX} does not exist"
  exit 1
end
unless File.executable?(VBOX)
  warn "#{VBOX} is not executable"
  exit 1
end

# Load a list of VMs
# VBoxManage list vms
VMS_BY_NAME = `#{VBOX} list vms`.split(/\n/).map do |line|
  unless line =~ /^"(.*)" \{(#{UUID_REGEX})\}/
    warn "Couldn't parse line from VBoxManage output: #{line}"
    exit 1
  end
  [Regexp.last_match(1), Regexp.last_match(2)]
end.to_h
VMS_BY_UUID = VMS_BY_NAME.invert()

if VMS_BY_UUID.length != VMS_BY_NAME.length
  warn "Warning: There are multiple VMs with the same name (or same UUID), that's bad!"
  exit 1
end

def opts_get_name_or_uuid(opts, options)
  opts.on('-uUUID', '--uuid=UUID', "The target VM's UUID") do |v|
    unless options[:name].nil?
      warn 'You must specify a UUID -or- a name, not both!'
      exit 1
    end

    unless v =~ /#{UUID_REGEX}/
      warn "This must be a valid UUID: #{v}"
      exit 1
    end

    unless VMS_BY_UUID.include?(v)
      warn "No VM found with uuid = #{v}"
      exit 1
    end

    options[:uuid] = v
  end
  opts.on('-nNAME', '--name=NAME', "The target VM's name") do |v|
    unless options[:uuid].nil?
      warn 'You must specify a UUID -or- a name, not both!'
      exit 1
    end

    unless VMS_BY_NAME.include?(v)
      warn "No VM found with name = \"#{v}\" (use the UUID if the name is weird)"
      exit 1
    end

    options[:name] = v
  end
end

def lookup_vm(options)
  uuid = options[:uuid]
  name = options[:name]

  if uuid
    name = VMS_BY_UUID[uuid]
    if name.nil?
      warn "No VM found with uuid #{uuid}!"
      exit 1
    end
  elsif name
    uuid = VMS_BY_NAME[name]
    if uuid.nil?
      warn "No VM found with name #{name}!"
      exit 1
    end
  else
    warn 'Name or UUID are required!'
    exit 1
  end

  { uuid: uuid, name: name }
end

subcommands = {
  'list' => OptionParser.new do |opts|
    opts.banner = 'Usage: list [options]'
    opts.on('-mREGEX', '--match=REGEX', 'Only show VMs that match the given regex (case insensitive)') do |v|
      options[:match] = v
    end
  end,

  'info' => OptionParser.new do |opts|
    opts.banner = 'Usage: info <--uuid=UUID|--name=NAME> [options]'
    opts_get_name_or_uuid(opts, options)
  end,

  'create' => OptionParser.new do |opts|
    opts.banner = 'Usage: create [options]'
    # opts.on("-f", "--[no-]force", "force verbosely") do |v|
    #   options[:force] = v
    # end
  end,

  'delete' => OptionParser.new do |opts|
    opts.banner = 'Usage: delete <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,

  'boot' => OptionParser.new do |opts|
    opts.banner = 'Usage: delete <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,

  'stop' => OptionParser.new do |opts|
    opts.banner = 'Usage: stop <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,

  'suspend' => OptionParser.new do |opts|
    opts.banner = 'Usage: suspend <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,

  'suspendall' => OptionParser.new do |opts|
    opts.banner = 'Usage: suspendall [options]'
  end,

  'snapshot' => OptionParser.new do |opts|
    opts.banner = 'Usage: snapshot <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,

  'restore' => OptionParser.new do |opts|
    opts.banner = 'Usage: restore <--uuid=UUID|--name=NAME> [options]'

    opts_get_name_or_uuid(opts, options)
  end,
}

# Get the subcommand
command = ARGV.shift

# Sanity check
unless subcommands.include?(command)
  puts global_opts.help()
  exit 1
end
subcommands[command].order!

case command
when 'list'
  puts 'UUID                                 Name'
  puts '----                                 ----'

  if options[:match]
    vm_names = VMS_BY_NAME.keys.select { |k| k =~ /#{options[:match]}/i }
  else
    vm_names = VMS_BY_NAME.keys
  end

  vm_names.each do |name|
    puts "#{VMS_BY_NAME[name]} #{name}"
  end
when 'info'
  vm = lookup_vm(options)

  info = `#{VBOX} showvminfo #{vm[:uuid]} --machinereadable`.split(/\n/).map do |line|
    if line =~ /^([^=]+)="(.*)"/
      # If the value is quoted
      [Regexp.last_match(1), Regexp.last_match(2)]

    elsif line =~ /^([^=]+)=(.*)/
      # If the value is unquoted
      [Regexp.last_match(1), Regexp.last_match(2)]

    else
      # Blank lines or lines without '=' (because "--machinereadable" isn't very machine readable)
      # .compact() will remove the nil fields
      nil
    end
  end.compact.to_h

  pp info
  # VBoxManage showvminfo <uuid | vmname> [--details] [--machinereadable]
when 'create'
  # TODO
when 'delete'
  # TODO
when 'snapshot'
  # TODO
when 'restore'
  # TODO
when 'boot'
  # TODO
when 'stop'
  # TODO
when 'suspend'
  # TODO
when 'suspendall'
  # TODO
end

exit 0

# NAME="$1"
# ISO="$2"

# VBOX="/usr/bin/VBoxManage"
# VBOXUI="/usr/bin/VBoxSDL"
# MEMORY="1024" # Set 1gb ram
# HDD_SIZE="32000" # Set 32gb harddrive
# VM_DIR="/vmware/VirtualBox/$NAME"
# HDD_FILE="$VM_DIR/hdd.vmi"
# BRIDGE="wlp4s0" # Set the bridged interface to eth0

# die()
# {
#   $VBOX unregistervm "$NAME" --delete
#   rm "$HDD_FILE"
#   echo "ERROR: ${1}"
#   exit
# }

# alreadyexists()
# {
#   echo "--------------------------------------------------------------------------------"
#   echo "VM already exists; to remove, run:"
#   echo "$VBOX unregistervm \"$NAME\" --delete"
#   echo "--------------------------------------------------------------------------------"
#   exit
# }

# if [ $# -ne 2 ]; then
#   echo "Usage: create.sh <name> <iso>"
#   exit
# fi

# echo ">>> Checking if this VM already exists..."
# $VBOX showvminfo "$NAME" > /dev/null 2>&1 && alreadyexists

# # Create the directory where we're gonna be storing the harddrive
# echo ">>> Creating a directory for the VM $VM_DIR..."
# /bin/mkdir -p "$VM_DIR"

# # Create and register the VM
# echo ">>> Creating and registering the VM $NAME..."
# $VBOX createvm --name "$NAME" --register || die "Failed to create VM"

# # Set the memory to $MEMORY
# echo ">>> Setting the memory to $MEMORY"
# $VBOX modifyvm "$NAME" --memory $MEMORY || die "Failed to set memory"

# # Set up the networking
# $(dirname $0)/vbox-set-up-networking.sh "$NAME"

# # Set up shared folders
# $(dirname $0)/vbox-add-shared-folders.sh "$NAME" "public"

# # Enable APIC
# echo ">>> Enabling APIC..."
# $VBOX modifyvm "$NAME" --ioapic on || die "Failed to enable APIC"

# # Setting video memory to 48 MB
# $VBOX modifyvm "$NAME" --vram 48

# # Setting the OS to Windows 64-bit
# $VBOX modifyvm "$NAME" --ostype "WindowsNT_64"

# # Create a SCSI and a IDE interface
# #$VBOX storagectl "$NAME" --name scsi --add scsi || die "Failed to create SCSI interface}"
# echo ">>> Creating an IDE interface..."
# $VBOX storagectl "$NAME" --name ide  --add ide || die "Failed to create IDE interface"

# # Create a harddrive file
# echo ">>> Cearing a harddrive: $HDD_FILE..."
# $VBOX createhd --filename "$HDD_FILE" --size "$HDD_SIZE" || die "Failed to crate harddrive file: $HDD_FILE"

# # Attach the Harddrive
# echo ">>> Attaching the harddrive"
# $VBOX storageattach "$NAME" --storagectl ide --type hdd --medium "$HDD_FILE" --port 0 --device 0 || die "Failed to attach $HDD_FILE"

# # Attach the requested ISO
# $(dirname $0)/vbox-mount-cd.sh "$NAME" "$ISO"

# # Turn the VM on, in the background
# echo "Starting the UI in the background and waiting..."
# $(dirname $0)/vbox-ui.sh "$NAME" &

# echo "--------------------------------------------------------------------------------"
# echo "Press <ENTER> when you're ready to install drivers (this will disconnect"
# echo "the currenly loaded ISO)"
# echo ""
# echo "(Press ctrl+alt to release mouse from VM UI)"
# echo "--------------------------------------------------------------------------------"

# read

# echo "Attaching guest additions CD..."
# $(dirname $0)/vbox-install-additions.sh "$NAME"

# echo "--------------------------------------------------------------------------------"
# echo "Press <ENTER> when you're ready to take a base snapshot"
# echo "(Press ctrl+alt to release mouse)"
# echo "--------------------------------------------------------------------------------"

# read

# $(dirname $0)/vbox-snapshot.sh "$NAME" "base install"

# echo "--------------------------------------------------------------------------------"
# echo "Everything should be set up!"
# echo "Here are a couple helpful commands:"
# echo
# echo "Linux:"
# echo "  sudo mkdir /mnt/public; sudo mount -t vboxsf -o uid=ron public /mnt/public"
# echo
# echo "Windows:"
# echo '  net use z: \\vboxsrv\public'
# echo
# echo "Once you've mounted the share, you can find some helpful scripts in"
# echo " /mnt/public/scripts/<linux|windows>"
# echo
# echo "--------------------------------------------------------------------------------"
