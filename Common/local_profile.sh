#!/bin/bash
#
# Uses a provisioning profile on the local filesystem.
# See the PROFILE_NAMES and PROFILE_FILES in the Configuration Section.
#
# Levi Brown
# mailto:levigroker@gmail.com
# Created March 7, 2013
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 distribution|development <profile_name> [<destination_directory>]" >&2
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

# ----------------------
# Configuration Section
# ----------------------
#The hardcoded profile names we are expecting
PROFILE_NAMES=("CHANGE_ME AdHoc" "CHANGE_ME Enterprise")
#The matching profile files
PROFILE_FILES=("CHANGE_ME_AdHoc.mobileprovision" "CHANGE_ME_Enterprise.mobileprovision")

#The name of the desired profile (as entered in the dev portal)
PROFILE_TYPE=${1:-""}
#The profile type (could be either "distribution" or "development")
PROFILE_NAME=${2:-""}
#The optional destination directory for the resulting mobileprovision file
PROFILE_DEST=${3:-"."}
#The directory to find the provisioning profile file(s)
PROFILE_DIR=${PROFILE_DIR:-"."}
DEBUG=${DEBUG:-0}

# Fully qualified binaries
CP_B="/bin/cp"

# Sanity check input
if [ "$PROFILE_TYPE" != "distribution" -a "$PROFILE_TYPE" != "development" ]; then
	usage "Unknown/unspecified profile type given (\"$PROFILE_TYPE\")."
fi

if [ "$PROFILE_NAME" = "" ]; then
	usage "Empty profile name specified."
fi

# NOTE: Currently we do not care about PROFILE_TYPE in local_profile.sh, so we ignore it

INDX=0
PROFILE_FILE=""
for EXPECTED_NAME in "${PROFILE_NAMES[@]}"; do
	if [ "$PROFILE_NAME" = "$EXPECTED_NAME" ]; then
		PROFILE_FILE="${PROFILE_FILES[$INDX]}"
		break
	fi
	let INDX=INDX+1
done
if [ "$PROFILE_FILE" = "" ]; then
	fail "Unsupported profile \"$PROFILE_NAME\""
fi

`$CP_B "$PROFILE_DIR/$PROFILE_FILE" "$PROFILE_DEST"`

# Return the profile file name
echo "$PROFILE_FILE"
