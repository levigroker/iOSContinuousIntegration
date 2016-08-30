#!/bin/sh
#
# A script to install a given Mac OS X keychain as the default or to restore the login keychain.
#
# For details on how to create the keychain, see this on Stack Overflow:
# http://stackoverflow.com/a/19550453/397210
# Essentially:
# 1) Create your build Keychain. This will contain the private key/certificate used for codesigning:
#     security create-keychain -p [keychain_password] MyKeychain.keychain
# 2) We don't want the keychain to lock on timeout or lock on sleep, so configure it thusly:
#     security set-keychain-settings "$KEYCHAIN_NAME"
# 3) Import the private key (*.p12) for your CodeSign identity:
#     security import MyPrivateKey.p12 -t agg -k MyKeychain.keychain -P [p12_Password] -A
#
# Levi Brown
# mailto:levigroker@gmail.com
# Created April 14, 2015
# History:
# 1.0 April 14 2015
#   * Initial release
#
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 install <keychain file>" >&2
	echo "$0 restore" >&2
	echo "'KEYCHAIN_PASS' environment variable must be set for 'install' command." >&2
    exit 1
}

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}

DEBUG=${DEBUG:-0}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

# Fully qualified binaries (_B suffix to prevent collisions)
SECURITY_B="/usr/bin/security"


COMMAND="$1"

if [ "$COMMAND" = "install" ]; then
	KEYCHAIN_FILE="$2"
	if [ "$KEYCHAIN_FILE" = "" ]; then
		usage
	fi
	KEYCHAIN_PASS=${KEYCHAIN_PASS:-""}
	if [ "$KEYCHAIN_PASS" = "" ]; then
		fail "Empty KEYCHAIN_PASS specified. Please export KEYCHAIN_PASS with the target keychain password."
	fi

	# Install keychain
	$SECURITY_B list-keychains -s "$KEYCHAIN_FILE"
	$SECURITY_B default-keychain -s "$KEYCHAIN_FILE"
	$SECURITY_B unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_FILE"
elif [ "$COMMAND" = "restore" ]; then
	# Default to login keychain
	$SECURITY_B list-keychains -s "login.keychain"
	$SECURITY_B default-keychain -s "login.keychain"
else
	usage
fi
