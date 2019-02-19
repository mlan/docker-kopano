#!/bin/sh

# use /etc/service if $docker_build_runit_root not already defined
docker_build_runit_root=${docker_build_runit_root-/etc/service}
#docker_build_svlog_root=${docker_build_svlog_root-/var/log/sv}

#
# Define helpers
#

define_formats() {
	name=$(basename $0)
	f_norm="\e[0m"
	f_bold="\e[1m"
	f_red="\e[91m"
	f_green="\e[92m"
	f_yellow="\e[93m"
}

inform() {
	echo "$f_bold${f_green}INFO ($name)${f_norm} $@"
}

#
# initialize runit services
#

init_service() {
	# create runit 'run' script for service
	# if service is part of kopano suite also make the 'run' script
	# delete lingering pid files, which appears to happen to kopano-search
	local cmd="$1"
	shift
	local runit_dir=$docker_build_runit_root/${cmd##*/}
	local svlog_dir=$docker_build_svlog_root/${cmd##*/}
	local clear_pids_str=
	if echo $cmd | grep kopano - >/dev/null; then
		clear_pids_str="rm -f /var/run/kopano/${cmd#*kopano-}.pid*"
	fi
	cmd=$(which $cmd)
	if [ ! -z "$cmd" ]; then
		mkdir -p $runit_dir
		cat <<-!cat > $runit_dir/run
			#!/bin/sh -e
			#exec 2>&1
			$(echo $clear_pids_str)
			exec $cmd $@
		!cat
		chmod +x $runit_dir/run
		inform "runit configured to run: $cmd $@"
		if [ -n "$docker_build_svlog_root" ]; then
			mkdir -p $runit_dir/log $svlog_dir
			cat <<-!cat > $runit_dir/log/run
				#!/bin/sh
				exec svlogd -tt $svlog_dir
			!cat
			chmod +x $runit_dir/log/run
		fi
	fi
	}

init_services() {
	for cmd in "$@" ; do
		init_service $cmd
	done
}

down_service() {
	local cmd="$1"
	touch $docker_build_runit_root/$cmd/down
	inform "runit configured to down: $cmd"
}

down_services() {
	for cmd in "$@" ; do
		down_service $cmd
	done
	}

setup_services() {
	case "$1" in
	-d|--down)
		shift
		init_services "$@"
		down_services "$@"
		;;
	*)
		init_services "$@"
		;;
	esac
}

#
# run
#

define_formats
setup_services "$@"
