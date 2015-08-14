#!/bin/bash
#
# Common configuration for pre and post build scripts
#
# Prior to calling, you'll need to export 'CI_DIR' as the directory which is home to this
# and other related scripts, such as configure.sh, pre_action.sh, local_profile.sh,
# testflight.sh, crashlytics.sh, etc.
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
export CI_DIR=${CI_DIR:-"$PROJECT_DIR/CI"}
echo "CI directory: \"$CI_DIR\""
# The project specific Continuous Integration path
export PROJECT_CI_DIR=${PROJECT_CI_DIR:-"$PROJECT_DIR/CI"}
echo "Project CI directory: \"$PROJECT_CI_DIR\""
# The directory containing the provisioning profile file(s) in the repository
export PROFILE_DIR=${PROFILE_DIR:-"$PROJECT_CI_DIR"}
echo "Profile directory: \"$PROFILE_DIR\""

# The working location where we will stage our provisioning profile
export PROFILE_HOME="$PROJECT_DIR/profile"
# The location where Xcode bots look for provisioning profiles
export PROFILE_BOT_LOC="/Library/Developer/XcodeServer/ProvisioningProfiles"
echo "Xcode bot provisioning profile directory: \"$PROFILE_BOT_LOC\""
# The full path to the file we will use to store the git hash of the last successful build
export GIT_REV_FILE="/Library/Developer/XcodeServer/Integrations/$SCHEME_NAME.last_success_git_hash.txt"
echo "Git latest rev file: \"$GIT_REV_FILE\""

# Script relative to $CI_DIR which will return the release notes for this build
export GIT_HISTORY_SCRIPT="git_history.sh"
# Release note formatting (See 'git help log' for format details)
export GIT_LOG_FORMAT="%ai %an: %B"

# Script relative to $CI_DIR which will upload the built IPA to TestFlight
export TEST_FLIGHT_UPLOAD_SCRIPT="testflight.sh"
# Script relative to $CI_DIR which will upload the built IPA to Crashlytics
export CRASHLYTICS_UPLOAD_SCRIPT="crashlytics.sh"
# Script relative to $CI_DIR which will fetch the provisioning profile
# (takes <profile_type>(development|distribution) and <profile_name> as arguments)
# returns the name of the profile file which should be present in the current directory
# after the script exits successfully.
export PROFILE_ACQUISITION_SCRIPT="local_profile.sh"

# The type of profile we will fetch with the PROFILE_ACQUISITION_SCRIPT. Should be either "development" or "distribution".
export PROFILE_TYPE="distribution"

# The current Integration Number
export INTEGRATION_NUMBER=$XCS_INTEGRATION_NUMBER
echo "Integration number: \"$INTEGRATION_NUMBER\""
export BASE_BUILD_NUMBER=${BASE_BUILD_NUMBER:-0}
echo "Base build number: \"$BASE_BUILD_NUMBER\""
export BUILD_NUMBER=${BUILD_NUMBER:-$((BASE_BUILD_NUMBER + INTEGRATION_NUMBER))}
echo "Build number: \"$BUILD_NUMBER\""

echo "Done with configuration script!"
