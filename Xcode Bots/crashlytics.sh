#!/bin/bash
#
# A script to upload an IPA Crashlytics ( http://crashlytics.com) with optional release
# notes.
#
# Levi Brown
# mailto:levigroker@gmail.com
# August 14, 2014
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 <ipa file> [<release_notes>]" >&2
    exit 1
}

function fail()
{
    echo "$0 Failed: $@" >&2
    exit 1
}

DEBUG=${DEBUG:-0}

set -eu
[ $DEBUG -ne 0 ] && set -x

IPA_FILE=${1:-""}
NOTES=${2:-"Automated build."}

# Fully qualified binaries
FIND_B="/usr/bin/find"
MKTEMP_B="/usr/bin/mktemp"
RM_B="/bin/rm"
TAIL_B="/usr/bin/tail"
BASENAME_B="/usr/bin/basename"

#Find the first Crashlytics.framework
CRASHLYTICS_FWK="Crashlytics.framework" 
CRASHLYTICS_FWK_PATH=$($FIND_B . -name "$CRASHLYTICS_FWK" | $TAIL_B -1)
if [ "$CRASHLYTICS_FWK_PATH" = "" ]; then
	fail "Could not locate $CRASHLYTICS_FWK in current project subdirectory."
fi
SUBMIT_B="$CRASHLYTICS_FWK_PATH/submit"

# Start: Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
CL_API_KEY=${CL_API_KEY:-""}
CL_BUILD_SECRET=${CL_BUILD_SECRET:-""}
CL_DIST_LIST=${CL_DIST_LIST:-""}

if [ "$CL_API_KEY" = "" ]; then
	usage "Empty API key specified. Please export CL_API_KEY with the needed API key."
fi

if [ "$CL_BUILD_SECRET" = "" ]; then
	usage "Empty Build Secret specified. Please export CL_BUILD_SECRET with the needed token."
fi

# End: Prevent sensitive info from going to the console
[ $DEBUG -ne 0 ] && set -x

if [ "$IPA_FILE" = "" ]; then
	usage "No .ipa file specified."
elif [ "$IPA_FILE" = "-h" -o "$IPA_FILE" = "--help" -o "$IPA_FILE" = "?" ]; then
    usage
fi

#Since Crashlytics submit needs a file for the release notes we need to write the notes
#to a temp file...
BASENAME=`$BASENAME_B $0`
NOTES_PATH=`$MKTEMP_B -q "/tmp/$BASENAME.XXXXXX"`
if [ $? -ne 0 ]; then
	fail "Can not create temp file: \"$NOTES_PATH\""
fi
echo "$NOTES" > "$NOTES_PATH"

# Start: Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
set +e
REZ=`"$SUBMIT_B" $CL_API_KEY $CL_BUILD_SECRET -ipaPath "$IPA_FILE" -notesPath "$NOTES_PATH" -groupAliases "$CL_DIST_LIST" -notifications YES -debug YES`
FAILURE=$?
set -e
# End: Prevent sensitive info from going to the console
[ $DEBUG -ne 0 ] && set -x

#Clean up our temp file
$RM_B -f "$NOTES_PATH"

if [ $FAILURE -ne 0 ]; then
	fail "Submission to Crashlytics failed: $REZ"
fi

echo "Successfully submitted \"$IPA_FILE\" to Crashlytics!"
