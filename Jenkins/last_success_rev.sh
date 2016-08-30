#!/bin/sh
#
# Fetches the last successful build GIT revision hash from a Jenkins job at the specified
# URL. This expects the URL supplied by Jenkins in the JOB_URL variable (and is expected
# to be terminated by a / character).
#
# Example:
# % ./last_success_rev.sh http://myserver.com:8080/jenkins/job/MyJob/
#
# NOTE: Be sure the access token represents a user which has read access on the job.
#
# See https://wiki.jenkins-ci.org/display/JENKINS/Authenticating+scripted+clients
#
# Levi Brown
# mailto:levigroker@gmail.com
# October 5, 2011
# https://github.com/levigroker/iOSContinuousIntegration
##

function fail()
{
    echo "Failed: $@" >&2
    # We exit with success, even though we fail, so calling scripts simply get "" as the
    # result and can do their own error handling.
    exit 0
}

DEBUG=${DEBUG:-0}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

# ----------------------
# Configuration Section
# ----------------------
JENKINS_USER=${JENKINS_USER:-""}
JENKINS_API_TOKEN=${JENKINS_API_TOKEN:-""}
LAST_SUCCESS_URL_SUFFIX="lastSuccessfulBuild/api/xml"
# ----------------------

# Fully qualified binaries
GREP_B="/usr/bin/grep"
CURL_B="/usr/bin/curl"
SED_B="/usr/bin/sed"

# Sanity check input
URL=$1
if [ "$URL" = "" ]; then
	fail "No URL specified."
fi

if [ "$JENKINS_USER" = "" ]; then
	fail "Empty JENKINS_USER specified. Please export JENKINS_USER with the desired Jenkins username."
fi

if [ "$JENKINS_API_TOKEN" = "" ]; then
	fail "Empty JENKINS_API_TOKEN specified. Please export JENKINS_API_TOKEN with the needed Jenkins API token."
fi

URL="$URL$LAST_SUCCESS_URL_SUFFIX"

REZ=$($CURL_B --insecure --silent --user "$JENKINS_USER:$JENKINS_API_TOKEN" "$URL" | $GREP_B "<lastBuiltRevision>" | $SED_B 's|.*<lastBuiltRevision>.*<SHA1>\(.*\)</SHA1>.*<branch>.*|\1|')
echo $REZ
