. "${progdir_?}msg.sh"
. "${progdir_?}run.sh"

create_freebsd_zroot() {
	local msgprog zroot zpool altroot mountpoint subfs fs props prop name newline curprops source value create_props status
	msgprog="${msgprog:+"${msgprog}: "}create_freebsd_zroot"
	status=0
	newline='
'
	local OPTIND opt
	OPTIND=1
	while getopts : opt
	do
		case "${opt}" in
			'?') err "unrecognized option -${OPTARG}"; return 64;;
			':') err "missing argument for -${OPTARG}"; return 64;;
		esac
	done
	shift $((OPTIND - 1))
	for zroot
	do
		zpool="${zroot%%/*}"
		if altroot=$(run zpool get -H -p -o value altroot "${zpool}")
		then
			case "${altroot}" in
				/*)
					debug "zpool ${zpool} has altroot ${altroot}" >&2
					altroot="${altroot%/}"
					;;
				""|-|none)
					debug "zpool ${zpool} has no altroot" >&2
					altroot=""
					;;
				*)
					debug "unrecognized altroot ${altroot} for zpool ${zpool}" >&2
					status=1
					break
					;;
			esac
		else
			status=$?
			break
		fi
		if mountpoint=$(run zfs get -H -p -o value mountpoint "${zroot}")
		then
			case "${mountpoint}" in
				"${altroot}"|"${altroot}"/*)
					mountpoint="${mountpoint%/}"
					mountpoint="${mountpoint#"${altroot}"}"
					;;
				*)
					err "mountpoint ${mountpoint} for zroot ${zroot} is outside of altroot ${altroot} of zpool ${zpool}" >&2
					status=1
					break
					;;
			esac
		else
			status=$?
			break
		fi
		for subfs in "" /ROOT /ROOT/default /tmp /usr /usr/home /usr/ports /usr/src /var /var/audit /var/crash /var/log /var/mail /var/tmp
		do
			fs="${zroot}${subfs}"
			props=""
			case "${subfs}" in
				"")		props="canmount=off compress=zstd atime=off";;
				/ROOT)		props="mountpoint=none";;
				/ROOT/default)	props="mountpoint=${mountpoint:-"/"}";;
				/tmp)		props="exec=on setuid=off";;
				/usr)		props="canmount=off";;
				/usr/ports)	props="setuid=off";;
				/var)		props="canmount=off";;
				/var/audit)	props="exec=off setuid=off";;
				/var/crash)	props="exec=off setuid=off";;
				/var/log)	props="exec=off setuid=off";;
				/var/mail)	props="atime=on";;
				/var/tmp)	props="setuid=off";;
			esac
			case "${fs}" in
				"${zroot}")
					if info_and_run zfs set ${props} "${fs}"
					then
						:
					else
						status=$?
						break 2
					fi
					;;
				*)
					create_props=""
					for prop in ${props}
					do
						create_props="${create_props} -o ${prop}"
					done
					if info_and_run zfs create ${create_props} "${fs}"
					then
						:
					else
						status=$?
						break 2
					fi
					;;
			esac
		done
	done
	return ${status}
}
