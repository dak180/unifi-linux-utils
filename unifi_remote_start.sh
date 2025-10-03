#!/usr/bin/env bash
# shellcheck disable=SC2029
set -o pipefail


switchName="se8"
keyPort="2"

# Must be run as root
if [ ! "$(whoami)" = "root" ]; then
	echo "Must be run as root." >&2
	exit 1
fi

if ! ssh unifi true &> /dev/null; then
	ssh "${switchName}" swctrl poe restart id "${keyPort}"
fi
