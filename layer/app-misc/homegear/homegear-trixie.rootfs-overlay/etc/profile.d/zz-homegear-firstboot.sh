# Kick off the interactive first-boot Homegear installation (see
# /usr/sbin/homegear-firstboot) on the first interactive login, the way
# pi-gen ran firstStart.sh from the pi user's .bashrc.
#
# Sourced by /etc/profile: must be POSIX sh, and must never call `exit` -
# that would terminate the login shell instead of this snippet. Named
# zz-* so it runs after the rest of /etc/profile.d, and it deliberately
# runs before ~/.bash_profile's Homegear banner, which only makes sense
# once Homegear is actually installed.

if [ ! -e /etc/rpi-image-gen/homegear-install.done ] &&
	[ -x /usr/sbin/homegear-firstboot ] &&
	[ -t 0 ] && [ -t 1 ]; then
	case "$-" in
	*i*)
		if [ "$(id -u)" = 0 ]; then
			/usr/sbin/homegear-firstboot
		elif command -v sudo > /dev/null 2>&1; then
			echo "Homegear is not installed yet - starting the installer (this may ask for your password)."
			sudo /usr/sbin/homegear-firstboot
		fi
		;;
	esac
fi
