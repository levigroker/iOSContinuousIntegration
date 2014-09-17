#!/bin/bash
#
# A script to upload an IPA and dSYM to TestFlight ( http://testflightapp.com) with
# release notes to optional distribution lists.
#
# Levi Brown
# mailto:levigroker@gmail.com
# October 5, 2011
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 <ipa file> <dsym zip file> <release_notes> [<distribution_lists>]" >&2
    exit 1
}

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}

DEBUG=${DEBUG:-0}

set -eu
[ $DEBUG -ne 0 ] && set -x

IPA_FILE=${1:-""}
DSYM_ZIP=${2:-""}
NOTES=${3:-"Automated build."}
DIST=${4:-""}

TF_API_URL="http://testflightapp.com/api/builds.json"

# Start: Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
TF_API_TOKEN=${TF_API_TOKEN:-""}
TF_TEAM_TOKEN=${TF_TEAM_TOKEN:-""}

# Fully qualified binaries
GREP_B="/usr/bin/grep"
CURL_B="/usr/bin/curl"

if [ "$TF_API_TOKEN" = "" ]; then
	usage "Empty TestFlight API token specified. Please export TF_API_TOKEN with the needed API token."
fi

if [ "$TF_TEAM_TOKEN" = "" ]; then
	usage "Empty TestFlight Team token specified. Please export TF_API_TOKEN with the needed team token."
fi

# End: Prevent sensitive info from going to the console
[ $DEBUG -ne 0 ] && set -x

if [ "$IPA_FILE" = "" ]; then
	usage "No .ipa file specified."
elif [ "$IPA_FILE" = "-h" -o "$IPA_FILE" = "--help" -o "$IPA_FILE" = "?" ]; then
    usage
fi

if [ "$DSYM_ZIP" = "" ]; then
	usage "No dSYM zip file specified."
elif [ "$DSYM_ZIP" = "-h" -o "$DSYM_ZIP" = "--help" -o "$DSYM_ZIP" = "?" ]; then
    usage
fi

# Start: Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
if [ "$DIST" = "" ]; then
	REZ=`$CURL_B "$TF_API_URL" -F file="@$IPA_FILE" -F dsym="@$DSYM_ZIP" -F api_token="$TF_API_TOKEN" -F team_token="$TF_TEAM_TOKEN" -F notes="$NOTES" -F notify=True || fail "Upload to TestFlight failed."`
else
	REZ=`$CURL_B "$TF_API_URL" -F file="@$IPA_FILE" -F dsym="@$DSYM_ZIP" -F api_token="$TF_API_TOKEN" -F team_token="$TF_TEAM_TOKEN" -F notes="$NOTES" -F notify=True -F distribution_lists="$DIST" || fail "Upload to TestFlight failed."`
fi
# End: Prevent sensitive info from going to the console
[ $DEBUG -ne 0 ] && set -x

KEY=`echo "$REZ" | $GREP_B install_url`
if [ "$KEY" == "" ]; then
	fail "$REZ"
else
	echo "Uploaded \"$IPA_FILE\" to TestFlight!"
fi
