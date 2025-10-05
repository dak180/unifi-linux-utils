#!/usr/bin/env bash
# shellcheck disable=SC2029
set -o pipefail

# Config
cloudKey="unifi"
switchName="se8"
keyPort="2"


while getopts ":t:" OPTION; do
	case "${OPTION}" in
		t)
			setTime="${OPTARG}"
		;;
		*)
			true
		;;
	esac
done

# Must be run as root
if [ ! "$(whoami)" = "root" ]; then
	echo "Must be run as root." >&2
	exit 1
fi

if [ ! -z "${setTime}" ] && [[ "${setTime}" =~ ^[0-9]+$ ]]; then
	sleep "${setTime}"
fi

if ! ssh "${cloudKey}" true &> /dev/null; then
	ssh "${switchName}" swctrl poe restart id "${keyPort}"
fi
