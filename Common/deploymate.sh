#!/bin/bash
#
# Executes Deploymate code analysis tool
#
# Deploymate Command Line Interface: http://www.deploymateapp.com/kb/cli/
#
# While this can be called independently, this script is meant to be called as part of the
# `build.sh` build process (part of the iOSContinuousIntegration project), which exports
# environment values for the current build, such as `XC_WORKSPACE_DIR` and `XC_WORKSPACE`.
#
# Levi Brown
# mailto:levigroker@gmail.com
# August 12, 2015
# https://github.com/levigroker/iOSContinuousIntegration
##

function fail()
{
    echo "FAIL: $@" >&2
    exit 1
}

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 [-u|--unavailable <count>] [-d|--deprecated <count>] [-s|--scheme <scheme/target>] [-f|--file <project_file>|<workspace_file>]" >&2
	echo "    -u|--unavailable Specify the count of \"Unavailable API\" warnings to consider as a failure." >&2
	echo "    -d|--deprecated  Specify the count of \"Deprecated API\" warnings to consider as a failure." >&2
	echo "    -s|--scheme      Specify the scheme (or \"target\") of the project to analyze." >&2
	echo "                     This overrides the use of the XC_SCHEME environment variable." >&2
	echo "    -f|--file        Specify the count of 'Deprecated API' warnings to consider as a failure." >&2
	echo "                     This overrides the use of the XC_WORKSPACE and XC_WORKSPACE_DIR environment variables." >&2
	echo "  Specifying <count> as 0 will ignore warnings of that type." >&2
    exit 1
}

DEBUG=${DEBUG:-0}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

# Parse command line parameters
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -u|--unavailable)
    # Make sure we have a value in $2
    if [[ -z ${2+x} ]]; then
    	usage
    fi
    UNAVAILABLE_API_THRESHOLD="$2"
    shift # past argument
    ;;
    -d|--deprecated)
    # Make sure we have a value in $2
    if [[ -z ${2+x} ]]; then
    	usage
    fi
    DEPRECATED_API_THRESHOLD="$2"
    shift # past argument
    ;;
	-s|--scheme)
    # Make sure we have a value in $2
    if [[ -z ${2+x} ]]; then
    	usage
    fi
    XC_SCHEME="$2"
    shift # past argument
    ;;
	-f|--file)
    # Make sure we have a value in $2
    if [[ -z ${2+x} ]]; then
    	usage
    fi
    XC_FILE="$2"
    shift # past argument
    ;;
    *)
    # Unknown option
    usage
    ;;
esac
shift # past argument or value
done

## Defaults
UNAVAILABLE_API_THRESHOLD=${UNAVAILABLE_API_THRESHOLD:-1}
# Ensure we have a number
if [[ ! $UNAVAILABLE_API_THRESHOLD =~ ^[-+]?[0-9]+$ ]]
then
    usage
fi

DEPRECATED_API_THRESHOLD=${DEPRECATED_API_THRESHOLD:-1}
# Ensure we have a number
if [[ ! $DEPRECATED_API_THRESHOLD =~ ^[-+]?[0-9]+$ ]]
then
    usage
fi

XC_FILE=${XC_FILE:-""}

## Fully qualified binaries
GREP_B="/usr/bin/grep"
WC_B="/usr/bin/wc"
XARGS_B="/usr/bin/xargs"
DEPLOYMATE_B="/Applications/Deploymate.app/Contents/MacOS/Deploymate"

# We only care about XC_WORKSPACE_DIR and XC_WORKSPACE if XC_FILE was not specified as a
# CLI parameter
if [ "$XC_FILE" = "" ]; then
	# The directory containing the Xcode xxx.workspace file which we will analyze.
	XC_WORKSPACE_DIR=${XC_WORKSPACE_DIR:-""}
	if [ "$XC_WORKSPACE_DIR" = "" ]; then
		fail "XC_WORKSPACE_DIR not specified. Please export XC_WORKSPACE_DIR as the directory containing your xcworkspace."
	fi
	# The Xcode xxx.workspace file which we will analyze.
	XC_WORKSPACE=${XC_WORKSPACE:-""}
	if [ "$XC_WORKSPACE" = "" ]; then
		fail "XC_WORKSPACE not specified. Please export XC_WORKSPACE as the xxx.xcworkspace to build."
	fi
	XC_FILE="$XC_WORKSPACE_DIR/$XC_WORKSPACE"
fi

# The Xcode build scheme (target) we will analyze
XC_SCHEME=${XC_SCHEME:-""}
if [ "$XC_SCHEME" = "" ]; then
	fail "XC_SCHEME not specified. Please export XC_SCHEME as the build scheme to use."
fi

if [ ! -x "$DEPLOYMATE_B" ]; then
	fail "Unable to locate Deploymate binary at: \"$DEPLOYMATE_B\""
fi

BUILD_FAILURE=0

REZ=$("$DEPLOYMATE_B" --cli --output-format=default --loglevel=warn --target "$XC_SCHEME" "$XC_FILE")
echo "$REZ"

if [ "$UNAVAILABLE_API_THRESHOLD" -gt 0 ]; then
	UNAVAILABLE_API_COUNT=$(echo "$REZ" | $GREP_B "\[Unavailable API\]" | $WC_B -l | $XARGS_B)
	echo "Unavailable API warning count: $UNAVAILABLE_API_COUNT threshold: $UNAVAILABLE_API_THRESHOLD"
	if [[ $UNAVAILABLE_API_COUNT -ge $UNAVAILABLE_API_THRESHOLD ]]; then
		BUILD_FAILURE=1
	fi
fi

if [ "$DEPRECATED_API_THRESHOLD" -gt 0 ]; then
	DEPRECATED_API_COUNT=$(echo "$REZ" | $GREP_B "\[Deprecated API\]" | $WC_B -l | $XARGS_B)
	echo "Deprecated API warning count: $DEPRECATED_API_COUNT threshold: $DEPRECATED_API_THRESHOLD"
	if [[ $DEPRECATED_API_COUNT -ge DEPRECATED_API_THRESHOLD ]]; then
		BUILD_FAILURE=1
	fi
fi

if [[ $BUILD_FAILURE -ne 0 ]]; then
	fail "Too many warnings."
fi
