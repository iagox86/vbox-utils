# frozen_string_literal: true

require 'optimist'
require 'fileutils'

# Things to look into:
# * Unattended install
# * Clipboard
# * OVF

UUID_REGEX = '[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}'

# Set up defaults
DEFAULT_MEMORY = 1024
DEFAULT_BRIDGE = 'wlp0s20f3'
DEFAULT_HDD = 32_000 # Set 32gb harddrive
DEFAULT_VRAM = 16
DEFAULT_OSTYPE = 'Linux26_64'
DEFAULT_CPUS = 2
DEFAULT_SHARE = '~/shared:shared'
VM_DIR = '~/VirtualBox VMs'

# HDD_FILE = 'hdd.vmi'

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
  {
    name: 'ostypes',
    description: 'Get a list of supported os types',
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
    # n/a
  when 'create'
    opt(:name, 'Give this name to the VM', type: String, required: true)
    opt(:iso, 'Mount the given iso', type: String, required: true)
    opt(:memory, "The size, in MB, of the VM's memory", default: DEFAULT_MEMORY)
    opt(:bridge, 'The network to bridge networking to', default: DEFAULT_BRIDGE)
    opt(:hdd, "The size, in MB, of the VM's HDD", default: DEFAULT_HDD)
    opt(:vram, "The size, in MB, of the VM's VRAM", default: DEFAULT_VRAM)
    opt(:ostype, "The OS type (use '#{$PROGRAM_NAME} ostypes' for a list of options)", default: DEFAULT_OSTYPE)
    opt(:cpus, 'The number of CPUs', default: DEFAULT_CPUS)
    opt(:share, 'Folder to share (format is "localpath:name")', default: DEFAULT_SHARE)

    opt(:dir, 'The directory to store VMs in', default: VM_DIR)
    opt(:dryrun, "Show the command but don't actually make any changes", default: false)
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

# Get a list of OSTypes, which are used in a couple different commands
OS_TYPES = `#{VBOX} list ostypes`
           .split("\n")
           .grep(/^ID:/)
           .map { |line| line.gsub(/^ID: */, '') }
           .sort
           .uniq

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
  # Sanity checks
  unless VMS_BY_NAME[cmd_opts[:name]].nil?
    warn "A VM with that name already exists: #{cmd_opts[:name]}"
    exit 1
  end

  unless File.exist?(cmd_opts[:iso])
    warn "ISO file does not appear to exist: #{cmd_opts[:iso]}"
    exit 1
  end

  unless OS_TYPES.include?(cmd_opts[:ostype])
    warn "Invalid ostype: #{cmd_opts[:iso]}"
    warn "Run '#{$PROGRAM_NAME} ostypes' for a full list"
    exit 1
  end

  DIR = File.expand_path(cmd_opts[:dir])

  unless cmd_opts[:dryrun]
    FileUtils.mkdir_p(DIR)
  end

  commands = [
    "#{VBOX} createvm --name='#{cmd_opts[:name]}' --register --basefolder='#{DIR}'",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --memory #{cmd_opts[:memory]}",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --ioapic on",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --vram #{cmd_opts[:vram]}",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --os-type '#{cmd_opts[:ostype]}'",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --boot1 dvd --boot2 disk --boot3 none --boot4 none",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --cpus #{cmd_opts[:cpus]}",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --audio none",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --usb off --usbehci off --usbxhci off",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic1 bridged --bridgeadapter1 '#{DEFAULT_BRIDGE}' --cableconnected1 on",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic2 nat --cableconnected2 on",
    "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic3 hostonly --cableconnected3 on",
  ]

  # Add the share, if we have one
  if cmd_opts[:share] && !cmd_opts[:share].empty?
    split = cmd_opts[:share].split(':')
    SHARED_PATH = File.expand_path(split[0])
    SHARED_NAME = split[1]

    if SHARED_NAME.nil?
      warn '--share must be in the format directory:name'
      exit 1
    end

    unless File.directory?(SHARED_PATH)
      warn "Folder specified in --share doesn't exist on the local filesystem: #{SHARED_PATH}"
    end

    commands.push(
      "#{VBOX} sharedfolder add '#{cmd_opts[:name]}' --name '#{SHARED_NAME}' --hostpath '#{SHARED_PATH}' --automount"
    )
  end

  puts 'Will run the following commands in 3 seconds:'
  puts commands.join("\n")
  puts
  sleep(3) # TODO: More obvious delay?

  unless cmd_opts[:dryrun]
    commands.each do |c|
      puts "Running: #{c}"
      out = system(c)
      if out.nil?
        warn "Couldn't find the VBox command!"
        exit 1
      elsif out == false
        # TODO: back out?
        warn 'Something went wrong running the command!'
        exit 1
      end
      sleep 1
    end
  end
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
when 'ostypes'
  puts OS_TYPES.join("\n")
else
  warn 'Error!'
end

exit 0

# # Set up the networking
# $(dirname $0)/vbox-set-up-networking.sh "$NAME"

# # Set up shared folders
# $(dirname $0)/vbox-add-shared-folders.sh "$NAME" "public"

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
