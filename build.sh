#!/bin/sh
# Original concept from http://nachbaur.com/blog/how-to-automate-your-iphone-app-builds-with-hudson
# (modified heavily since)
#
# NOTE: This is intended to be run relative to the Jenkins WORKSPACE and due to Jenkins
# populating WORKSPACE with a non-absolute path, this script attempts to gather absolute
# path information with the assumption that it is being executed at the root level of
# the repository. So, when running manually, execute it accordingly, or paths are likely
# to break.
# Example:
# % pwd
# /Users/labrown/Documents/Development/MyProject
# % /bin/sh MyProject/MyProject/jenkins/build.sh
#
# You can prevent the build from uploading to TestFlight by specifying TF_UPLOAD=0, like:
# % TF_UPLOAD=0 /bin/sh MyProject/MyProject/jenkins/build.sh
#
# Differences in behavior fork from the BRANCH being built. BRANCH is being set from git
# but can be overridden by specifying BRANCH="branch_name" manually, like:
# % BRANCH="development" /bin/sh MyProject/MyProject/jenkins/build.sh
#
# Manual builds will get build number "1"
#
# Levi Brown
# mailto:levigroker@gmail.com
# October 5, 2011
##

# Jenkins needs to have the "Test report XMLs" configuration set to:
#	MyProject/output/test-results/*.xml

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}
DEBUG=${DEBUG:-0}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

# ----------------------
# Configuration Section
# ----------------------
# The password for the KEYCHAIN containing the credentials, certificates and keys needed
# for the build.
KEYCHAIN_PASSWORD=${KEYCHAIN_PASSWORD:-""}
# The name of the resulting application (for instance, the IPA will be named "$APP_NAME.ipa")
APP_NAME=${APP_NAME:-""}
PROJECT_NAME=${PROJECT_NAME:-"$APP_NAME"}
# The sub-directory (of the Jenkins WORKSPACE directory) containing the actual Xcode
# project file.
PROJECT_DIR="$PROJECT_NAME"
# Subdirectory of the PROJECT_DIR containing the project sources and resources
# $RESOURCE_DIR/jenkins should contain the provisioning profile(s) and this script.
RESOURCE_DIR="$PROJECT_NAME"
XCODE_WORKSPACE="$PROJECT_NAME.xcworkspace"
MAIN_SCHEME="$PROJECT_NAME"
TEST_SCHEME="Tests"
MASTER_BRANCH_NAME="master"

## Build Configurations
# The space separated list of Xcode project configurations to build.
CONFIGURATIONS="AdHoc"
# Each configuration listed in CONFIGURATIONS should have a corresponding mobileprovision
# name defined.
AdHoc="$PROJECT_NAME AdHoc"
# The type of profile (used to download the profile from the Apple Developer portal)
PROFILE_TYPE="distribution"

## Jenkins Configuration
# See https://wiki.jenkins-ci.org/display/JENKINS/Authenticating+scripted+clients
export JENKINS_USER=${JENKINS_USER:-""}
export JENKINS_API_TOKEN=${JENKINS_API_TOKEN:-""}

## Branch configuration
# Determine what branch is being built so we can behave accordingly
# Pull this information from git directly if not already set
BRANCH=${BRANCH:-"$(git describe --contains --all HEAD | sed 's|^.*/||')"}

## TestFlight distribution lists
# Default:
TF_DIST_LISTS="Development"
# "master" branch
[ "$BRANCH" = "$MASTER_BRANCH_NAME" ] && TF_DIST_LISTS="Internal Release"
# TestFlight upload configuration
export TF_API_TOKEN=${TF_API_TOKEN:-""}
export TF_TEAM_TOKEN=${TF_TEAM_TOKEN:-""}
# You can prevent the build from uploading to TestFlight by specifying TF_UPLOAD=0, like:
# % TF_UPLOAD=0 /bin/sh MyProject/MyProject/jenkins/build.sh
TF_UPLOAD=${TF_UPLOAD:-1}

# -----------------------

## These get set by Jenkins
BUILD_NUMBER=${BUILD_NUMBER:-"1"}
WORKSPACE=${WORKSPACE:-"(not defined)"}
JOB_URL=${JOB_URL:-""}

## Standard configs (probably don't need changing)
SDK="iphoneos"
SIMULATOR_SDK="iphonesimulator"
# Release note formatting (See 'git help log' for format details)
GIT_LOG_FORMAT="%ai %an: %s"
KEYCHAIN="$HOME/Library/Keychains/login.keychain"
PROFILE_HOME="$HOME/Library/MobileDevice/Provisioning Profiles/"
# Script relative to $RESOURCE_DIR/jenkins which will download mobileprovision profile files
PROFILE_DOWNLOAD_SCRIPT="download_profile.sh"
# Script relative to $RESOURCE_DIR/jenkins which will upload the built IPA
TEST_FLIGHT_UPLOAD_SCRIPT="testflight.sh"
# Script relative to $RESOURCE_DIR/jenkins which will get the last successful revision hash
LAST_SUCCESS_REV_SCRIPT="last_success_rev.sh"

# -------------------------
# End Configuration Section
# -------------------------

# Validate the configuration

if [ "$APP_NAME" = "" ]; then
	fail "Empty APP_NAME specified. Please export APP_NAME with the application name."
fi

if [ "$PROJECT_NAME" = "" ]; then
	fail "Empty PROJECT_NAME specified. Please export PROJECT_NAME with the project name."
fi

if [ "$KEYCHAIN_PASSWORD" = "" ]; then
	fail "Empty KEYCHAIN_PASSWORD specified. Please export KEYCHAIN_PASSWORD with build user's keychain password."
fi

if [ "$JENKINS_USER" = "" ]; then
	fail "Empty JENKINS_USER specified. Please export JENKINS_USER with the desired Jenkins username."
fi

if [ "$JENKINS_API_TOKEN" = "" ]; then
	fail "Empty JENKINS_API_TOKEN specified. Please export JENKINS_API_TOKEN with the needed Jenkins API token."
fi

if [ "$TF_API_TOKEN" = "" ]; then
	usage "Empty TestFlight API token specified. Please export TF_API_TOKEN with the needed API token."
fi

if [ "$TF_TEAM_TOKEN" = "" ]; then
	usage "Empty TestFlight Team token specified. Please export TF_API_TOKEN with the needed team token."
fi

## Main

echo "Jenkins workspace: \"$WORKSPACE\""

# Capture the full path to our project
cd "$PROJECT_DIR"
PROJECT_DIR="$(pwd)"
echo "$APP_NAME project directory: \"$PROJECT_DIR\""
RESOURCE_DIR="$PROJECT_DIR/$RESOURCE_DIR"
echo "$APP_NAME resource directory: \"$RESOURCE_DIR\""

# Set up our output directory
export OUTPUT="$PROJECT_DIR/output"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

echo "Unlocking keychain..."
[ $DEBUG -ne 0 ] && set +x
/usr/bin/security list-keychains -s "$KEYCHAIN"
/usr/bin/security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
[ $DEBUG -ne 0 ] && set -x

# Fetch the release notes from source control
echo "Fetching release notes from source control..."
LAST_SUCCESS_REV=${LAST_SUCCESS_REV:-$("$RESOURCE_DIR/jenkins/$LAST_SUCCESS_REV_SCRIPT" "$JOB_URL")}
[ "$LAST_SUCCESS_REV" = "" ] && echo "Could not determine last successful build revision from Jenkins" || echo "Last build success revision: $LAST_SUCCESS_REV"
[ "$LAST_SUCCESS_REV" = "" ] && RELEASE_NOTES=$(git show -s --format="$GIT_LOG_FORMAT") || RELEASE_NOTES=$(git log --pretty="$GIT_LOG_FORMAT" $LAST_SUCCESS_REV..HEAD)
[ "$RELEASE_NOTES" = "" ] && RELEASE_NOTES="(no release notes)"
echo "Release Notes:\n$RELEASE_NOTES"

echo "Updating version number..."
cd "$PROJECT_DIR"
agvtool new-version -all $BUILD_NUMBER
#Strip off everything past the first space
MARKETING_VERSION="$(agvtool mvers -terse1 | sed 's|\(^.*\) .*$|\1|')"
#Update the marketing version with our clean version
agvtool new-marketing-version "$MARKETING_VERSION"
FULLVERSION="$(agvtool mvers -terse1) ($(agvtool vers -terse)) $BRANCH"
echo "Version \"$FULLVERSION\" Building..."

for CONFIG in $CONFIGURATIONS; do
	echo "Building for \"$CONFIG\" configuration..."

	# Clean up existing mobileprovisions in favor of what's in source control
	if [ -d "$PROFILE_HOME" ] ; then
		cd "$PROFILE_HOME"
		echo "Cleaning up old provisioning profile(s)."
		rm -f *.mobileprovision
	fi

	# Get the profile name from our configuration
	PROFILE_NAME=$(eval echo \$`echo $CONFIG`)
	echo "Downloading provisioning profile \"$PROFILE_NAME\""

	# Ensure the needed directory structure is in place to receive the mobileprovision profile
	[ -d "$PROFILE_HOME" ] || mkdir -p "$PROFILE_HOME"

	# Download the profile
	cd "$PROFILE_HOME"
	CERT=`. "$RESOURCE_DIR/jenkins/$PROFILE_DOWNLOAD_SCRIPT" "$PROFILE_TYPE" "$PROFILE_NAME"`
	if [ -f "$CERT" ]; then
		echo "Successfully downloaded provisioning profile: \"$CERT\""
	else
		fail "Expected provisioning profile not found: \"$CERT\""
	fi

	# Build and execute the tests
	cd "$PROJECT_DIR"
	xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$TEST_SCHEME" -configuration $CONFIG -sdk $SIMULATOR_SDK clean;
	GHUNIT_CLI=1 WRITE_JUNIT_XML=YES xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$TEST_SCHEME" -configuration $CONFIG -sdk $SIMULATOR_SDK build || fail "Xcode test build failed.";

	# Move test results so Jenkins can locate them reliably
	# Fetch the BUILD_ROOT from the xcode build configuration directly
	TEST_BUILD_ROOT=`xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$TEST_SCHEME" -configuration $CONFIG -showBuildSettings | grep ' BUILD_ROOT' | uniq | awk '{ print $3}'`
	TEST_OUTPUT_DIR="$TEST_BUILD_ROOT/test-results"
	if [ -d "$TEST_OUTPUT_DIR" ]; then
		cp -Rp "$TEST_OUTPUT_DIR" "$OUTPUT"
	else
		echo "No test output available at \"$TEST_OUTPUT_DIR\""
	fi

	# Build the application
	xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$MAIN_SCHEME" -configuration $CONFIG -sdk $SDK clean;
	xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$MAIN_SCHEME" -configuration $CONFIG -sdk $SDK || fail "Xcode main build failed.";

	echo "Building IPA..."
	# Packaging
	# Fetch the BUILT_PRODUCTS_DIR from the xcode build configuration directly
	BUILT_PRODUCTS_DIR=`xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$MAIN_SCHEME" -configuration $CONFIG -showBuildSettings | grep ' BUILT_PRODUCTS_DIR' | uniq | awk '{ print $3}'`
	cd $BUILT_PRODUCTS_DIR
	rm -rf "Payload"
	rm -f "$APP_NAME".*.ipa
	mkdir "Payload"
	cp -Rp "$APP_NAME.app" "Payload"
	if [ -f "$RESOURCE_DIR/iTunesArtwork" ] ; then
	    cp -f "$RESOURCE_DIR/iTunesArtwork" "Payload"
	fi

	IPA_NAME="$APP_NAME $FULLVERSION $CONFIG.ipa"
	zip -r -y "$IPA_NAME" "Payload"

	mv "$IPA_NAME" "$OUTPUT"

	echo "Built $IPA_NAME"

	# Zip up the dSYM file for uploading to TestFlight
	DYSM_NAME="$APP_NAME.app.dSYM"
	DSYM_ZIP="$DYSM_NAME.zip"
	zip -r -y "$DSYM_ZIP" "$DYSM_NAME"
	mv "$DSYM_ZIP" "$OUTPUT"
	echo "dSYM file ready for upload"

	# Upload to TestFlight
	echo "Distributing to TestFlight list(s): $TF_DIST_LISTS"
	[ $TF_UPLOAD -ne 0 ] && . "$RESOURCE_DIR/jenkins/$TEST_FLIGHT_UPLOAD_SCRIPT" "$OUTPUT/$IPA_NAME" "$OUTPUT/$DSYM_ZIP" "$RELEASE_NOTES" "$TF_DIST_LISTS"
done
