#!/bin/bash
#
# A wrapper around Cupertino https://github.com/mattt/cupertino which allows for automated
# downloads of named provisioning profiles.
#
# NOTE: This assumes `ios login` has previously been performed and the needed credentials
# are stored in the calling user's Keychain.
# NOTE: This assumes the calling user's Keychain is unlocked.
#
# Levi Brown
# mailto:levigroker@gmail.com
# March 7, 2013
##

function usage()
{
	[ "$@" = "" ] || echo "$@"
	echo "Usage:"
	echo "$0 distribution|development <profile_name>"
    exit 1
}

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}

#The name of the desired profile (as entered in the dev portal)
PROFILE_TYPE=${1:-""}
#The profile type (could be either "distribution" or "development")
PROFILE_NAME=${2:-""}
DEBUG=${DEBUG:-0}

set -eu
[ $DEBUG -ne 0 ] && set -x

# Sanity check input
if [ "$PROFILE_TYPE" != "distribution" -a "$PROFILE_TYPE" != "development" ]; then
	usage "Unknown/unspecified profile type given (\"$PROFILE_TYPE\")."
fi

if [ "$PROFILE_NAME" = "" ]; then
	usage "Empty profile name specified."
fi

# Fully qualified binaries
AWK="/usr/bin/awk"
SED="/usr/bin/sed"
IOS="ios" #We'll just use the default since Ruby can do strange things with the path

# Get the list of available distribution profiles
REZ=`$IOS profiles:list $PROFILE_TYPE`
#REZ=`cat foo.txt`
#Skip the first three lines (ascii table headers), separate fields by |, trim leading and trailing whitespace for each field, and print out the profile name.
PROFILES=`echo "$REZ" | $AWK 'BEGIN { FS = "|" } { if (NR>3) { for (i=1;i<=NF;i++) {gsub (/^ */,"",$i); gsub (/ *$/,"",$i) }  print $2 } } END { }'`

# Get the index of the desired target profile (into TARGET)
INDEX=0
TARGET=0
while read -r PROFILE; do
	INDEX=$[$INDEX + 1]
	if [ "$PROFILE" == "$PROFILE_NAME" ]; then
		TARGET=$INDEX
		break
	fi
done <<< "$PROFILES"

if [ $TARGET -eq 0 ]; then
	fail "Desired profile \"$PROFILE_NAME\" not found in the list of profiles."
fi

# Download the desired profile
REZ=`echo "$TARGET" | $IOS profiles:download $PROFILE_TYPE`
PROFILE_FILE=`echo $REZ | $SED 's|.*'\''\(.*\)'\''.*|\1|g'`

# Return the profile file name
# (unfortunately, Cupertino will output the filename of the file it downloaded, not the file it wrote to disk, so this may not be accurate)
echo "$PROFILE_FILE"
