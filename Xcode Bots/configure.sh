#!/bin/bash
#
# Common configuration for pre and post build scripts
#
# You'll need to create a 'CI' directory in your SRCROOT which is home to this and other
# related scripts, such as pre_action.sh, post_action.sh, local_profile.sh, testflight.sh,
# etc.
#
# Levi Brown
# mailto:levigroker@gmail.com
# June 30, 2014
# https://github.com/levigroker/iOSContinuousIntegration
##

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}
DEBUG=${DEBUG:-1}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

echo "Starting configuration script..."

if [ $DEBUG -ne 0 ]; then
	echo "Environment:"
	echo "-------------------------"
	printenv
	echo "-------------------------"
fi

# Constants
export YES="Yes"
export NO="No"

# Fully qualified binaries (_B suffix to prevent collisions)
export CP_B="/bin/cp"
export LS_B="/bin/ls"
export CAT_B="/bin/cat"
export RM_B="/bin/rm"
export MKDIR_B="/bin/mkdir"
export XCRUN_B="/usr/bin/xcrun"
export ZIP_B="/usr/bin/zip"
export GIT_B="/usr/bin/git"
export GREP_B="/usr/bin/grep"
export TAIL_B="/usr/bin/tail"
export SED_B="/usr/bin/sed"
export HEAD_B="/usr/bin/head"
export AGVTOOL_B="/usr/bin/agvtool"

## Branch configuration
# Determine what branch is being built so we can behave accordingly
# Pull this information from git directly if not already set
cd "$PROJECT_DIR"
export BRANCH=${BRANCH:-$($GIT_B describe --contains --all HEAD | $SED_B 's|^.*/||')}

## Paths
# The path containing this script and related scripts for Continuous Integration
export CI_DIR="$PROJECT_DIR/CI"
echo "CI directory: \"$CI_DIR\""
# The working location where we will stage our provisioning profile
export PROFILE_HOME="$PROJECT_DIR/profile"
# The location where Xcode bots look for provisioning profiles
export PROFILE_BOT_LOC="/Library/Server/Xcode/Data/ProvisioningProfiles"
echo "Xcode bot provisioning profile directory: \"$PROFILE_BOT_LOC\""
# The full path to the file we will use to store the git hash of the last successful build
export GIT_REV_FILE="/Library/Server/Xcode/Data/$SCHEME_NAME.last_success_git_hash.txt"
echo "Git latest rev file: \"$GIT_REV_FILE\""

# Release note formatting (See 'git help log' for format details)
export GIT_LOG_FORMAT="%ai %an: %s"

# Script relative to $CI_DIR which will upload the built IPA to TestFlight
export TEST_FLIGHT_UPLOAD_SCRIPT="testflight.sh"
# Script relative to $CI_DIR which will fetch the provisioning profile
# (takes <profile_type>(development|distribution) and <profile_name> as arguments)
# returns the name of the profile file which should be present in the current directory
# after the script exits successfully.
export PROFILE_ACQUISITION_SCRIPT="local_profile.sh"

# The type of profile we will fetch with the PROFILE_ACQUISITION_SCRIPT. Should be either "development" or "distribution".
export PROFILE_TYPE="distribution"

# The current Build Number (or Integration Number)
# Hack-ish, but it's what we've got.
# See: http://stackoverflow.com/questions/23875979/register-for-messages-from-collabd-like-xcsbuildservice-to-receive-xcode-bots-in
export BUILD_NUMBER=${BUILD_NUMBER:-$($GREP_B -r 'integration =' /Library/Server/Xcode/Logs/xcsbuildd.log | $TAIL_B -1 | $SED_B -E 's|.* ([0-9]+);|\1|')}
echo "Integration number: \"$BUILD_NUMBER\""

echo "Done with configuration script!"
