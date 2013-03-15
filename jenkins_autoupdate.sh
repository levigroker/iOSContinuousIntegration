#!/bin/bash -e
#
# jenkins_autoupdate.sh
# A script to automatically update the Jenkins web application if a new version is
# available. The intention is for this script to be executed periodically as a Jenkins
# Job.
#
# Upon execution, the script will query the Jenkins instance specified by JENKINS_URL
# for version information, then query the Jenkins Update Center for the most recent
# Jenkins version information. Should these two versions not match, the Update Center
# will be queried for the download URL of the updated jenkins.war. The WAR will be
# downloaded and moved into the WAR_DEPLOY_PATH which should autodeploy Jenkins.
#
# Levi Brown
# mailto:levigroker@gmail.com
# Created March 15, 2013
# https://github.com/levigroker/iOSContinuousIntegration
##

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
# The path to deploy the jenkins.war file
WAR_DEPLOY_PATH=${WAR_DEPLOY_PATH:-""}
# The URL to check for current Jenkins version
UPDATE_CENTER_URL="http://updates.jenkins-ci.org/update-center.json"
# Get the Jenkins URL from the Jenkins Job environment
JENKINS_URL=${JENKINS_URL:-""}
# Append 'login' to the URL since that will be accessible even if login is required
[ "$JENKINS_URL" != "" ] && JENKINS_URL+="login"
echo "JENKINS_URL \"$JENKINS_URL\""

[ "$WAR_DEPLOY_PATH" -eq "" ] && fail "WAR_DEPLOY_PATH not specified. Please export WAR_DEPLOY_PATH as the path where the jenkins.war should be deployed."
[ "$JENKINS_URL" -eq "" ] && fail "JENKINS_URL not specified. Please export JENKINS_URL as the URL to the target Jenkins install. NOTE: JENKINS_URL is set automatically if this script is exectuted as a Jenkins Job."

# Fully qualified binaries
CURL="/usr/bin/curl"
AWK="/usr/bin/awk"
SED="/usr/bin/sed"
GREP="/usr/bin/grep"
TR="/usr/bin/tr"
PYTHON="/usr/bin/python"

# Get the current Jenkins version from the 'X-Jenkins' HTTP header
JENKINS_VERSION=`$CURL -f -s --head $JENKINS_URL | $GREP "X-Jenkins:" | $TR -d '\r' | $SED 's|.*X-Jenkins:[ \t]*\([.0-9]*\)|\1|g'`
[ $DEBUG -ne 0 ] && echo "JENKINS_VERSION: \"$JENKINS_VERSION\""
[ "$JENKINS_VERSION" -eq "" ] && fail "Could not determine local Jenkins version."

# Determine the most recent version
JSON=`curl -sL $UPDATE_CENTER_URL`
JSON=`echo "$JSON" | grep "\"connectionCheckUrl\":"`
NEW_VERSION=`echo "$JSON" | $PYTHON -c 'import json,sys;obj=json.load(sys.stdin);print obj["core"]["version"]'`
[ $DEBUG -ne 0 ] && echo "NEW_VERSION: \"$NEW_VERSION\""
[ "$NEW_VERSION" -eq "" ] && fail "Could not determine current available Jenkins version."

if [ "$JENKINS_VERSION" -ne "$NEW_VERSION" ]; then
	# Assume if the version strings are not equal, that we are out of date locally
	WAR_URL=`echo "$JSON" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["core"]["url"]'`
	[ $DEBUG -ne 0 ] && echo "WAR_URL: \"$WAR_URL\""
	[ "$WAR_URL" -eq "" ] && fail "Could not determine Jenkins war download URL."
	$CURL -sLO "$WAR_URL"
	mkdir -p "$WAR_DEPLOY_PATH"
	mv jenkins.war "$WAR_DEPLOY_PATH"
	echo "Jenkins $NEW_VERSION deployed!"
else
	echo "No update needed, we are at $JENKINS_VERSION and the most recent version is $NEW_VERSION."
fi
