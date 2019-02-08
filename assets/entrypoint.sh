#!/bin/bash

#
# config
#

docker_build_runit_root=${docker_build_runit_root-/etc/service}
kopano_cfg_dir=/etc/kopano
zpush_cfg_dir=/usr/share/z-push
server_cfg_file=$kopano_cfg_dir/server.cfg
ldap_cfg_file=$kopano_cfg_dir/ldap.cfg
spooler_cfg_file=$kopano_cfg_dir/spooler.cfg
zpush_cfg_file=$zpush_cfg_dir/config.php
sqlstate_cfg_file=$zpush_cfg_dir/backend/sqlstatemachine/config.php

#
# define environment variables
#

server_env_vars="MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD DISABLED_FEATURES USER_PLUGIN LOG_LEVEL"
ldap_env_vars="LDAP_HOST LDAP_PORT LDAP_PROTOCOL LDAP_SEARCH_BASE LDAP_USER_TYPE_ATTRIBUTE_VALUE LDAP_GROUP_TYPE_ATTRIBUTE_VALUE LDAP_USER_SEARCH_FILTER"
spooler_env_vars="SMTP_SERVER SMTP_PORT"
zpush_env_vars="TIMEZONE USE_CUSTOM_REMOTE_IP_HEADER USE_FULLEMAIL_FOR_LOGIN STATE_MACHINE STATE_DIR LOGBACKEND LOGLEVEL LOGAUTHFAIL LOG_SYSLOG_PROGRAM LOG_SYSLOG_FACILITY SYNC_CONFLICT_DEFAULT PING_INTERVAL FILEAS_ORDER SYNC_MAX_ITEMS UNSET_UNDEFINED_PROPERTIES ALLOW_WEBSERVICE_USERS_ACCESS USE_PARTIAL_FOLDERSYNC"
sqlstate_env_vars="STATE_SQL_ENGINE STATE_SQL_SERVER STATE_SQL_PORT STATE_SQL_DATABASE STATE_SQL_USER STATE_SQL_PASSWORD STATE_SQL_OPTIONS"

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
	echo -e "$f_bold${f_green}INFO ($name)${f_norm} $@"
}


#
# kopano now installs without any cfg files, so we just write custom values
# into their target cfg file
#

_kopano_cfg_gen() {
	# do not touch existing cfg files
	local cfg_file=$1
	shift
	local env_vars=$@
	if [ ! -e $cfg_file ]; then
		for env_var in $env_vars; do
			if [ -n "${!env_var}" ]; then
				inform "Setting ${env_var,,} = ${!env_var} in $cfg_file"
				echo ${env_var,,} = ${!env_var} >> $cfg_file
			fi
		done
	fi
}

_php_cfg_gen() {
	local cfg_file=$1
	shift
	local env_vars=$@
	if [ -e $cfg_file ]; then
		for env_var in $env_vars; do
			if [ -n "${!env_var}" ]; then
				inform "Setting ${env_var} = ${!env_var} in $cfg_file"
				sed -ri "s/(\s*define).+${env_var}.+/\1\(\x27${env_var}\x27, \x27${!env_var}\x27\);/g" $cfg_file
			fi
		done
	fi
}

kopano_cfg() {
	_kopano_cfg_gen $server_cfg_file $server_env_vars
	_kopano_cfg_gen $ldap_cfg_file $ldap_env_vars
	_kopano_cfg_gen $spooler_cfg_file $spooler_env_vars
}

php_cfg() {
	_php_cfg_gen $zpush_cfg_file $zpush_env_vars
	_php_cfg_gen $sqlstate_cfg_file $sqlstate_env_vars
}

loglevel() {
	if [ -n "$SYSLOG_LEVEL" -a $SYSLOG_LEVEL -ne 4 ]; then
		setup-runit.sh "syslogd -n -O /dev/stdout -l $SYSLOG_LEVEL"
	fi
}

#
# run
#

define_formats
kopano_cfg
php_cfg
loglevel

exec 2>&1
exec runsvdir -P $docker_build_runit_root

