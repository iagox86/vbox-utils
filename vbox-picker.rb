#!/usr/bin/ruby

VBOXMANAGE = '/usr/bin/VBoxManage'.freeze
DIR = File.expand_path(File.dirname(__FILE__))

VMS = `#{VBOXMANAGE} list vms`
      .split(/\n/)
      .map { |i| i.split(/"/)[1] }

VMS.each_with_index do |name, i|
  puts "#{i + 1}. #{name}"
end
puts
puts('Please select a VM to boot...')
puts
print('> ')

i = $stdin.gets.to_i
i -= 1

if i < 0 || i >= VMS.length
  exit
end

if !fork
  system("#{DIR}/vbox-ui.sh \"#{VMS[i]}\"")
end
