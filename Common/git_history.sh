#!/bin/bash
#
# Pulls git commit history between two revision hashes and returns a formatted result.
#
# Usage is as simple as:
#
# % cd <your repo>
# % git_history.sh 663bc9427b609554c57663196b6a36651df6f3c1
#
# Which will fetch all history from the commit with the given hash to HEAD.
#
# Supply a second hash to specify a range:
#
# % cd <your repo>
# % git_history.sh 663bc9427b609554c57663196b6a36651df6f3c1 eebf0e48a10dfc43b4d579734c0199941171376f
#
# The output format defaults to "%ai %an: %B" but can be overridden by exporting
# `GIT_LOG_FORMAT` with the desired format string (see 'git help log' for format details).
#
# Levi Brown
# mailto:levigroker@gmail.com
# September 16, 2014
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 <start hash> [<end hash>]" >&2
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

# Release note formatting (See 'git help log' for format details)
export GIT_LOG_FORMAT=${GIT_LOG_FORMAT:-"%ai %an: %B"}

# Fully qualified binaries (_B suffix to prevent collisions)
GIT_B="/usr/bin/git"
SED_B="/usr/bin/sed"

START_REV=${1:-""}
END_REV=${2:-""}

if [ "$START_REV" = "--help" -o "$START_REV" = "-h" ]; then
	usage
fi

if [ "$START_REV" = "" ]; then
	usage "Empty starting commit hash specified."
fi

if [ "$END_REV" = "" -o "$END_REV" = "HEAD" ]; then
	END_REV=$($GIT_B rev-parse --verify HEAD)
fi

RELEASE_NOTES=$($GIT_B log --notes --reverse --pretty="$GIT_LOG_FORMAT" $START_REV..$END_REV)

if [[ "$RELEASE_NOTES" != "" ]]; then
	BRANCH=$($GIT_B describe --contains --all HEAD | $SED_B 's|^.*/||')
	HEADER="Commit History"$'\n'"---"$'\n'"- From Revision: \"$START_REV\""$'\n'"- To Revision:   \"$END_REV\""$'\n'"- Branch:        \"$BRANCH\""$'\n'"---"$'\n'
	RELEASE_NOTES="$HEADER"$'\n'"$RELEASE_NOTES"
fi
echo "$RELEASE_NOTES"
