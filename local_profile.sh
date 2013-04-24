#!/bin/bash
#
# Uses a provisioning profile on the local filesystem.
# See the PROFILE_FILE and EXPECTED_PROFILE_NAME in the Configuration Section.
#
# Levi Brown
# mailto:levigroker@gmail.com
# Created March 7, 2013
##

function usage()
{
	[ "$@" = "" ] || echo "$@"
	echo "Usage:"
	echo "$0 distribution|development <profile_name> [<destination_directory>]"
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


PROFILE_HOME="$HOME/Library/MobileDevice/Provisioning Profiles/"
cd "$PROFILE_HOME"

# ----------------------
# Configuration Section
# ----------------------
#The hardcoded profile file
PROFILE_FILE="CHANGE_ME.mobileprovision"
#The hardcoded profile name we are expecting
EXPECTED_PROFILE_NAME="CHANGE_ME AdHoc"
#The name of the desired profile (as entered in the dev portal)
PROFILE_TYPE=${1:-""}
#The profile type (could be either "distribution" or "development")
PROFILE_NAME=${2:-""}
#The optional destination directory for the resulting mobileprovision file
PROFILE_DEST=${3:-"."}
#The directory to find the mobileprovision file(s)
PROFILE_DIR=${PROFILE_DIR:-$CI_DIR}
DEBUG=${DEBUG:-0}

# Fully qualified binaries
CP="/bin/cp"

# Sanity check input
if [ "$PROFILE_TYPE" != "distribution" -a "$PROFILE_TYPE" != "development" ]; then
	usage "Unknown/unspecified profile type given (\"$PROFILE_TYPE\")."
fi

if [ "$PROFILE_NAME" = "" ]; then
	usage "Empty profile name specified."
fi

# Hard Coded profile/name mapping for now

if [ "$PROFILE_TYPE" != "distribution" -o "$PROFILE_NAME" != "$EXPECTED_PROFILE_NAME" ]; then
	fail "Unsupported profile \"$PROFILE_NAME\" and type \"$PROFILE_TYPE\""
fi

`$CP "$PROFILE_DIR/$PROFILE_FILE" "$PROFILE_DEST"`

# Return the profile file name
echo "$PROFILE_FILE"
