#!/bin/bash
#
# A script to use with Xcode bots as a "Pre-action" script on the Build phase of a
# continuous integration Xcode scheme. The intention is, before the build starts, this
# script will ensure the needed provisioning profile is properly located, and augment the
# version number of the build with the Xcode Bot integration number.
#
# Usage:
#
# From within your CI scheme in Xcode call this script from a new "Run Script" Pre Action
# on the Build phase. Some simple configuration is needed, so in the Run Script specify
# /bin/bash as the shell, then use something like this to initiate the script:
#
# PROFILE_NAME='Awesomesauce AdHoc'
# CI_DIR="${PROJECT_DIR}/CI"
# source "${CI_DIR}/pre_action.sh"
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

echo "Starting pre action script..."

# Common configuration
source "$SRCROOT/CI/configure.sh"

# ----------------------
# Configuration Section
# ----------------------

PROFILE_NAME=${PROFILE_NAME:-""}

# -------------------------
# End Configuration Section
# -------------------------

# Validate the configuration

if [ "$PROFILE_NAME" = "" ]; then
	fail "Empty provisioning profile specified. Please export PROFILE_NAME with the name of the provisioning profile (as named in the dev portal) to use."
fi

## Main

# Clean/set up our profile directory
$RM_B -rf "$PROFILE_HOME"
$MKDIR_B -p "$PROFILE_HOME"

echo "Acquiring provisioning profile \"$PROFILE_NAME\""

# Acquire the profile
cd "$PROFILE_HOME"
PROFILE_FILE=`. "$CI_DIR/$PROFILE_ACQUISITION_SCRIPT" "$PROFILE_TYPE" "$PROFILE_NAME"`
if [ -f "$PROFILE_FILE" ]; then
	echo "Successfully acquired provisioning profile: \"$PROFILE_FILE\""
else
	fail "Expected provisioning profile not found: \"$PROFILE_FILE\""
fi

# Ensure the needed directory structure is in place to receive the mobileprovision profile
[ -d "$PROFILE_BOT_LOC" ] || $MKDIR_B -p "$PROFILE_BOT_LOC"

$CP_B -f "$PROFILE_HOME/$PROFILE_FILE" "$PROFILE_BOT_LOC"
echo "Copied provisioning profile to destination: $PROFILE_BOT_LOC/$PROFILE_FILE"

echo "Updating version number..."
cd "$PROJECT_DIR"
$AGVTOOL_B new-version -all $BUILD_NUMBER
#Get only the first version match, and then strip off everything past the first space
MARKETING_VERSION=$($AGVTOOL_B mvers -terse1 | $GREP_B -v '\$.*' | $HEAD_B -1 | $SED_B 's|\(^.*\) .*$|\1|')
#Update the marketing version with our clean version
$AGVTOOL_B new-marketing-version "$MARKETING_VERSION"
FULLVERSION="$MARKETING_VERSION ($BUILD_NUMBER) $BRANCH"
echo "Full version: \"$FULLVERSION\""

echo "Done with pre action script!"
