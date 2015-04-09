#!/bin/bash
#
# A script to use with Xcode bots as a "Post-action" script on the Archive phase of a
# continuous integration Xcode scheme. The intention is, after a successful archive is
# generated this script will collect the git commit history since the last success,
# package up the archive into a signed ipa, zip the dSYM, and then upload all that to
# TestFlight.
#
# Inspiration and some problem solving from:
# http://matt.vlasach.com/xcode-bots-hosted-git-repositories-and-automated-testflight-builds/
#
# Usage:
#
# From within your CI scheme in Xcode call this script from a new "Run Script" Post Action
# on the Archive phase. Some simple configuration is needed, so in the Run Script specify
# /bin/bash as the shell, then use something like this to initiate the script:
#
# TF_UPLOAD=1
# SIGNING_IDENTITY="iPhone Distribution: ProGroker LLC"
# TF_DIST_LIST="Internal,Foo"
# TF_API_TOKEN="actualtestflightapitoken"
# TF_TEAM_TOKEN="actualtestflightteamtoken"
# CL_UPLOAD=1
# CL_API_KEY="actualcrashlytlicsapikey"
# CL_BUILD_SECRET="actualcrashlytlicsbuildsecret"
# CL_DIST_LIST="Internal,Foo"
# CI_DIR="${PROJECT_DIR}/CI"
# source "${CI_DIR}/post_action.sh"
#

# Prior to calling, you'll need to export 'CI_DIR' as the directory which is home to this
# and other related scripts, such as configure.sh, pre_action.sh, local_profile.sh,
# testflight.sh, crashlytics.sh, etc.
#
# Levi Brown
# mailto:levigroker@gmail.com
# August 14, 2014
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

echo "Starting post action script..."

# Common configuration
source "$CI_DIR/configure.sh"

# ----------------------
# Configuration Section
# ----------------------
SIGNING_IDENTITY=${SIGNING_IDENTITY:-""}

## TestFlight distribution lists
export TF_DIST_LIST=${TF_DIST_LIST:-""}
# You can enable uploading the build to TestFlight by specifying TF_UPLOAD=1
TF_UPLOAD=${TF_UPLOAD:-0}
# Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
# TestFlight upload configuration
export TF_API_TOKEN=${TF_API_TOKEN:-""}
export TF_TEAM_TOKEN=${TF_TEAM_TOKEN:-""}

# You can enable uploading the build to Crashlytics by specifying CL_UPLOAD=1
CL_UPLOAD=${CL_UPLOAD:-0}
# Crashlytics upload configuration
export CL_API_KEY=${CL_API_KEY:-""}
export CL_BUILD_SECRET=${CL_BUILD_SECRET:-""}
## Crashlytics Beta distribution lists
export CL_DIST_LIST=${CL_DIST_LIST:-""}

[ $DEBUG -ne 0 ] && set -x

# -------------------------
# End Configuration Section
# -------------------------

# Validate the configuration

if [ $TF_UPLOAD -ne 0 -o $CL_UPLOAD -ne 0 ]; then
	if [ "$SIGNING_IDENTITY" = "" ]; then
		fail "Empty signing identity specified. Please export SIGNING_IDENTITY with the name of the signing identity to use."
	fi
fi

if [ $TF_UPLOAD -ne 0 ]; then
	# Prevent sensitive info from going to the console in debug mode.
	[ $DEBUG -ne 0 ] && set +x
	if [ "$TF_API_TOKEN" = "" ]; then
		fail "Empty TestFlight API token specified. Please export TF_API_TOKEN with the needed API token."
	fi

	if [ "$TF_TEAM_TOKEN" = "" ]; then
		fail "Empty TestFlight Team token specified. Please export TF_API_TOKEN with the needed team token."
	fi
	[ $DEBUG -ne 0 ] && set -x
fi

if [ $CL_UPLOAD -ne 0 ]; then
	# Prevent sensitive info from going to the console in debug mode.
	[ $DEBUG -ne 0 ] && set +x
	if [ "$CL_API_KEY" = "" ]; then
		fail "Empty Crashlytics Beta API key specified. Please export CL_API_KEY with the needed API key."
	fi

	if [ "$CL_BUILD_SECRET" = "" ]; then
		fail "Empty Crashlytics Beta build secret specified. Please export CL_BUILD_SECRET with the needed build secret."
	fi
	[ $DEBUG -ne 0 ] && set -x
fi

## Main

# Fetch the release notes from source control
echo "Fetching release notes from source control..."
LAST_SUCCESS_REV=${LAST_SUCCESS_REV:-""}
if [ "$LAST_SUCCESS_REV" = "" ]; then
  if [ -r "$GIT_REV_FILE" ]; then
    LAST_SUCCESS_REV=$($CAT_B "$GIT_REV_FILE")
  fi
fi
[ "$LAST_SUCCESS_REV" = "" ] && echo "Could not determine last successful build revision" || echo "Last build success revision: $LAST_SUCCESS_REV"
cd "$PROJECT_DIR"
# If we didn't find the last successful revision, then just get the notes since checkout,
# otherwise, use the GIT_HISTORY_SCRIPT to get all notes from that rev to HEAD.
[ "$LAST_SUCCESS_REV" = "" ] && RELEASE_NOTES=$($GIT_B show -s --format="$GIT_LOG_FORMAT" | $TAIL_B -r) || RELEASE_NOTES=$("$CI_DIR/$GIT_HISTORY_SCRIPT" "$LAST_SUCCESS_REV")
[ "$RELEASE_NOTES" = "" ] && RELEASE_NOTES="(no release notes)"
echo -e "Release Notes:\n$RELEASE_NOTES"

if [ $TF_UPLOAD -ne 0 -o $CL_UPLOAD -ne 0 ]; then
	# Set up our output directory
	OUTPUT="$PROJECT_DIR/output"
	$RM_B -rf "$OUTPUT"
	$MKDIR_B -p "$OUTPUT"

	# Copy the latest build the bot just created to our output directory
	echo "Copying latest Archive from \"$ARCHIVE_PATH\" to \"$OUTPUT\"..."
	$CP_B -Rp "$ARCHIVE_PATH" "$OUTPUT"

	# The actual provisioning file found in PROFILE_HOME
	PROFILE_FILE=${PROFILE_FILE:-$($LS_B "$PROFILE_HOME" | $HEAD_B -1)}
	echo "Profile file: \"$PROFILE_FILE\""
	# The full path to the provisioning profile to bundle in the app
	BUNDLE_PROFILE="$PROFILE_BOT_LOC/$PROFILE_FILE"
	echo "Profile to bundle: \"$BUNDLE_PROFILE\""

	DYSM_NAME="$PRODUCT_NAME.app.dSYM"
	DSYM="$OUTPUT/Archive.xcarchive/dSYMs/$DYSM_NAME"
	APP="$OUTPUT/Archive.xcarchive/Products/Applications/$PRODUCT_NAME.app"
	IPA="$OUTPUT/$PRODUCT_NAME.ipa"

	echo "Creating \"$IPA\"..."
	$XCRUN_B -sdk iphoneos PackageApplication -v "$APP" -o "$IPA" --sign "$SIGNING_IDENTITY" --embed "$BUNDLE_PROFILE"
	echo "Built \"$IPA\""

	# Zip up the dSYM file for uploading to TestFlight
	DSYM_ZIP="$OUTPUT/$DYSM_NAME.zip"
	echo "Zipping dSYM \"$DSYM\" to \"$DSYM_ZIP\"..."
	$ZIP_B -r -y "$DSYM_ZIP" "$DSYM"
	echo "dSYM file ready for upload"

	# Upload to TestFlight
	if [ $TF_UPLOAD -ne 0 ]; then
		echo "Distributing to TestFlight list(s): $TF_DIST_LIST"
		. "$CI_DIR/$TEST_FLIGHT_UPLOAD_SCRIPT" "$IPA" "$DSYM_ZIP" "$RELEASE_NOTES" "$TF_DIST_LIST"
	fi

	# Upload to Crashlytics
	if [ $CL_UPLOAD -ne 0 ]; then
		echo "Submitting IPA to Crashlytics"
		. "$CI_DIR/$CRASHLYTICS_UPLOAD_SCRIPT" "$IPA" "$RELEASE_NOTES"
	fi
fi

# Update our last success rev hash
REV=$($GIT_B rev-parse --verify HEAD)
echo "$REV" > "$GIT_REV_FILE"

echo "Done with post action script!"
