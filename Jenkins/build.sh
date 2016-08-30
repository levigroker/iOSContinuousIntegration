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
# "ARCHIVE_BASE_URL" The base HTTPS URL which will be used to provide a link to the manifest and executable.
# "ARCHIVE_WEB_ROOT_DIR" The full path to the webroot directory to populate with build artifacts.
#
# A Post-Build action for the Jenkins job could be added with the JUnit plugin to display
# test results (see https://wiki.jenkins-ci.org/display/JENKINS/JUnit+Plugin )
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
    echo "warning: $@" >&2
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
	echo "$XC_BUILD_SETTINGS" | $GREP_B " $1 = " | uniq | $SED_B "s|.* $1 = ||"
	set -x
}

# See http://stackoverflow.com/a/10797966/397210
function urlencode()
{
    local data
    if [[ $# != 1 ]]; then
        echo "Usage: $0 string-to-urlencode" >&2
        return 1
    fi
    data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$1" "")"
    if [[ $? != 3 ]]; then
        echo "Unexpected error" >&2
        return 2
    fi
    echo "${data##/?}"
    return 0
}

function post_slack_build_status()
{
	if [ $SLACK_BUILD_STATUS_POST -ne 0 ]; then
		if [ "$BUILD_URL" = "" ]; then
			warn "No 'BUILD_URL' available. Can not include in Slack post."
			SLACK_BUILD="${JOB_NAME} #${BUILD_NUMBER}:"
		else
			SLACK_BUILD="<${BUILD_URL}|${JOB_NAME} #${BUILD_NUMBER}>:"
		fi

		export SLACK_TEXT="${SLACK_BUILD} ${1}"

		echo "Posting build status to Slack"
		. "$CI_DIR/$SLACK_POST_SCRIPT" -c "$SLACK_CHANNEL" -i "$SLACK_BUILD_STATUS_ICON" -n "$SLACK_USERNAME" "$SLACK_TEXT" "$SLACK_WEBHOOK_URL"
	fi
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
export AWK_B="/usr/bin/awk"
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
export PLISTBUDDY_B="/usr/libexec/Plistbuddy -c"
export LN_B="/bin/ln -s"
XCPRETTY_B="/usr/local/bin/xcpretty"
if [ ! -x "$XCPRETTY_B" ]; then
	XCPRETTY_B=$($WHICH_B xcpretty)
fi
export XCPRETTY_B

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
# Jenkins defines JOB_NAME but if it is not defined, we set it (blank, but the env variable is set)
JOB_NAME=${JOB_NAME:-""}
# Jenkins defines BUILD_NUMBER but if it is not defined, we set it (blank, but the env variable is set)
BUILD_NUMBER=${BUILD_NUMBER:-""}
# Jenkins defines BUILD_URL but if it is not defined, we set it (blank, but the env variable is set)
BUILD_URL=${BUILD_URL:-""}

## Paths

# The directory Jenkins will place archived artifacts
ARCHIVE_HOME="$JENKINS_HOME/jobs/$JOB_NAME/builds/$BUILD_NUMBER/archive"
# Jenkins defines "WORKSPACE" but if it is not defined, we populate it from the root of the git repository
export WORKSPACE=${WORKSPACE:-$(git rev-parse --show-toplevel)}
echo "Workspace directory: \"$WORKSPACE\""
# The path containing this script and related scripts for Continuous Integration
export CI_DIR=${CI_DIR:-"$WORKSPACE/CI"}
echo "CI directory: \"$CI_DIR\""
# The directory under WORKSPACE containing the Xcode xxx.workspace file which we will build.
export XC_WORKSPACE_DIR=${XC_WORKSPACE_DIR:-""}
if [ "$XC_WORKSPACE_DIR" = "" ]; then
	fail "XC_WORKSPACE_DIR not specified. Please export XC_WORKSPACE_DIR as the directory containing your xcworkspace."
fi
export XC_WORKSPACE_DIR_NAME="$XC_WORKSPACE_DIR"
XC_WORKSPACE_DIR="$WORKSPACE/$XC_WORKSPACE_DIR"
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
# The name of the produced product, with no suffix (e.g. "My App"). This will be used as part of the archive name.
export XC_PRODUCT_NAME=${XC_PRODUCT_NAME:-$(xc_config "PRODUCT_NAME")}
export XC_TARGET_NAME=${XC_TARGET_NAME:-$(xc_config "TARGET_NAME")}
# The current info.plist for this project, relative to $XC_WORKSPACE_DIR
export XC_PLIST_FILE=$(xc_config "INFOPLIST_FILE")

# Build and test output directory
export OUTPUT_DIR_NAME="output"
export OUTPUT_DIR="$XC_WORKSPACE_DIR/$OUTPUT_DIR_NAME"
# The export options plist file. This is the plist file to be passed to xcodebuild's -exportOptionsPlist flag.
export XC_EXPORT_OPTIONS_PLIST=${XC_EXPORT_OPTIONS_PLIST:-""}
if [ "$XC_EXPORT_OPTIONS_PLIST" = "" ]; then
	fail "XC_EXPORT_OPTIONS_PLIST not specified. Please export XC_EXPORT_OPTIONS_PLIST as the plist file to be passed to xcodebuild's -exportOptionsPlist flag."
fi
echo "Export options plist: \"$XC_EXPORT_OPTIONS_PLIST\""

## Configuration

# Should tests be built and executed?
export EXECUTE_TESTS=${EXECUTE_TESTS:-1}
# Should static analysis be performed?
export EXECUTE_STATIC_ANALIZER=${EXECUTE_STATIC_ANALIZER:-1}
# Should Deploymate analysis be performed?
export EXECUTE_DEPLOYMATE=${EXECUTE_DEPLOYMATE:-1}
# Should the archive be generated?
export EXECUTE_ARCHIVE=${EXECUTE_ARCHIVE:-1}
# Should components supporting "over-air" install of iOS app be built and linked to the web?
export EXECUTE_IOS_INSTALL=${EXECUTE_IOS_INSTALL:-0}
# You can enable uploading the build to Crashlytics by specifying CL_UPLOAD=1
export CL_UPLOAD=${CL_UPLOAD:-0}
#TBD
export TF_UPLOAD=${TF_UPLOAD:-0}
# You can enable posting archived builds to Slack by specifying SLACK_ARCHIVE_POST=1
export SLACK_ARCHIVE_POST=${SLACK_ARCHIVE_POST:-0}
# You can enable posting build staus updates to Slack by specifying SLACK_BUILD_STATUS_POST=1
export SLACK_BUILD_STATUS_POST=${SLACK_BUILD_STATUS_POST:-0}

DEFAULT_EXECUTABLE_EXTENSION=""

# Platform Specific Switch
XC_PLATFORM_NAME=$(xc_config "PLATFORM_NAME")
if [ "$XC_PLATFORM_NAME" = "macosx" ]; then
# macOS

	# See `XC_TEST_DESTINATIONS` below
	DEFAULT_TEST_DESTINATIONS=("-destination" "platform=OS X")

	DEFAULT_EXECUTABLE_EXTENSION="app"
	
	if [ $CL_UPLOAD -ne 0 ]; then
		warn "No Crashlytics uploads possible for macOS"
		CL_UPLOAD=0
	fi
	
# end macOS
elif [ "$XC_PLATFORM_NAME" = "iphoneos" ]; then
# iOS

	# See `XC_TEST_DESTINATIONS` below
	DEFAULT_TEST_DESTINATIONS=("-destination" "platform=iOS Simulator,name=iPhone 6s" "-destination" "platform=iOS Simulator,name=iPad Retina")

	DEFAULT_EXECUTABLE_EXTENSION="ipa"
	
# end iOS
else
	warn "Unhandled platform \"$XC_PLATFORM_NAME\""
fi

# The "destinations" to execute tests on. See the `xcodebuild` man page for details on
# possible destinations.
# See `DEFAULT_TEST_DESTINATIONS`
# NOTE: `XC_TEST_DESTINATIONS` is an array
export XC_TEST_DESTINATIONS=("${XC_TEST_DESTINATIONS[@]:-${DEFAULT_TEST_DESTINATIONS[@]}}")

# Build Number Method
# This can be either "git", "jenkins", or "plist"
# If "git" then `git rev-list HEAD --count` will be used to get the number of commits in
# the current branch and use that, in conjunction with `BASE_BUILD_NUMBER` to obtain the
# actual build number.
# If "jenkins" then the `BUILD_NUMBER` environment variable exported by Jenkins will be
# used to get the number of commits in the current branch and use that, in conjunction
# with `BASE_BUILD_NUMBER` to obtain the actual build number.
# If "plist" then the build number defined in the info.plist will be used without
# modification.
export BUILD_NUMBER_METHOD=${BUILD_NUMBER_METHOD:-"git"}
export BASE_BUILD_NUMBER=${BASE_BUILD_NUMBER:-0}

# Crashlytics Beta distribution lists
export CL_DIST_LIST=${CL_DIST_LIST:-""}
# Prevent sensitive info from going to the console in debug mode.
[ $DEBUG -ne 0 ] && set +x
# Crashlytics upload configuration
export CL_API_KEY=${CL_API_KEY:-""}
export CL_BUILD_SECRET=${CL_BUILD_SECRET:-""}
[ $DEBUG -ne 0 ] && set -x


# Slack
export SLACK_CHANNEL=${SLACK_CHANNEL:-"#general"}
export SLACK_USERNAME=${SLACK_USERNAME:-"buildbot"}
export SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}
export SLACK_ARCHIVE_ICON=${SLACK_ARCHIVE_ICON:-":package:"}
export SLACK_BUILD_STATUS_ICON=${SLACK_BUILD_STATUS_ICON:-":warning:"}

if [ $SLACK_ARCHIVE_POST -ne 0 || $SLACK_BUILD_STATUS_POST -ne 0 ]; then
	if [ "$SLACK_CHANNEL" = "" ]; then
		warn "No 'SLACK_CHANNEL' specified. Posting to Slack will not occur."
		SLACK_ARCHIVE_POST=0
		SLACK_BUILD_STATUS_POST=0
	fi
	if [ "$SLACK_USERNAME" = "" ]; then
		warn "No 'SLACK_USERNAME' specified. Posting to Slack will not occur."
		SLACK_ARCHIVE_POST=0
		SLACK_BUILD_STATUS_POST=0
	fi
	if [ "$SLACK_WEBHOOK_URL" = "" ]; then
		warn "No 'SLACK_WEBHOOK_URL' specified. Posting to Slack will not occur."
		SLACK_ARCHIVE_POST=0
		SLACK_BUILD_STATUS_POST=0
	fi
fi

# Deploymate
export DM_UNAVAILABLE_THRESHOLD=${DM_UNAVAILABLE_THRESHOLD:-1}
export DM_DEPRECATED_THRESHOLD=${DM_DEPRECATED_THRESHOLD:-1}

# Keychain support
# NOTE: this script will NOT restore the default login keychain. You should add a
# post-build step to Jenkins to call `keychain.sh restore` even if the build fails.
#
# The keychain file, relative to WORKSPACE, to install for the build
export BUILD_KEYCHAIN=${BUILD_KEYCHAIN:-""}
# The password for the specified keychain
export BUILD_KEYCHAIN_PASS=${BUILD_KEYCHAIN_PASS:-""}

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
# Script relative to $CI_DIR which will optionally execute the Deploymate analytics tool.
export DEPLOYMATE_SCRIPT="deploymate.sh"
# Script relative to $CI_DIR which will handle posting to Slack
export SLACK_POST_SCRIPT="slack.sh"
# Script relative to $CI_DIR which will handle generation of iOS installation landing HTML
export INSTALLATION_HTML_SCRIPT="install_html.sh"

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
# Looks for the version of the current info.plist
cd "$XC_WORKSPACE_DIR"
MARKETING_VERSION=$($AGVTOOL_B mvers -terse | $GREP_B "$XC_PLIST_FILE" | $HEAD_B -1 | $SED_B 's|.*=\(.*\)$|\1|')

case $BUILD_NUMBER_METHOD in
    git)
		echo "Using \"$BUILD_NUMBER_METHOD\" build number method."
		WORKING_BUILD_NUMBER=$($GIT_B rev-list HEAD --count)
		if [ "$WORKING_BUILD_NUMBER" != "" ]; then
			echo "git build number: \"$WORKING_BUILD_NUMBER\""
			echo "Base build number: \"$BASE_BUILD_NUMBER\""
			export BUILD_NUMBER_ACTUAL=${BUILD_NUMBER_ACTUAL:-$((BASE_BUILD_NUMBER + WORKING_BUILD_NUMBER))}
		else
			warn "Could not determine Jenkins build number."
		fi
    ;;
    jenkins)
		echo "Using \"$BUILD_NUMBER_METHOD\" build number method."
		if [ "$BUILD_NUMBER" != "" ]; then
			echo "Jenkins build number: \"$BUILD_NUMBER\""
			echo "Base build number: \"$BASE_BUILD_NUMBER\""
			export BUILD_NUMBER_ACTUAL=${BUILD_NUMBER_ACTUAL:-$((BASE_BUILD_NUMBER + BUILD_NUMBER))}
		else
			warn "Could not determine Jenkins build number."
		fi
    ;;
    plist)
		echo "Using \"$BUILD_NUMBER_METHOD\" build number method."
		PLIST="$XC_WORKSPACE_DIR/$XC_PLIST_FILE"
		WORKING_BUILD_NUMBER=$($PLISTBUDDY_B "Print CFBundleVersion" "$PLIST")
		if [ "$WORKING_BUILD_NUMBER" != "" ]; then
			echo "info.plist build number: \"$WORKING_BUILD_NUMBER\""
			export BUILD_NUMBER_ACTUAL=$WORKING_BUILD_NUMBER
		else
			warn "Could not determine info.plist build number."
		fi
    ;;
    *)
    # Unknown option
    fail "Unknown build number method \"$BUILD_NUMBER_METHOD\""
    ;;
esac

if [ "$WORKING_BUILD_NUMBER" = "" ]; then
	WORKING_BUILD_NUMBER=1
	warn "Could not determine build number. Defaulting to \"$WORKING_BUILD_NUMBER\""
fi
export BUILD_NUMBER_ACTUAL=${BUILD_NUMBER_ACTUAL:-"$WORKING_BUILD_NUMBER"}
# The current build number
echo "Build number: \"$BUILD_NUMBER_ACTUAL\""

if [ "$BUILD_NUMBER" = "" ]; then
	BUILD_NUMBER=1
	warn "Could not determine Jenkins build number. Defaulting to \"$BUILD_NUMBER\""
fi

# Update version number
echo "Updating version number..."
cd "$XC_WORKSPACE_DIR"
$AGVTOOL_B new-version -all $BUILD_NUMBER_ACTUAL
#Update the marketing version with our clean version
$AGVTOOL_B new-marketing-version "$MARKETING_VERSION"
FULLVERSION="$MARKETING_VERSION ($BUILD_NUMBER_ACTUAL)"
echo "Full version: \"$FULLVERSION\""

# The resulting base name of the generated archive file (sans `.xcarchive` extension)
ARCHIVE_NAME=${ARCHIVE_NAME:-"$XC_PRODUCT_NAME $FULLVERSION $XC_CONFIG"}

# The name of the exported archive executable file
EXECUTABLE_EXTENSION=${EXECUTABLE_EXTENSION:-"$DEFAULT_EXECUTABLE_EXTENSION"}
EXECUTABLE_NAME=${EXECUTABLE_NAME:-"$XC_TARGET_NAME.$EXECUTABLE_EXTENSION"}

# Clean up any Xcode Derived Data from past builds
echo "Cleaning up old Xcode Derived Data."
clean_dir "$XC_DD_DIR"

# Clean up any Xcode cache from past builds
echo "Cleaning up Xcode Cache."
# Fetch the CACHE_ROOT from the xcode build configuration directly
CACHE_ROOT=$(xc_config "CACHE_ROOT")
clean_dir "$CACHE_ROOT"

# Clean up existing provisioning profiles in favor of what's in source control
if [ -d "$XC_PROFILE_HOME" ] ; then
	cd "$XC_PROFILE_HOME"
	echo "Cleaning up old provisioning profile(s)."
	$RM_B -f *.mobileprovision
	$RM_B -f *.provisionprofile
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
TESTS_PASSING=1
if [ $EXECUTE_TESTS -ne 0 ]; then
	# Check to see if we have xcpretty available to format our test output
	# If so, we do a clean build, then test, with test result JUnit formatted output to "$OUTPUT_DIR/junit.xml"
	# (re. JUnit: see https://wiki.jenkins-ci.org/display/JENKINS/JUnit+Plugin )
	# (re. TAP: see http://testanything.org )
	if [ -x "$XCPRETTY_B" ]; then
		cd "$XC_WORKSPACE_DIR"
		# Clean-build and execute the tests
		echo "Testing..."
		# We don't let -e fail the script if the test fails, we want to handle it ourselves
		set +e
		set -o pipefail && $XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" "${XC_TEST_DESTINATIONS[@]}" clean test | "$XCPRETTY_B" --no-utf --report junit --output "$OUTPUT_DIR/junit.xml"
		if [ $? -ne 0 ]; then
			TESTS_PASSING=0
		fi
		set -e
	else
		# xcpretty is not available to format our test output
		warn "xcpretty is not available on the current PATH. No tests will be performed. Please install xcpretty https://github.com/supermarin/xcpretty"
	fi
else
	echo "Tests disabled."
fi

if [ $TESTS_PASSING -ne 1 ]; then
	warn "One or more tests failed. Skipping remaining build steps!"
	post_slack_build_status "One or more tests failed."
else
	## Static Analyzer
	if [ $EXECUTE_STATIC_ANALIZER -ne 0 ]; then
		echo "TODO: Performing static analysis..."
		# TODO: Analyze and output the results to Jenkins
		# See: http://blog.manbolo.com/2014/04/15/automated-static-code-analysis-with-xcode-5.1-and-jenkins
	else
		echo "Static analysis disabled."
	fi

	## Deploymate Analyzer
	if [ $EXECUTE_DEPLOYMATE -ne 0 ]; then
		echo "Performing Deploymate analysis..."
		set +e
			. "$CI_DIR/$DEPLOYMATE_SCRIPT" -u $DM_UNAVAILABLE_THRESHOLD -d $DM_DEPRECATED_THRESHOLD
		set -e
		if [ $? -ne 0 ]; then
			post_slack_build_status "Deploymate analysis failed."
			fail "Deploymate analysis failed."
		fi
	else
		echo "Deploymate analysis disabled."
	fi

	## Archive
	if [ $EXECUTE_ARCHIVE -ne 0 ]; then
		echo "Creating Archive..."
		XC_ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME.xcarchive"
		cd "$XC_WORKSPACE_DIR"
		if [ -x "$XCPRETTY_B" -a $DEBUG -eq 0 ]; then
			# Clean-archive piped through xcpretty
			set +e
				set -o pipefail && $XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" clean archive -archivePath "$XC_ARCHIVE_PATH" | "$XCPRETTY_B" --no-utf
			set -e
			if [ $? -ne 0 ]; then
				post_slack_build_status "Build archive failed."
				fail "Build archive failed."
			fi
		else
			# xcpretty is not available to format our output or we aren't using it because DEBUG == 1
			if [ $DEBUG -eq 0 ]; then
				echo "INFO: xcpretty is not available on the current PATH. Building without it. Please install xcpretty https://github.com/supermarin/xcpretty"
			fi
			set +e
				$XCODEBUILD_B -workspace "$XC_WORKSPACE" -scheme "$XC_SCHEME" -configuration "$XC_CONFIG" clean archive -archivePath "$XC_ARCHIVE_PATH"
			set -e
			if [ $? -ne 0 ]; then
				post_slack_build_status "Build archive failed."
				fail "Build archive failed."
			fi
		fi
	
		EXPORT_DIR_NAME="$ARCHIVE_NAME"
		EXPORT_PATH="$OUTPUT_DIR/$EXPORT_DIR_NAME"
		MANIFEST_NAME="manifest.plist"
		INSTALLATION_HTML_FILE_NAME="install.html"

		# If we are building for iOS and we want to generate the install components then
		# modify the export options plist with the `appURL` which will point to the exported
		# ipa executable file.
		if [ "$XC_PLATFORM_NAME" = "iphoneos" ]; then
			if [ $EXECUTE_IOS_INSTALL -ne 0 ]; then
				# If we are supplied with a base URL for exposing the archive then modify the export
				# options plist to include the URL to the executable
				ARCHIVE_BASE_URL=${ARCHIVE_BASE_URL:-""}
				# The ARCHIVE_BASE_URL gets us to the webroot for archives, but we need the URL to the
				# root for this job's archive, so we will create it, assuming we have an ARCHIVE_BASE_URL
				# The ARCHIVE_ROOT_URL and ARCHIVE_WEB_PATH need to match up...
				ARCHIVE_ROOT_URL=""
				if [ "$ARCHIVE_BASE_URL" = "" ]; then
					warn "No 'ARCHIVE_BASE_URL' set. Can not generate manifest with URL to executable."
				else
					# Add the "appURL" to the export options plist manifest
					# See `xcodebuild -help` for details
					# See `ARCHIVE_WEB_PATH` below
					ARCHIVE_ROOT_URL="$ARCHIVE_BASE_URL"'/'$(urlencode "$JOB_NAME")'/'"$BUILD_NUMBER"'/'$(urlencode "$EXPORT_DIR_NAME")
					EXECUTABLE_URL="$ARCHIVE_ROOT_URL"'/'$(urlencode "$EXECUTABLE_NAME")
					set +e
					# `manifest:appURL` may not exist, hence the `set +e` and `set -e` wrapper, but if it
					# does we must delete it before attempting to Add it.
					$PLISTBUDDY_B "Delete manifest:appURL" "$WORKSPACE/$XC_EXPORT_OPTIONS_PLIST"
					set -e
					$PLISTBUDDY_B "Add manifest:appURL string $EXECUTABLE_URL" "$WORKSPACE/$XC_EXPORT_OPTIONS_PLIST"
				fi
			else
				echo "iOS Install disabled"
			fi
		fi

		# Export the archive
		echo "Exporting archive to \"$EXPORT_PATH\""
		set +e
			$XCODEBUILD_B -exportArchive -archivePath "$XC_ARCHIVE_PATH" -exportPath "$EXPORT_PATH" -exportOptionsPlist "$WORKSPACE/$XC_EXPORT_OPTIONS_PLIST"
		set -e
		if [ $? -ne 0 ]; then
			post_slack_build_status "Export archive failed."
			fail "Export archive failed."
		fi

		# If we are building for iOS and we want to generate the install components then
		# create the HTML landing page with installation link, and symbolically link the
		# artifact files to the web-root so they are available to the HTTP server.
		if [ "$XC_PLATFORM_NAME" = "iphoneos" ]; then
			if [ $EXECUTE_IOS_INSTALL -ne 0 ]; then
				ARCHIVE_WEB_ROOT_DIR=${ARCHIVE_WEB_ROOT_DIR:-""}
				if [ "$ARCHIVE_WEB_ROOT_DIR" = "" ]; then
					warn "No 'ARCHIVE_WEB_ROOT_DIR' set. Can not link executable into webserver root."
				elif [ "$ARCHIVE_ROOT_URL" = "" ]; then
					warn "No 'ARCHIVE_ROOT_URL' set. Can not generate install link."
				else
					# Create symbolic links from the archived locations of the executable, generated
					# manifest, and install.html to the ARCHIVE_WEB_ROOT_DIR to make them accessible
					# via an HTTP server.
					# See `EXECUTABLE_URL` above
		
					ARCHIVE_PATH="$ARCHIVE_HOME/$XC_WORKSPACE_DIR_NAME/$OUTPUT_DIR_NAME/$EXPORT_DIR_NAME"
		
					ARCHIVE_WEB_PATH="$ARCHIVE_WEB_ROOT_DIR/$JOB_NAME/$BUILD_NUMBER/$EXPORT_DIR_NAME"
					$MKDIR_B -p "$ARCHIVE_WEB_PATH"
					$LN_B "$ARCHIVE_PATH/$EXECUTABLE_NAME" "$ARCHIVE_WEB_PATH/$EXECUTABLE_NAME"
					$LN_B "$ARCHIVE_PATH/$MANIFEST_NAME" "$ARCHIVE_WEB_PATH/$MANIFEST_NAME"

					# Create the installation html file and installation link
					APP_ICON_URL=$($PLISTBUDDY_B "Print manifest:fullSizeImageURL" "$WORKSPACE/$XC_EXPORT_OPTIONS_PLIST")
					MANIFEST_URL="$ARCHIVE_ROOT_URL"'/'$(urlencode "$MANIFEST_NAME")
					MANIFEST_URL_ENC=$(urlencode "$MANIFEST_URL")
					INSTALL_URL='itms-services://?action=download-manifest&url='"$MANIFEST_URL_ENC"
					INSTALL_HTML=$("$CI_DIR/$INSTALLATION_HTML_SCRIPT" "$ARCHIVE_NAME" "$INSTALL_URL" "$APP_ICON_URL")
					if [ $? -ne 1 ]; then
						echo "$INSTALL_HTML" > "$EXPORT_PATH/$INSTALLATION_HTML_FILE_NAME"
						$LN_B "$ARCHIVE_PATH/$INSTALLATION_HTML_FILE_NAME" "$ARCHIVE_WEB_PATH/$INSTALLATION_HTML_FILE_NAME"
					else
						warn "Failed to create \"$INSTALLATION_HTML_FILE_NAME\"."
					fi
				fi
			fi
		fi
	
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
		RELEASE_NOTES_FILE_NAME="release_notes.txt"
		echo "$RELEASE_NOTES" > "$OUTPUT_DIR/$RELEASE_NOTES_FILE_NAME"

		# Upload to TestFlight
		if [ $TF_UPLOAD -ne 0 ]; then
			echo "Distributing to TestFlight list(s): $TF_DIST_LIST"
			. "$CI_DIR/$TEST_FLIGHT_UPLOAD_SCRIPT" "$EXPORT_PATH/$EXECUTABLE_NAME" "$DSYM_ZIP" "$RELEASE_NOTES" "$TF_DIST_LIST"
		fi

		# Upload to Crashlytics
		if [ $CL_UPLOAD -ne 0 ]; then
			echo "Submitting archive to Crashlytics"
			. "$CI_DIR/$CRASHLYTICS_UPLOAD_SCRIPT" "$EXPORT_PATH/$EXECUTABLE_NAME" "$RELEASE_NOTES"
		else
			echo "Crashlytics Upload disabled."
		fi

		# Post to Slack
		if [ $SLACK_ARCHIVE_POST -ne 0 ]; then
			if [ "$XC_PLATFORM_NAME" = "macosx" ]; then
				SLACK_OS_NAME="macos"
				if [ "$BUILD_URL" = "" ]; then
					warn "No 'BUILD_URL' available (not executing from Jenkins?)."
				else
					ARTIFACT_URL="$BUILD_URL"'artifact/'$(urlencode "$XC_WORKSPACE_DIR_NAME")'/'$(urlencode "$OUTPUT_DIR_NAME")'/'$(urlencode "$EXPORT_DIR_NAME")'/*zip*/'$(urlencode "$ARCHIVE_NAME".zip)
				fi
			elif [ "$XC_PLATFORM_NAME" = "iphoneos" ]; then
				SLACK_OS_NAME="ios"
				if [ $EXECUTE_IOS_INSTALL -ne 0 ]; then
					if [ "$ARCHIVE_ROOT_URL" = "" ]; then
						warn "No 'ARCHIVE_ROOT_URL' set. Can not generate install link."
					else
						ARTIFACT_URL="$ARCHIVE_ROOT_URL"'/'$(urlencode "$INSTALLATION_HTML_FILE_NAME")
					fi
				fi
			else
				warn "Unhandled platform \"$XC_PLATFORM_NAME\". Posting to Slack will not occur."
				SLACK_ARCHIVE_POST=0
			fi
		
			if [ $SLACK_ARCHIVE_POST -ne 0 ]; then

				ARTIFACT_URL=${ARTIFACT_URL:-""}
				if [ "$ARTIFACT_URL" = "" ]; then
					SLACK_ARTIFACT="$ARCHIVE_NAME"
				else
					SLACK_ARTIFACT='<'"$ARTIFACT_URL"'|'"$ARCHIVE_NAME"'>'
				fi

				# Release Notes
				# If we can link to the release notes, we'll do that, otherwise we will include them inline.
				if [ "$BUILD_URL" = "" ]; then
					warn "No 'BUILD_URL' available. Can not create link to Release Notes. Inlining release notes."
					RELEASE_NOTES_ESC=$($AWK_B 1 ORS='\\n' < "$OUTPUT_DIR/$RELEASE_NOTES_FILE_NAME")
					SLACK_RELEASE_NOTES='Release notes:\n'"$RELEASE_NOTES_ESC"
				else
					RELEASE_NOTES_URL="$BUILD_URL"'artifact/'$(urlencode "$XC_WORKSPACE_DIR_NAME")'/'$(urlencode "$OUTPUT_DIR_NAME")'/'$(urlencode "$RELEASE_NOTES_FILE_NAME")
					SLACK_RELEASE_NOTES='<'"$RELEASE_NOTES_URL"'|Release notes>.'
				fi

				export SLACK_TEXT='['"$SLACK_OS_NAME"'] '"$SLACK_ARTIFACT"' is now available. '"$SLACK_RELEASE_NOTES"

				echo "Posting archive to Slack"
				. "$CI_DIR/$SLACK_POST_SCRIPT" -c "$SLACK_CHANNEL" -i "$SLACK_ARCHIVE_ICON" -n "$SLACK_USERNAME" "$SLACK_TEXT" "$SLACK_WEBHOOK_URL"
			fi
		else
			echo "Slack Archive Post disabled."
		fi
	
	else
		echo "Archive disabled."
	fi

	echo "Build finished"

fi #Tests Passing