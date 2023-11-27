# frozen_string_literal: true

require 'optimist'

# Things to look into:
# * Unattended install
# * Clipboard
# * OVF

UUID_REGEX = '[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}'

# Set up defaults
DEFAULT_MEMORY = 1024
HDD_SIZE = 32_000 # Set 32gb harddrive
VM_DIR = '/home/ron/VirtualBox VMs' # TODO: Can we interpret ~?
HDD_FILE = 'hdd.vmi'
BRIDGE = 'wlp0s20f3'

SUBCOMMANDS = [
  {
    name: 'list',
    description: 'List all VMs',
    requires_vm: false,
  },
  {
    name: 'info',
    description: 'Get information on a VM',
    requires_vm: true,
  },
  {
    name: 'create',
    description: 'Create a new VM',
    requires_vm: false,
  },
  {
    name: 'delete',
    description: 'Delete a VM',
    requires_vm: true,
  },
  {
    name: 'snapshot',
    description: 'Take a snapshot of a VM',
    requires_vm: true,
  },
  {
    name: 'restore',
    description: 'Restore a snapshot of a VM',
    requires_vm: true,
  },
  {
    name: 'start',
    description: 'Start a VM',
    requires_vm: true,
  },
  {
    name: 'stop',
    description: 'Stop a VM',
    requires_vm: true,
  },
  {
    name: 'stopall',
    description: 'Stop all VMs',
    requires_vm: false,
  },
  {
    name: 'suspend',
    description: 'Suspend a VM',
    requires_vm: true,
  },
  {
    name: 'suspendall',
    description: 'Suspend all VMs',
    requires_vm: false,
  },
].freeze

BANNER_HEADER = <<~BANNER
  VirtualBox Management Utility

  Usage:
    #{$PROGRAM_NAME} [global options] <SUBCOMMAND> [subcommand options]

  For help on a subcommand, run:
    #{$PROGRAM_NAME} [global options] <SUBCOMMAND> --help
BANNER

global_opts = Optimist.options do
  banner <<~BANNER
    #{BANNER_HEADER}
    Available subcommands:
    #{
      SUBCOMMANDS.map do |s|
        "  #{s[:name]}: #{s[:description]}"
      end.join("\n")
    }

    Global options:
  BANNER

  # opt :dry_run, "Don't actually do anything", :short => "-n"
  opt(:vbox, 'Path to the VBox binary', default: '/usr/bin/VBoxManage')
  stop_on(SUBCOMMANDS.map { |s| s[:name].downcase })
end

command = ARGV.shift # get the subcommand
if command.nil?
  warn 'No subcommand found'
  warn '---'
  Optimist.educate()
  exit 1
end

command_details = SUBCOMMANDS.select { |s| s[:name].downcase == command }
if command_details.nil? || command_details.empty?
  warn "Unknown subcommand: #{command}"
  warn '---'
  Optimist.educate()
  exit 1
end
COMMAND_DETAILS = command_details.pop

cmd_opts = Optimist.options do
  banner <<~BANNER
    #{BANNER_HEADER}
    Command: '#{command}' - #{COMMAND_DETAILS[:description]}
    #{
      if COMMAND_DETAILS[:requires_vm]
        "\nNote: this command requires --uuid=UUID -or- --name=NAME\n"
      end
    }
    Options for "#{command}":
  BANNER

  if COMMAND_DETAILS[:requires_vm]
    opt(:name, 'Target the VM with the given name (can be a regex IF the regex matches exactly one VM)', type: String)
    opt(:uuid, 'Target the VM with the given uuid', type: String)
    opt(:noregex, 'Turns off regex matching on --name argument')
  end

  case command
  when 'list'
    opt(:regex, 'Only show VMs that match the given regex (case insensitive)', default: '.*')
  when 'info'
    # TODO
  when 'create'
    # TODO
  when 'delete'
    # TODO
  when 'snapshot'
    # TODO
  when 'restore'
    # TODO
  when 'start'
    # TODO
  when 'stop'
    # TODO
  when 'suspend'
    # TODO
  when 'suspendall'
    # TODO
  else
    Optimist.die "unknown subcommand #{command.inspect}"
  end
end

# Set some globals
VBOX = global_opts[:vbox] || '/usr/bin/VBoxManage'
unless File.exist?(VBOX)
  warn "#{VBOX} does not exist"
  exit 1
end
unless File.executable?(VBOX)
  warn "#{VBOX} is not executable"
  exit 1
end

# Load a list of VMs
VMS_BY_NAME = `#{VBOX} list vms`.split("\n").to_h do |line|
  unless line =~ /^"(.*)" \{(#{UUID_REGEX})\}/
    warn "Couldn't parse line from VBoxManage output: #{line}"
    exit 1
  end
  [Regexp.last_match(1), Regexp.last_match(2)]
end
VMS_BY_UUID = VMS_BY_NAME.invert()

# Sanity check
if VMS_BY_UUID.length != VMS_BY_NAME.length
  warn "Warning: There are multiple VMs with the same name (or same UUID), that's bad!"
  exit 1
end

# Look up the VM if needed
if COMMAND_DETAILS[:requires_vm]
  uuid = cmd_opts[:uuid]
  name = cmd_opts[:name]

  # Whether they specified uuid or name, fill in the other
  if uuid && name
    warn 'Error: You must specify --uuid -or- --name, but not both!'
    exit 1
  elsif uuid
    name = VMS_BY_UUID[uuid]
    if name.nil?
      warn "No VM found with uuid #{uuid}!"
      exit 1
    end
  elsif name
    if cmd_opts[:noregex]
      uuid = VMS_BY_NAME[name]
      if uuid.nil?
        warn "No VM found with name #{name}!"
        exit 1
      end
    else
      names = VMS_BY_NAME.keys.grep(/#{name}/i)
      if names.empty?
        warn "No VM found with name matching #{name}!"
        exit 1
      elsif names.length > 1
        warn "Multiple VMs found with names matching #{name}: #{names.map { |n| "'#{n}'" }.join(', ')}"
        warn '(Hint: use --noregex to turn off regex matching)'
        exit 1
      else
        uuid = VMS_BY_NAME[names.pop]
      end
    end
  else
    warn "Error: You must specify --uuid or --name! (use '#{$PROGRAM_NAME} list' to see a list)"
    exit 1
  end

  VM = {
    uuid: uuid,
    name: name,
  }.freeze
end

case command
when 'list'
  puts 'UUID                                 Name'
  puts '----                                 ----'

  if cmd_opts[:regex]
    vm_names = VMS_BY_NAME.keys.grep(/#{cmd_opts[:regex]}/i)
  else
    vm_names = VMS_BY_NAME.keys
  end

  vm_names.each do |n|
    puts "#{VMS_BY_NAME[n]} #{n}"
  end
when 'info'
  info = `#{VBOX} showvminfo #{VM[:uuid]} --machinereadable`.split("\n").map do |line|
    # Handle either quoted or unquoted values
    if line =~ /^([^=]+)="(.*)"/ || line =~ /^([^=]+)=(.*)/
      [Regexp.last_match(1), Regexp.last_match(2)]
    else
      # Blank lines or lines without '=' (because "--machinereadable" isn't very machine readable)
      # .compact() will remove the nil fields
      nil
    end
  end.compact.to_h
  pp info
when 'create'
  # TODO
  if cmd_opts[:name].nil?
    warn subcommands[command].help()
    warn '---'
    warn 'Missing --name option'
    exit 1
  end

  puts 'hi'
  pp cmd_opts
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
else
  warn 'Error!'
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
