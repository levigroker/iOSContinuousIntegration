#!/bin/bash
#
# A script to post build info to Slack ( http://slack.com).
#
# Levi Brown
# mailto:levigroker@gmail.com
# August 10, 2016
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 [--channel|-c <channel_name>] [--name|-n <username>] [--icon|-i <emoji_icon_text>] <text> <webhook_url>" >&2
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

# Fully qualified binaries
CURL_B="/usr/bin/curl"

# Defaults
S_CHANNEL="#general"
S_USERNAME="buildbot"
S_ICON=":package:"

# Parse command and options

REMAINS=""
while [[ $# -gt 0 ]]; do
	# Copy so we can modify it (can't modify $1)
	OPT="$1"
	# Detect argument termination
	if [ x"$OPT" = x"--" ]; then
		shift
		for OPT ; do
			REMAINS="$REMAINS \"$OPT\""
		done
		break
	fi
	# Parse current opt
	while [ x"$OPT" != x"-" ] ; do
		case "$OPT" in
			-c | --channel )
					S_CHANNEL="$2"
					shift
					;;
			-n | --name )
					S_USERNAME="$2"
					shift
					;;
			-i | --icon )
					S_ICON="$2"
					shift
					;;
			# Anything unknown is recorded for later
			* )
				REMAINS="$REMAINS \"$OPT\""
				break
				;;
		esac
		# Check for multiple short options
		# NOTICE: be sure to update this pattern to match valid options
		NEXTOPT="${OPT#-[cni]}" # try removing single short opt
		if [ x"$OPT" != x"$NEXTOPT" ] ; then
			OPT="-$NEXTOPT"  # multiple short opts, keep going
		else
			break  # long form, exit inner loop
		fi
	done
	# Done with that param. move to next
	shift
done
# Set the non-parameters back into the positional parameters ($1 $2 ..)
eval set -- $REMAINS

# Non-flagged parameters
S_TEXT=${1:-""}
S_WEBHOOK_URL=${2:-""}

if [ "$S_TEXT" = "" ]; then
	usage "No text message specified."
fi

if [ "$S_WEBHOOK_URL" = "" ]; then
	usage "No webhook URL specified."
fi

REZ=$($CURL_B -s -S -X POST --data-urlencode "payload={\"channel\": \"$S_CHANNEL\", \"username\": \"$S_USERNAME\", \"text\": \"$S_TEXT\", \"icon_emoji\": \"$S_ICON\"}" $S_WEBHOOK_URL)

if [ "$REZ" != "ok" ]; then
	fail "$REZ"
fi
