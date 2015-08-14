#!/bin/bash
#
# "WORKSPACE" is set by Jenkins or determined as the root of the current git repository.
# "CI_DIR" is a directory containing this and supporting scripts. It is assumed to be a
#   directory named "CI" as a direct child of the "WORKSPACE" directory.
#
# The following environment variables must be set prior to execution:
#
# "XC_WORKSPACE_DIR" The directory (relative to WORKSPACE) containing the .xcworkspace file.
# "XC_WORKSPACE" The .xcworkspace file to build (filename only, no path).
# "XC_SCHEME" The build scheme to use.
# "XC_CONFIG" The Xcode build configuration used for this build
# "XC_PROFILE_NAME" The name of the provisioning profile, as listed in the developer.apple.com portal.
#
# A Post-Build action for the Jenkins job could be added with the TAP plugin to display
# test results (see https://wiki.jenkins-ci.org/display/JENKINS/TAP+Plugin )
# The job configuration "Test results" will be relative to XC_WORKSPACE_DIR:
#	output/junit.xml
#
# Levi Brown
# mailto:levigroker@gmail.com
# Created October 5, 2011
# History:
# 2.0 April 14 2015
#   * Complete re-write from version 1.0.
#
# https://github.com/levigroker/iOSContinuousIntegration
##

function fail()
{
    echo "FAIL: $@" >&2
    exit 1
}

function warn()
{
    echo "WARN: $@" >&2
}

function clean_dir()
{
	if [ "$1" != "" -a "$1" != "/" -a -d "$1" ] ; then
		# Prevent rm failure from killing the build.
		set +e
		pushd "$1" && $RM_B -rf "$1" 1> /dev/null
		popd 1> /dev/null
		set -e
	else
		$MKDIR_B -p "$1"
	fi
}

# Captures the current Xcode build configuration and searches it for the given configuration key, then returns the value of that key
function xc_config()
{
	set +x
	if [ "$XC_BUILD_SETTINGS" == "" ]; then
		pushd "$XC_WORKSPACE_DIR" 1> /dev/null
		XC_BUILD_SETTINGS=`$XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" -showBuildSettings`
		popd 1> /dev/null
	fi
	echo "$XC_BUILD_SETTINGS" | grep " $1 = " | uniq | sed "s|.* $1 = ||"
	set -x
}

DEBUG=${DEBUG:-0}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

echo "Starting build script..."

# Constants
export YES="Yes"
export NO="No"

# Globals
XC_BUILD_SETTINGS=""
# Fix for xcpretty. See: https://github.com/supermarin/xcpretty/issues/137
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

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
export XCODEBUILD_B="/usr/bin/xcodebuild"
export WHICH_B="/usr/bin/which"
export PLISTBUDDY_B="/usr/libexec/Plistbuddy"
export XCPRETTY_B=$($WHICH_B xcpretty)

## Jenkins Configuration

# See https://wiki.jenkins-ci.org/display/JENKINS/Authenticating+scripted+clients
export JENKINS_USER=${JENKINS_USER:-""}
export JENKINS_API_TOKEN=${JENKINS_API_TOKEN:-""}
if [ "$JENKINS_USER" = "" ]; then
	warn "Empty JENKINS_USER specified. Please export JENKINS_USER with the desired Jenkins username."
fi
# Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
if [ "$JENKINS_API_TOKEN" = "" ]; then
	warn "Empty JENKINS_API_TOKEN specified. Please export JENKINS_API_TOKEN with the needed Jenkins API token."
fi
[ $DEBUG -ne 0 ] && set -x
# Jenkins defines JOB_URL but if it is not defined, we set it (blank, but the env variable is set)
JOB_URL=${JOB_URL:-""}

## Paths

# Jenkins defines "WORKSPACE" but if it is not defined, we populate it from the root of the git repository
export WORKSPACE=${WORKSPACE:-$(git rev-parse --show-toplevel)}
echo "Workspace directory: \"$WORKSPACE\""
# The path containing this script and related scripts for Continuous Integration
export CI_DIR=${CI_DIR:-"$WORKSPACE/CI"}
echo "CI directory: \"$CI_DIR\""
# The directory under WORKSPACE containing the Xcode xxx.workspace file which we will build.
export XC_WORKSPACE_DIR=${XC_WORKSPACE_DIR:-""}
XC_WORKSPACE_DIR="$WORKSPACE/$XC_WORKSPACE_DIR"
if [ "$XC_WORKSPACE_DIR" = "" ]; then
	fail "XC_WORKSPACE_DIR not specified. Please export XC_WORKSPACE_DIR as the directory containing your xcworkspace."
fi
echo "XC Workspace directory: \"$XC_WORKSPACE_DIR\""
# The Xcode xxx.workspace file which we will build.
export XC_WORKSPACE=${XC_WORKSPACE:-""}
if [ "$XC_WORKSPACE" = "" ]; then
	fail "XC_WORKSPACE not specified. Please export XC_WORKSPACE as the xxx.xcworkspace to build."
fi
echo "XC Workspace: \"$XC_WORKSPACE\""
# The Xcode build scheme used for this build
export XC_SCHEME=${XC_SCHEME:-""}
if [ "$XC_SCHEME" = "" ]; then
	fail "XC_SCHEME not specified. Please export XC_SCHEME as the build scheme to use."
fi
echo "XC build scheme: \"$XC_SCHEME\""
# The Xcode build configuration used for this build
export XC_CONFIG=${XC_CONFIG:-""}
if [ "$XC_CONFIG" = "" ]; then
	fail "XC_CONFIG not specified. Please export XC_CONFIG as the build configuration to use (e.g. \"AdHoc\")."
fi
echo "XC build configuration: \"$XC_CONFIG\""
# Xcode's derived data directory
XC_DD_DIR="$HOME/Library/Developer/Xcode/DerivedData"
# The location of the directory where provisioning profiles are located
export XC_PROFILE_HOME="$HOME/Library/MobileDevice/Provisioning Profiles/"
# The name of the profile we will fetch with the PROFILE_ACQUISITION_SCRIPT. Should be the name of the provisioning profile, as listed in the developer.apple.com portal.
export XC_PROFILE_NAME=${XC_PROFILE_NAME:-""}
if [ "$XC_PROFILE_NAME" = "" ]; then
	fail "XC_PROFILE_NAME not specified. Please export XC_PROFILE_NAME as the name of the provisioning profile, as listed in the provisioning portal at developer.apple.com."
fi
echo "Provisioning profile: \"$XC_PROFILE_NAME\""
# The type of profile we will fetch with the PROFILE_ACQUISITION_SCRIPT. Should be either "development" or "distribution".
export XC_PROFILE_TYPE=${XC_PROFILE_TYPE:-"distribution"}
# The name of the produced product, with no suffix (e.g. "My App"). This will be used as the archive name.
export XC_PRODUCT_NAME=${XC_PRODUCT_NAME:-$(xc_config "PRODUCT_NAME")}
# Build and test output directory
export OUTPUT_DIR="$XC_WORKSPACE_DIR/output"

## Configuration

# Should tests be built and executed?
export EXECUTE_TESTS=${EXECUTE_TESTS:-1}
# Should static analysis be performed?
export EXECUTE_STATIC_ANALIZER=${EXECUTE_STATIC_ANALIZER:-1}
# Should the archive be generated?
export EXECUTE_ARCHIVE=${EXECUTE_ARCHIVE:-1}

# Keychain support
# NOTE: this script will NOT restore the default login keychain. You should add a
# post-build step to Jenkins to call `keychain.sh restore` even if the build fails.
#
# The keychain file, relative to WORKSPACE, to install for the build
export BUILD_KEYCHAIN=${BUILD_KEYCHAIN:-""}
# The password for the specified keychain
export BUILD_KEYCHAIN_PASS=${BUILD_KEYCHAIN_PASS:-""}

# You can enable uploading the build to Crashlytics by specifying CL_UPLOAD=1
CL_UPLOAD=${CL_UPLOAD:-0}
# Crashlytics Beta distribution lists
export CL_DIST_LIST=${CL_DIST_LIST:-""}
# Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
# Crashlytics upload configuration
export CL_API_KEY=${CL_API_KEY:-""}
export CL_BUILD_SECRET=${CL_BUILD_SECRET:-""}
[ $DEBUG -ne 0 ] && set -x

TF_UPLOAD=${TF_UPLOAD:-0}
#TBD

## Scripts

# Script relative to $CI_DIR which will return the release notes for this build
export GIT_HISTORY_SCRIPT="git_history.sh"
# Release note formatting (See 'git help log' for format details)
export GIT_LOG_FORMAT="%ai %an: %B"
# Script relative to $CI_DIR which will get the last successful revision hash
LAST_SUCCESS_REV_SCRIPT="last_success_rev.sh"

# Script relative to $CI_DIR which will upload the built IPA to TestFlight
export TEST_FLIGHT_UPLOAD_SCRIPT="testflight.sh"
# Script relative to $CI_DIR which will upload the built IPA to Crashlytics
export CRASHLYTICS_UPLOAD_SCRIPT="crashlytics.sh"

# Script relative to $CI_DIR which will fetch the provisioning profile
# (takes <profile_type>(development|distribution) and <profile_name> as arguments)
# returns the name of the profile file which should be present in the current directory
# after the script exits successfully.
export PROFILE_ACQUISITION_SCRIPT="local_profile.sh"

# Script relative to $CI_DIR which will install a given default keychain or restore the
# login keychain.
export KEYCHAIN_SCRIPT="keychain.sh"

# Echo the environment for debugging purposes
if [ $DEBUG -ne 0 ]; then
	echo "Environment:"
	echo "-------------------------"
	printenv
	echo "-------------------------"
fi

## Main

# Get the Xcode project's "marketing version" from the info.plist
# Get only the first version match, and then strip off everything past the first space
cd "$XC_WORKSPACE_DIR"
MARKETING_VERSION=$($AGVTOOL_B mvers -terse1 | $GREP_B -v '\$.*' | $HEAD_B -1 | $SED_B 's|\(^.*\) .*$|\1|')

# Jenkins defines BUILD_NUMBER but if it is not defined, we set it to the version specified by the Xcode project's info.plist
BUILD_NUMBER=${BUILD_NUMBER:-""}
if [ "$BUILD_NUMBER" = "" ]; then
	warn "Using build number from plist instead of Jenkins."
	PLIST=$(xc_config "INFOPLIST_FILE")
	PLIST="$XC_WORKSPACE_DIR/$PLIST"
	BUILD_NUMBER=$($PLISTBUDDY_B -c "Print CFBundleVersion" "$PLIST")
	if [ "$BUILD_NUMBER" = "" ]; then
		BUILD_NUMBER=1
		warn "Could not determine build number. Defaulting to \"$BUILD_NUMBER\""
	fi
	export BUILD_NUMBER_ACTUAL=$BUILD_NUMBER
else
	echo "Jenkins build number: \"$BUILD_NUMBER\""
	export BASE_BUILD_NUMBER=${BASE_BUILD_NUMBER:-0}
	echo "Base build number: \"$BASE_BUILD_NUMBER\""
	export BUILD_NUMBER_ACTUAL=${BUILD_NUMBER_ACTUAL:-$((BASE_BUILD_NUMBER + BUILD_NUMBER))}
fi

# The current build number
echo "Build number: \"$BUILD_NUMBER_ACTUAL\""

# Update version number
echo "Updating version number..."
cd "$XC_WORKSPACE_DIR"
$AGVTOOL_B new-version -all $BUILD_NUMBER_ACTUAL
#Update the marketing version with our clean version
$AGVTOOL_B new-marketing-version "$MARKETING_VERSION"
FULLVERSION="$MARKETING_VERSION ($BUILD_NUMBER_ACTUAL)"
echo "Full version: \"$FULLVERSION\""

# Resulting product name (sans extension)
PRODUCT_BASE_NAME=${PRODUCT_BASE_NAME:-"$XC_PRODUCT_NAME $FULLVERSION $XC_CONFIG"}
# The name of the generated IPA file
IPA_NAME=${IPA_NAME:-"$PRODUCT_BASE_NAME.ipa"}

# Clean up any Xcode Derived Data from past builds
echo "Cleaning up old Xcode Derived Data."
clean_dir "$XC_DD_DIR"

# Clean up any Xcode cache from past builds
echo "Cleaning up Xcode Cache."
# Fetch the CACHE_ROOT from the xcode build configuration directly
CACHE_ROOT=$(xc_config "CACHE_ROOT")
clean_dir "$CACHE_ROOT"

# Clean up existing mobileprovisions in favor of what's in source control
if [ -d "$XC_PROFILE_HOME" ] ; then
	cd "$XC_PROFILE_HOME"
	echo "Cleaning up old provisioning profile(s)."
	$RM_B -f *.mobileprovision
else
	$MKDIR_B -p "$XC_PROFILE_HOME"
fi

# Setup a clean output directory
clean_dir "$OUTPUT_DIR"

# Acquire the profile
echo "Acquiring provisioning profile \"$XC_PROFILE_NAME\""
cd "$XC_PROFILE_HOME"
PROFILE_FILE=`. "$CI_DIR/$PROFILE_ACQUISITION_SCRIPT" "$XC_PROFILE_TYPE" "$XC_PROFILE_NAME"`
if [ -f "$PROFILE_FILE" ]; then
	echo "Successfully acquired provisioning profile file: \"$PROFILE_FILE\""
else
	fail "Expected provisioning profile not found: \"$PROFILE_FILE\""
fi

# Install the keychain
# Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
if [ "$BUILD_KEYCHAIN" = "" -o "$BUILD_KEYCHAIN_PASS" = "" ]; then
	warn "No build keychain and/or no build keychain password specified."
else
	echo "Installing build keychain \"$BUILD_KEYCHAIN\""
	export KEYCHAIN_PASS="$BUILD_KEYCHAIN_PASS"
	[ $DEBUG -ne 0 ] && set -x
	`. "$CI_DIR/$KEYCHAIN_SCRIPT" install "$WORKSPACE/$BUILD_KEYCHAIN"`
fi
[ $DEBUG -ne 0 ] && set -x

## Test
if [ $EXECUTE_TESTS -ne 0 ]; then
	# Check to see if we have xcpretty available to format our test output
	# If so, we do a clean build, then test, with test result TAP formatted output to "$OUTPUT_DIR/test_results.tap" (re. TAP: see http://testanything.org )
	if [ -x "$XCPRETTY_B" ]; then
		cd "$XC_WORKSPACE_DIR"
		# Clean-build and execute the tests
		echo "Testing..."
		set -o pipefail && $XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" -sdk "iphonesimulator" clean test | xcpretty --no-utf --report junit --output "$OUTPUT_DIR/junit.xml"
	else
		# xcpretty is not available to format our test output
		warn "xcpretty is not available on the current PATH. No tests will be performed. Please install xcpretty https://github.com/supermarin/xcpretty"
	fi
else
	echo "Tests disabled."
fi

## Analyze
if [ $EXECUTE_STATIC_ANALIZER -ne 0 ]; then
 	echo "TODO: Performing static analysis..."
 	# TODO: Analyze and output the results to Jenkins
	# See: http://blog.manbolo.com/2014/04/15/automated-static-code-analysis-with-xcode-5.1-and-jenkins
else
 	echo "Static analysis disabled."
fi

## Archive
if [ $EXECUTE_ARCHIVE -ne 0 ]; then
	echo "Creating Archive..."
	XC_ARCHIVE_PATH="$OUTPUT_DIR/$XC_PRODUCT_NAME.xcarchive"
	cd "$XC_WORKSPACE_DIR"
	if [ -x "$XCPRETTY_B" ]; then
		# Clean-archive piped through xcpretty
		set -o pipefail && $XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" clean archive -archivePath "$XC_ARCHIVE_PATH" | xcpretty --no-utf
	else
		# xcpretty is not available to format our output
		echo "INFO: xcpretty is not available on the current PATH. Building without it. Please install xcpretty https://github.com/supermarin/xcpretty"
		$XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" clean archive -archivePath "$XC_ARCHIVE_PATH"
	fi

	# Export the archive
	EXPORT_PATH="$OUTPUT_DIR/$IPA_NAME"
	echo "Exporting archive to \"$EXPORT_PATH\""
	$XCODEBUILD_B -exportArchive -exportFormat "IPA" -archivePath "$XC_ARCHIVE_PATH" -exportPath "$EXPORT_PATH" -exportProvisioningProfile "$XC_PROFILE_NAME"

	# Zip up the dSYM file
# Not needed at this time (crashlytics gets the dSYM itself).
# 	DYSM_NAME=$(xc_config "DWARF_DSYM_FILE_NAME")
# 	DSYM="$XC_ARCHIVE_PATH/dSYMs/$DYSM_NAME"
# 	DSYM_ZIP="$OUTPUT_DIR/$DYSM_NAME.zip"
# 	echo "Zipping dSYM \"$DSYM\" to \"$DSYM_ZIP\"..."
# 	$ZIP_B -r -y "$DSYM_ZIP" "$DSYM"
# 	echo "dSYM file ready for upload"

	# Post Archive

	# Fetch the release notes from source control
	echo "Fetching release notes from source control..."
	LAST_SUCCESS_REV=${LAST_SUCCESS_REV:-$("$CI_DIR/$LAST_SUCCESS_REV_SCRIPT" "$JOB_URL")}
	[ "$LAST_SUCCESS_REV" = "" ] && warn "Could not determine last successful build revision." || echo "Last build success revision: $LAST_SUCCESS_REV"
	[ "$LAST_SUCCESS_REV" = "" ] && RELEASE_NOTES=$($GIT_B show -s --format="$GIT_LOG_FORMAT" | $TAIL_B -r) || RELEASE_NOTES=$("$CI_DIR/$GIT_HISTORY_SCRIPT" "$LAST_SUCCESS_REV")
	[ "$RELEASE_NOTES" = "" ] && RELEASE_NOTES="(no release notes)"
	echo "Release Notes:"
	echo "$RELEASE_NOTES"
	# Write release notes to OUTPUT_DIR
	echo "$RELEASE_NOTES" > "$OUTPUT_DIR/release_notes.txt"

	# Upload to TestFlight
	if [ $TF_UPLOAD -ne 0 ]; then
		echo "Distributing to TestFlight list(s): $TF_DIST_LIST"
		. "$CI_DIR/$TEST_FLIGHT_UPLOAD_SCRIPT" "$EXPORT_PATH" "$DSYM_ZIP" "$RELEASE_NOTES" "$TF_DIST_LIST"
	fi

	# Upload to Crashlytics
	if [ $CL_UPLOAD -ne 0 ]; then
		echo "Submitting IPA to Crashlytics"
		. "$CI_DIR/$CRASHLYTICS_UPLOAD_SCRIPT" "$EXPORT_PATH" "$RELEASE_NOTES"
	fi
else
	echo "Archive disabled."
fi

echo "Build finished"
