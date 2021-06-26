#!/bin/bash

#
# defaults
#

_webroot="https://download.kopano.io/community"
_debroot="http://repo.z-hub.io/z-push:"
_component="core"
_stage="final"
_dist="ubuntu"
_rel="20.04"
_arch="amd64"

#
# define helpers
#

escape_dot() { sed 's/\./\\\./g' ;}
captialize() { echo "$@" | sed 's/[^ _-]*/\u&/g' ;}
decimalise() { echo "$@" | sed '/\./!s/$/\.0/g' ;}
get_version() { sed -nr 's/.*'$1'-([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' ;}

webaddr_kopano() {
	# Find weblinks to latest Kopano packages
	local component="${1-$_component}"
	local webroot="${2-$_webroot}"
	local dist=$(captialize "${3-$_dist}")
	local rel=$(decimalise "${4-$_rel}" | escape_dot)
	local arch="${5-$_arch}"
	file=$(curl -s -S "$webroot/$component:/" | \
		sed -nr 's/.*('$component'-.*-'$dist'_'$rel'-'$arch'\.tar\.gz).*/\1/p')
	echo "$webroot/$component:/$file"
}

debaddr_zpush() {
	local stage="${1-$_stage}"
	local debroot="${2-$_debroot}"
	local dist=$(captialize "${3-$_dist}")
	local rel=$(decimalise "${4-$_rel}")
	echo "$debroot/$stage/${dist}_${rel}"
}

#
# run
#

case $1 in
	-V|--version)
		shift
		webaddr_kopano $@ | get_version
		;;
	-VV)
		shift
		_core_ver=$(webaddr_kopano core | get_version core)
		_arch="all"
		_webapp_ver=$(webaddr_kopano webapp | get_version webapp)
		echo "$_core_ver-$_webapp_ver"
		;;
	-d|--deb)
		shift
		debaddr_zpush $@
		;;
	*)
		webaddr_kopano $@
		;;
esac
