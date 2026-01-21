: ${msgprog="${progname?}"} || return

: "${log_level=notice}"
: "${log_err=true}"
: "${log_syslog=false}"

msg() { case $# in [1-9]*) echo "${msgprog}: $*" >&2;; esac; }

log_facility=user
log_prog="${msgprog}"
log_levels="emerg alert crit err warning notice info debug"
log_level_label_emerg=EMERGENCY
log_level_label_alert=ALERT
log_level_label_crit=CRITICAL
log_level_label_err=ERROR
log_level_label_warning=WARNING
log_level_label_notice=NOTICE
log_level_label_info=INFO
log_level_label_debug=DEBUG

log() {
	case $# in
	0 | 1) return 64;;
	esac
	local level l label
	level="${1}"
	shift
	for l in emerg alert crit err warning notice info debug
	do
		case "${l}" in
		"${level}")
			eval "label=\"\${log_level_label_${l}-${l}}\""
			"${log_err}" && msg "${label}:" "$@" || :
			"${log_syslog}" && logger -p "${log_facility}.${l}" -t "${log_prog}[$$]" "$*" || :
			break
			;;
		"${log_level}")
			break
			;;
		esac
	done
}

unset -v level
for level in ${log_levels}
do
	eval "${level}() { log ${level} \"\$@\"; }"
done
for level in msg ${log_levels}
do
	eval "
		${level}_exit() {
			local code
			code=\"\${1-1}\"
			shift 2> /dev/null || :
			${level} \"\$@\" || :
			exit \"\${code}\" || exit
		}
	"
done
unset -v level

ex_usage() { err_exit 64 "$@"; }
ex_dataerr() { err_exit 65 "$@"; }
ex_noinput() { err_exit 66 "$@"; }
ex_nouser() { err_exit 67 "$@"; }
ex_nohost() { err_exit 68 "$@"; }
ex_unavailable() { err_exit 69 "$@"; }
ex_software() { err_exit 70 "$@"; }
ex_oserr() { err_exit 71 "$@"; }
ex_osfile() { err_exit 72 "$@"; }
ex_cantcreat() { err_exit 73 "$@"; }
ex_ioerr() { err_exit 74 "$@"; }
ex_tempfail() { err_exit 75 "$@"; }
ex_protocol() { err_exit 76 "$@"; }
ex_noperm() { err_exit 77 "$@"; }
ex_config() { err_exit 78 "$@"; }
