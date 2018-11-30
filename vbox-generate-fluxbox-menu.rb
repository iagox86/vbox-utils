#!/usr/bin/ruby

TEMPLATE = "
[begin] (Fluxbox 1.1.1)
  [encoding] {UTF-8}

  [exec] (xterm) {uxterm -ls -sl 5000 -fg white -bg black /usr/bin/fish}
  [exec] (chrome) {google-chrome-beta}
  [exec] (chrome-work) {google-chrome-beta --user-data-dir=/home/ron/.counterhack}
  [exec] (wireshark) {gksu wireshark}
  [exec] (sound) {unity-control-center sound}

  [submenu] (VMs)
<<<VMS>>>
  [end]

  [separator]

  [exec] (re-gen menu) {bash -c 'ruby /vmware/vbox-utils/vbox-generate-fluxbox-menu.rb > /home/ron/.fluxbox/custom-menu'}

  [separator]

  [submenu] (Fluxbox menu)
    [config] (Configure)

    [submenu] (Styles)
      [stylesdir] (/usr/share/fluxbox/styles)
      [stylesdir] (~/.fluxbox/styles)
    [end]
  [end]

  [restart] (Restart)
  [exit] (Exit)

  [endencoding]
[end]"

VBOXMANAGE = '/usr/bin/VBoxManage'.freeze
DIR = File.expand_path(File.dirname(__FILE__))

VMS = `#{VBOXMANAGE} list vms`
      .split(/\n/)
      .map { |i| i.split(/"/)[1] }
      .map { |name| "    [exec] (#{name}) {#{DIR}/vbox-ui.sh \"#{name}\"}" }

puts TEMPLATE.gsub("<<<VMS>>>", VMS.join("\n"))
