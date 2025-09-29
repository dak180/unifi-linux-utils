#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2029
set -o pipefail


# Functions
function scriptTest() {
	# Test for up to date scripts / config
	local localScriptMD5="$(md5sum -q "${localScripPth}/${scriptNme}" 2> /dev/null)"
	local remotScriptMD5="$(ssh "${ssh_Address}" "md5sum -q '${remoteScripPth}/${scriptNme}' 2> /dev/null")"

	local localConfigMD5="$(md5sum -q "${configFile}")"
	local remotConfigMD5="$(ssh "${ssh_Address}" "md5sum -q '${remoteScripPth}/${configName}' 2> /dev/null")"

	# Ensure destination dir exists
	if [ -z "${remotScriptMD5}" ]; then
		ssh "${ssh_Address}" "mkdir -p '${remoteScripPth}' 2> /dev/null"
	fi

	# Copy the script if needed
	if [ -z "${localScriptMD5}" ]; then
		echo "Please specify scriptNme in ${configFile}." >&2
		exit 1
	elif [ ! "${localScriptMD5}" = "${remotScriptMD5}" ]; then
		scp -Bqp "${localScripPth}/${scriptNme}" "scp://${ssh_Address}/${remoteScripPth}/${scriptNme}" || { echo "Unable to copy the script" >&2; exit 1; }
	fi

	# Copy the config file if needed
	if [ ! "${localConfigMD5}" = "${remotConfigMD5}" ]; then
		scp -Bqp "${configFile}" "scp://${ssh_Address}/${remoteScripPth}/${configName}" || { echo "Unable to copy the config" >&2; exit 1; }
	fi

}

function certTransfer() {
	# start fresh
	ssh "${ssh_Address}" "rm -f '${PRIV_KEY}' '${SIGNED_CRT}' '${CHAIN_FILE}' 2> /dev/null"

	scp -Bqp "${localPRIV_KEY}" "scp://${ssh_Address}/${PRIV_KEY}"  || { echo "Unable to copy ${localPRIV_KEY}" >&2; exit 1; }

	scp -Bqp "${localSIGNED_CRT}" "scp://${ssh_Address}/${SIGNED_CRT}"  || { echo "Unable to copy ${localSIGNED_CRT}" >&2; exit 1; }

	scp -Bqp "${localCHAIN_FILE}" "scp://${ssh_Address}/${CHAIN_FILE}"  || { echo "Unable to copy ${localCHAIN_FILE}" >&2; exit 1; }
}


#
# Main Script Starts Here
#

while getopts ":c:" OPTION; do
	case "${OPTION}" in
		c)
			configFile="${OPTARG}"
		;;
		?)
			# If an unknown flag is used (or -?):
			echo "${0} {-c configFile}" >&2
			exit 1
		;;
	esac
done

if [ -z "${configFile}" ]; then
	echo "Please specify a config file location." >&2
	exit 1
fi

# Source external config file
# shellcheck source=./unifi_ssl_import.cfg
. "${configFile}"

# Check if needed software is installed.
PATH="${PATH}:/usr/local/sbin:/usr/local/bin"
commands=(
ssh
md5sum
scp
cat
basename
)
for command in "${commands[@]}"; do
	if ! type "${command}" &> /dev/null; then
		echo "${command} is missing, please install" >&2
		exit 100
	fi
done


# Do not run if the config file has not been edited.
if [ ! "${defaultFile}" = "0" ]; then
	echo "Please edit the config file for your setup" >&2
	exit 1
fi


# Must be run as root
if [ ! "$(whoami)" = "root" ]; then
	echo "Must be run as root." >&2
	exit 1
fi

# Computed Vars
localScripPth="$(dirname "${configFile}")"
configName="$(basename "${configFile}")"
remoteScripPth="$(dirname "${PRIV_KEY}")"

# If certs are up to date stop here
inPlaceCertMD5="$(ssh "${ssh_Address}" "cat ${UNIFI_DIR}/certs.md5 2> /dev/null"  | cut -wf 1 | md5)"
localCertMD5="$(md5sum "${localPRIV_KEY}" "${localSIGNED_CRT}" "${localCHAIN_FILE}" | cut -wf 1 | md5)"
if [ "${inPlaceCertMD5}" = "${localCertMD5}" ]; then
	# Nothing needed, exiting
	exit 0
fi

scriptTest

certTransfer

ssh "${ssh_Address}" "${remoteScripPth}/${scriptNme}" -c "${remoteScripPth}/${configName}"

