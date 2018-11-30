#!/usr/bin/ruby

TEMPLATE = "
[begin] (Fluxbox 1.1.1)
  [encoding] {UTF-8}

  [exec] (Xterm) {uxterm -ls -sl 5000 -fg white -bg black /usr/bin/fish}
  [exec] (Chrome) {google-chrome-beta}
  [exec] (Chrome - work) {google-chrome-beta --user-data-dir=/home/ron/.counterhack}
  [exec] (Wireshark) {gksu wireshark}
  [exec] (Sound Settings) {unity-control-center sound}

  [separator]

  [submenu] (VMs)
<<<VMS>>>
  [end]

  [submenu] (Monitors)
    [exec] (Standalone Laptop) (xrand --output eDP1 --mode 2560x1440 --output HDMI2 --off --output DP1 --off)
    [exec] (Standalone Laptop - Lo Res) (xrand --output eDP1 --mode 1920x1080 --output HDMI2 --off --output DP1 --off)

    [separator]

    [exec] (Presentation - Mirror HDMI 1440) (xrand --output eDP1 --mode 2560x1440 --output HDMI2 --mode 2560x1440 --same-as eDP1 --output DP1 --off)
    [exec] (Presentation - Mirror HDMI 1080) (xrand --output eDP1 --mode 1920x1080 --output HDMI2 --mode 1920x1080 --same-as eDP1 --output DP1 --off)

    [separator]

    [exec] (Home Office) (xrandr --output eDP1 --mode 2560x1440 --output HDMI2 --mode 2560x1440 --same-as eDP1 --output DP1 --mode 2560x1440 --left-of eDP1)
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
