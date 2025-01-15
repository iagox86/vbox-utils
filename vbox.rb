#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optimist'
require 'fileutils'

UUID_REGEX = '[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}'

# Set up defaults
DEFAULT_MEMORY = 4096
DEFAULT_BRIDGE = 'wlp0s20f3'
DEFAULT_HDD_SIZE = 32_000 # Set 32gb harddrive
DEFAULT_VRAM = 32
DEFAULT_GFX_CONTROLLER = 'vboxsvga'
DEFAULT_OSTYPE = 'Linux26_64'
DEFAULT_CPUS = 2
DEFAULT_SHARE = '~/shared:shared'
DEFAULT_HDD_FILENAME = 'hdd.vmi'
VM_DIR = '~/VirtualBox VMs'

def vm_info(uuid)
  `#{VBOX} showvminfo '#{uuid}' --machinereadable`.split("\n").map do |line|
    # Handle either quoted or unquoted values
    if line =~ /^([^=]+)="(.*)"/ || line =~ /^([^=]+)=(.*)/
      [Regexp.last_match(1), Regexp.last_match(2)]
    else
      # Blank lines or lines without '=' (because "--machinereadable" isn't very machine readable)
      # .compact() will remove the nil fields
      nil
    end
  end.compact.to_h
end

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
    name: 'import',
    description: 'Import a VM from OVA or OVF',
    requires_vm: false,
  },
  {
    name: 'clone',
    description: 'Clone an existing VM',
    requires_vm: true,
  },
  {
    name: 'delete',
    description: 'Delete a VM',
    requires_vm: true,
  },
  {
    name: 'snapshot',
    description: 'Take or remove a snapshot of a VM (by default, will try to remove and then take a snapshot)',
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
  {
    name: 'mount',
    description: 'Mount an ISO',
    requires_vm: true,
  },
  {
    name: 'unmount',
    description: 'Unmount an ISO',
    requires_vm: true,
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
    opt(:hdd_size, "The size, in MB, of the VM's HDD", default: DEFAULT_HDD_SIZE)
    opt(:vram, "The size, in MB, of the VM's VRAM", default: DEFAULT_VRAM)
    opt(:ostype, "The OS type (use '#{$PROGRAM_NAME} ostypes' for a list of options) - by default, will try and detect from the ISO", type: String, required: false)
    opt(:cpus, 'The number of CPUs', default: DEFAULT_CPUS)
    opt(:share, 'Folder to share (format is "localpath:name")', default: DEFAULT_SHARE)
    opt(:hdd_filename, "Name of the harddrive file (relative to the VM's folder)", default: DEFAULT_HDD_FILENAME)

    opt(:dir, 'The directory to store VMs in', default: VM_DIR)
    opt(:dryrun, "Show the command but don't actually make any changes", default: false)
    opt(:nodelay, "Don't wait for the user to cancel", default: false)
    opt(:nostart, "Don't start the VM after creating it", default: false)
  when 'import'
    opt(:dir, 'The directory to store VMs in', default: VM_DIR)
    opt(:file, 'The OVA or OVF file', type: String, required: true)

    opt(:ostype, "The OS type (use '#{$PROGRAM_NAME} ostypes' for a list of options)", type: String, required: false)
    opt(:name, 'Give this name to the VM', type: String, required: false)
    opt(:cpus, 'The number of CPUs', type: Integer, required: false)
    opt(:memory, "The size, in MB, of the VM's memory", type: Integer, required: false)
  when 'clone'
    opt(:dir, 'The directory to store VMs in', default: VM_DIR)
    opt(:newname, 'The new VM name', type: String, required: true)
    opt(:nostart, "Don't start the VM after cloning it", default: false)
  when 'delete'
    # n/a
  when 'snapshot'
    opt(:snapshot, 'The name to give the snapshot', default: "snapshot_#{DateTime.now.iso8601}")
    opt(:only_delete, 'Delete the snapshot', default: false)
    opt(:no_delete, "Don't try to delete the snapshot first", default: false)
  when 'restore'
    opt(:snapshot, 'The name of the snapshot to restore (by default, will use the most recent)', required: false)
  when 'start'
    opt(:headless, 'Start headless?', default: false)
  when 'stop'
    # n/a
  when 'suspend'
    # n/a
  when 'suspendall'
    # n/a
  when 'mount'
    opt(:iso, 'Mount the given iso', type: String, required: true)
  when 'unmount'
    # n/a
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

    VMS = [{
      name: name,
      uuid: uuid,
    }].freeze
  elsif name
    if cmd_opts[:noregex]
      uuid = VMS_BY_NAME[name]
      if uuid.nil?
        warn "No VM found with name #{name}!"
        exit 1
      end

      VMS = [{
        name: name,
        uuid: uuid,
      }].freeze
    else
      names = VMS_BY_NAME.keys.grep(/#{name}/i)
      if names.empty?
        warn "No VM found with name matching #{name}!"
        exit 1
      end

      vms = []
      names.each do |n|
        uuid = VMS_BY_NAME[n]
        if uuid.nil?
          warn "No VM with name #{n} found, something is weird with our mapping!"
          exit 1
        end

        vms.push(
          {
            name: n,
            uuid: uuid,
          }
        )
      end
      VMS = vms.freeze
    end
  else
    warn "Error: You must specify --uuid or --name! (use '#{$PROGRAM_NAME} list' to see a list)"
    exit 1
  end

  puts "We're going to operate on the following VMs (use --uuid or --noregex to avoid selecting multiple):"
  puts
  puts 'UUID                                 Name'
  puts '----                                 ----'
  VMS.each do |vm|
    info = vm_info(vm[:uuid])
    puts "#{vm[:uuid]} #{vm[:name]} (#{info['VMState']})"

    # info = vm_info(uuid)
    # if info['VMState'] != 'running'
    #   puts "VM isn't running, it's #{info['VMState']}"
    #   return
    # end
  end
  puts
  puts 'Press <enter> to continue or CTRL-c to stop'
  gets
end

# Get a list of OSTypes, which are used in a couple different commands
OS_TYPES = `#{VBOX} list ostypes`
           .split("\n")
           .grep(/^ID/)
           .map { |line| line.gsub(/^ID[^:]*: */, '').gsub(/ .*$/, '') }
           .sort
           .uniq

def execute_commands(cmds)
  # Ensure cmd is an array
  if cmds.is_a?(String)
    cmds = [cmds]
  end

  cmds.each do |cmd|
    puts "Executing: #{cmd}"
    out = system(cmd)

    if out.nil?
      warn "Couldn't find the VBox command!"
      exit 1
    end

    # Raise an error if something goes wrong
    unless out
      raise "Something went wrong running command: #{cmd}"
    end
  end
end

def shutdown_vm(uuid, wait: true)
  info = vm_info(uuid)
  if info['VMState'] != 'running'
    puts "VM isn't running, it's #{info['VMState']}"
    return
  end

  puts
  puts 'Powering down...'
  execute_commands("#{VBOX} controlvm #{uuid} poweroff")

  return unless wait

  puts 'Waiting a few seconds for shutdown to complete (not sure how to do this more efficiently...)'
  sleep(5)
end

def suspend_vm(uuid, wait: true)
  info = vm_info(uuid)
  if info['VMState'] != 'running'
    puts "VM isn't running, it's #{info['VMState']}"
    return false
  end

  puts
  puts 'Saving VM state...'
  execute_commands("#{VBOX} controlvm #{uuid} savestate")

  return true unless wait

  puts 'Waiting a few seconds for suspend to complete (not sure how to do this more efficiently...)'
  sleep(5)

  true
end

def start_vm(uuid, type: 'gui')
  execute_commands("#{VBOX} startvm '#{uuid}' --type #{type}")
end

def handle_command(command, cmd_opts, vm = nil)
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
      uuid = VMS_BY_NAME[n]
      info = vm_info(uuid)
      puts "#{uuid} #{n} (#{info['VMState']})"

      # info = vm_info(uuid)
      # if info['VMState'] != 'running'
      #   puts "VM isn't running, it's #{info['VMState']}"
      #   return
      # end
    end
  when 'info'
    pp vm_info(vm[:uuid])
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

    # Try and detect the ostype if it's not specified
    if cmd_opts[:ostype]
      ostype = cmd_opts[:ostype]
    else
      puts
      puts 'Trying to detect OSType...'

      vminfo = `#{VBOX} unattended detect --iso='#{cmd_opts[:iso]}' --machine-readable`
               .split("\n")
               .grep(/^OSTypeId=/)

      if vminfo.nil? || vminfo.empty?
        puts
        puts "Couldn't detect OSType, using #{DEFAULT_OSTYPE}"
        ostype = DEFAULT_OSTYPE
      else
        ostype = vminfo
                 .pop
                 .gsub(/.*=/, '')
                 .gsub('"', '')

        puts
        puts "Detected ostype = #{ostype}"
      end
    end

    unless OS_TYPES.include?(ostype)
      warn "Invalid ostype: #{ostype}"
      warn "Run '#{$PROGRAM_NAME} ostypes' for a full list and use --ostype to specify one"
      exit 1
    end

    hdd_filename = File.join(File.expand_path(cmd_opts[:dir]), cmd_opts[:name], cmd_opts[:hdd_filename])

    unless cmd_opts[:dryrun]
      FileUtils.mkdir_p(File.expand_path(cmd_opts[:dir]))
    end

    # The basic set of commands
    commands = [
      "#{VBOX} createvm --name='#{cmd_opts[:name]}' --register --basefolder='#{File.expand_path(cmd_opts[:dir])}'",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --memory #{cmd_opts[:memory]}",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --ioapic on",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --vram #{cmd_opts[:vram]}",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --os-type '#{ostype}'",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --boot1 disk --boot2 dvd --boot3 none --boot4 none",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --cpus #{cmd_opts[:cpus]}",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --audio-driver none",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --graphicscontroller '#{DEFAULT_GFX_CONTROLLER}'",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --usb off --usbehci off --usbxhci off",

      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --clipboard-mode bidirectional",

      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic1 bridged --bridgeadapter1 '#{DEFAULT_BRIDGE}' --cableconnected1 on",
      "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic2 nat --cableconnected2 on",
      # "#{VBOX} modifyvm '#{cmd_opts[:name]}' --nic3 hostonly --cableconnected3 on",

      # SATA will be used for the HDD
      "#{VBOX} storagectl '#{cmd_opts[:name]}' --name sata --controller IntelAhci --add sata",
      "#{VBOX} createhd --filename '#{hdd_filename}' --size '#{cmd_opts[:hdd_size]}'",
      "#{VBOX} storageattach '#{cmd_opts[:name]}' --storagectl sata --type hdd --medium '#{hdd_filename}' --port 0 --device 0",

      # IDE will be used for CDRom
      "#{VBOX} storagectl '#{cmd_opts[:name]}' --name ide  --add ide",
      "#{VBOX} storageattach '#{cmd_opts[:name]}' --storagectl ide --type dvddrive --medium '#{cmd_opts[:iso]}' --port 0 --device 0",
    ]

    # Add the share, if we have one
    if cmd_opts[:share] && !cmd_opts[:share].empty?
      split = cmd_opts[:share].split(':')
      shared_path = File.expand_path(split[0])
      shared_name = split[1]

      if shared_name.nil?
        warn '--share must be in the format directory:name'
        exit 1
      end

      unless File.directory?(shared_path)
        warn "Folder specified in --share doesn't exist on the local filesystem: #{shared_path}"
      end

      commands.push(
        "#{VBOX} sharedfolder add '#{cmd_opts[:name]}' --name '#{shared_name}' --hostpath '#{shared_path}' --automount"
      )
    end

    puts 'Will run the following commands shortly, press ctrl-c to stop:'
    puts commands.join("\n")
    puts

    unless cmd_opts[:nodelay]
      3.step(0, -1) do |i|
        puts "#{i} seconds..."
        sleep 1
      end
    end

    unless cmd_opts[:dryrun]
      begin
        execute_commands(commands)

        unless cmd_opts[:nostart]
          start_vm(cmd_opts[:name])
        end
      rescue StandardError => e
        warn "Command failed: #{e}"
        warn ''
        warn 'Backing out...'
        execute_commands("#{VBOX} unregistervm --delete '#{cmd_opts[:name]}'")
        warn ''
        warn 'Something went wrong!'
      end
    end
  when 'import'
    # Sanity checks
    unless File.exist?(cmd_opts[:file])
      warn "Image file does not appear to exist: #{cmd_opts[:file]}"
      exit 1
    end

    # Optional args
    opts = [
      cmd_opts[:ostype].nil? ? nil : "--vsys 0 --ostype '#{cmd_opts[:ostype]}'",
      cmd_opts[:name].nil?   ? nil : "--vsys 0 --vmname '#{cmd_opts[:name]}'",
      cmd_opts[:cpus].nil?   ? nil : "--vsys 0 --cpus #{cmd_opts[:cpus]}",
      cmd_opts[:memory].nil? ? nil : "--vsys 0 --memory #{cmd_opts[:memory]}",
    ].compact.join(' ')

    execute_commands("#{VBOX} import --vsys 0 --eula accept --vsys 0 --basefolder='#{File.expand_path(cmd_opts[:dir])}' '#{cmd_opts[:file]}' #{opts}")
  when 'clone'
    unless VMS_BY_NAME[cmd_opts[:newname]].nil?
      warn "A VM with that name already exists: #{cmd_opts[:newname]}"
      exit 1
    end

    puts
    puts 'Attempting to suspend the VM...'
    was_running = suspend_vm(vm[:uuid], wait: true)

    begin
      execute_commands(
        [
          "#{VBOX} clonevm #{vm[:uuid]} --name '#{cmd_opts[:newname]}' --basefolder='#{File.expand_path(cmd_opts[:dir])}' --mode machine --register",
          "#{VBOX} discardstate '#{cmd_opts[:newname]}'",
          "#{VBOX} modifyvm '#{cmd_opts[:newname]}' --mac-address1 auto --mac-address2 auto --mac-address3 auto --mac-address4 auto",
        ]
      )
    ensure
      if was_running
        puts
        puts 'Restarting the original VM...'
        start_vm(vm[:uuid])
      end
    end

    unless cmd_opts[:nostart]
      start_vm(cmd_opts[:newname])
    end
  when 'delete'
    puts
    puts 'Attempting to shut down the VM...'

    shutdown_vm(vm[:uuid], wait: true)

    puts
    puts 'Attempting to delete the VM...'

    begin
      execute_commands("#{VBOX} unregistervm --delete #{vm[:uuid]}")
    rescue StandardError
      warn ''
      warn 'Something went wrong deleting the VM!'
      exit 1
    end
  when 'snapshot'
    unless cmd_opts[:no_delete]
      begin
        puts 'Deleting existing snapshot, if any'
        execute_commands("#{VBOX} snapshot '#{vm[:uuid]}' delete '#{cmd_opts[:snapshot]}'")
      rescue StandardError
        puts "Failed to delete existing snapshot, there probably isn't one"
        puts
      end
    end

    unless cmd_opts[:only_delete]
      puts 'Trying to take live snapshot...'

      begin
        execute_commands("#{VBOX} snapshot '#{vm[:uuid]}' take '#{cmd_opts[:snapshot]}' --live")
      rescue StandardError
        puts
        puts 'Live snapshot failed, trying non-live snapshot'
        execute_commands("#{VBOX} snapshot '#{vm[:uuid]}' take '#{cmd_opts[:snapshot]}'")
      end
    end
  when 'restore'
    shutdown_vm(vm[:uuid], wait: true)

    if cmd_opts[:snapshot]
      execute_commands("#{VBOX} snapshot '#{vm[:uuid]}' restore '#{cmd_opts[:snapshot]}'")
    else
      execute_commands("#{VBOX} snapshot '#{vm[:uuid]}' restorecurrent")
    end
  when 'start'
    puts

    if cmd_opts[:headless]
      start_vm(vm[:uuid], type: 'headless')
    else
      start_vm(vm[:uuid])
    end
  when 'stop'
    shutdown_vm(vm[:uuid], wait: false)
  when 'stopall'
    VMS_BY_NAME.each_pair do |n, u|
      puts
      puts "Shutting down #{n}..."
      shutdown_vm(u, wait: false)
    end
  when 'suspend'
    suspend_vm(vm[:uuid], wait: false)
  when 'suspendall'
    VMS_BY_NAME.each_pair do |n, u|
      puts
      puts "Suspending #{n}..."
      suspend_vm(u, wait: false)
    end
  when 'ostypes'
    puts OS_TYPES.join("\n")
  when 'mount'
    unless File.exist?(cmd_opts[:iso])
      warn "ISO file does not appear to exist: #{cmd_opts[:iso]}"
      exit 1
    end

    execute_commands(
      "#{VBOX} storageattach '#{vm[:uuid]}' --storagectl ide --type dvddrive --medium '#{cmd_opts[:iso]}' --port 0 --device 0",
    )
  when 'unmount'
    execute_commands(
      "#{VBOX} storageattach '#{vm[:uuid]}' --storagectl ide --type dvddrive --medium emptydrive --port 0 --device 0",
    )
  else
    warn 'Error!'
  end
end

if COMMAND_DETAILS[:requires_vm]
  VMS.each do |vm|
    handle_command(command, cmd_opts, vm)
  end
else
  handle_command(command, cmd_opts)
end

exit 0

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
