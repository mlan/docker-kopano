#!/bin/sh

#
# health check
#
# uses the runit tool to check if a service that is configured to run is down.
# This is a quite limited check.
#

docker_build_runit_root=${docker_build_runit_root-/etc/service}

if sv status $(ls $docker_build_runit_root) | grep "normally up, want up"; then
	exit 1
else
	exit 0
fi
