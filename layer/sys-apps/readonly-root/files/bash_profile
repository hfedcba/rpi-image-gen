let upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
let secs=$((${upSeconds}%60))
let mins=$((${upSeconds}/60%60))
let hours=$((${upSeconds}/3600%24))
let days=$((${upSeconds}/86400))
UPTIME=`printf "%d days, %02dh %02dm %02ds" "$days" "$hours" "$mins" "$secs"`

if test -e /usr/bin/homegear; then
    echo "$(tput setaf 4)$(tput bold)
                   dd
                  dddd
                dddddddd
              dddddddddddd
               dddddddddd                   $(tput setaf 7)Welcome to your Homegear system!$(tput setaf 4)
               dddddddddd                   $(tput setaf 7)`uname -srmo`$(tput setaf 4)
               d$(tput setaf 6).:dddd:.$(tput setaf 4)d$(tput setaf 6)
    .:ool:,,:oddddddddddddo:,,:loo:.        $(tput sgr0)Uptime.............: ${UPTIME}$(tput setaf 6)$(tput bold)
    oddddddddddddddddddddddddddddddo        $(tput sgr0)Homegear Version...: $(homegear -v | head -1 | cut -d " " -f 3)$(tput setaf 6)$(tput bold)
    .odddddddd| $(tput setaf 7)Homegear$(tput setaf 6) |ddddddddo.
     lddddddddddddddddddddddddddddl
    lddddddddddddddddddddddddddddddl
  .:dddddddddddddc.''.cddddddddddddd:.
:odddddddddddddo.      .odddddddddddddo:
ddddddddddddddd,        ,ddddddddddddddd


$(tput sgr0)"
fi

echo ""
echo "* To change data on the root partition (e. g. to update the system),"
echo "  enter:"
echo ""
echo "  rw"
echo ""
echo "  When you are done, execute"
echo ""
echo "  ro"
echo ""
echo "  to make the root partition readonly again."
echo "* You can store data on \"/data\". It is recommended to only backup"
echo "  data to this directory. During operation data should be written to a"
echo "  temporary file system. By default these are \"/var/log\" and "
echo "  \"/var/tmp\". You can add additional mounts in \"/etc/fstab\"."
echo "* Remember to backup all data to \"/data\" before rebooting."
echo ""

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
