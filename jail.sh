#!/bin/sh

. /etc/rc.subr

set -e

load_rc_config jail

unset -v name action j jv
name="${1}"
action="${2}"
j=$(echo -n "${name}" | tr /. _)
jv=$(echo -n "${name}" | tr -c '[[:alnum:]]' _)

load_jail_param() { # var param default
	local _v _p _d
	_v="${1-}"
	_p="${2-}"
	_d="${3-}"
	shift 3 || return $?
	eval "${_v}=\"\${jail_${jv}_${_p}-\"\${jail_${_p}-\"\${_d}\"}\"}\""
}

load_jail_param bridges bridge ""

unset -v ifconfig
: ${IFCONFIG_CMD:="/sbin/ifconfig"}
: ${JLS_CMD:="/usr/sbin/jls"}
: ${JEXEC_CMD:="/usr/sbin/jexec"}

exec >> "/var/log/jail_${j}_shell.out" 2>&1 || exit $?
echo "$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ") ${name} ${action}"

prepare() {
}

prestart() {
}

set_or_save_epair_b_ether() {
	local ether etherconf
	etherconf="/etc/jail.ether.d/${j}/${epair_b_in_jail}.ether"
	if read -r ether < "${etherconf}"
	then
		echo "Setting ${epair_b_in_jail} ether address: ${ether}"
		${IFCONFIG_CMD} "${epair_b}" ether "${ether}" || return $?
	elif ether=$(ifconfig "${epair_b}" | awk '/^\tether/ { print $2; }' | grep .)
	then
		echo "Saving ${epair_b_in_jail} ether address: ${ether}"
		mkdir -p "${etherconf%/*}"
		echo "${ether}" > "${etherconf}"
	else
		echo "Cannot set or save ether address; using ephemeral address!"
	fi
}

created() {
	local jid next_if_num bridge bridge epair_a epair_b epair_b_in_jail vnet
	jid="$(${JLS_CMD} -j "${name}" jid)"
	next_if_num=0
	set -- ${bridges}
	echo "Setting up $# vnet epairs to add to bridge(s)${*+": $*"}"
	for bridge in ${bridges}
	do
		if_num="${next_if_num}"
		next_if_num=$((${next_if_num} + 1))
		vnet="vnet${if_num}.${jid}"
		echo "Adding ${vnet} to ${bridge}"
		if
			epair_a="$(${IFCONFIG_CMD} epair create)" &&
			epair_b="${epair_a%a}b" &&
			epair_b_in_jail="epair${if_num}b" &&
			${IFCONFIG_CMD} "${epair_a}" name "${vnet}" > /dev/null &&
			epair_a="${vnet}" && # use the new name beyond this point
			${IFCONFIG_CMD} "${bridge}" addm "${epair_a}" &&
			${IFCONFIG_CMD} "${epair_a}" up &&
			set_or_save_epair_b_ether &&
			${IFCONFIG_CMD} "${epair_b}" vnet "${jid}" &&
			${JEXEC_CMD} -l "${jid}" ${IFCONFIG_CMD} "${epair_b}" name "${epair_b_in_jail}" > /dev/null &&
			epair_b="${epair_b_in_jail}" &&
			${IFCONFIG_CMD} "${epair_a}" &&
			${JEXEC_CMD} -l "${jid}" ${IFCONFIG_CMD} "${epair_b}"
		then
			:
		else
			${IFCONFIG_CMD} "${epair_a}" destroy || :
		fi
	done
}

poststart() {
}

prestop() {
}

poststop() {
	local jid next_if_num if_num vnet
	read jid < "/var/run/jail_${j}.id" || return $?
	set -- ${bridges}
	next_if_num=$(($# - 1))
	while :
	do
		case $((${next_if_num} >= 0)) in 0) break;; esac
		if_num="${next_if_num}"
		next_if_num=$((${next_if_num} - 1))
		vnet="vnet${if_num}.${jid}"
		echo "Removing ${vnet}"
		${IFCONFIG_CMD} "${vnet}" destroy || :
	done
}

release() {
}

case "${action}" in
prepare|prestart|created|poststart|prestop|poststop|release)
	"${action}"
	;;
*)
	echo "${0##*/}: unknown action ${action}" >&2
	exit 64
	;;
esac
