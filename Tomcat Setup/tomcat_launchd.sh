#!/bin/bash
#
# A script to configure and launch Tomcat from a Mac OS X launchd configuration.
#
# For further details on setup and configuration, please see the repository.
#
# Levi Brown
# mailto:levigroker@gmail.com
# April 7, 2015
# Version 1.0
# https://github.com/levigroker/iOSContinuousIntegration
##

# Configuration
export CATALINA_HOME=${CATALINA_HOME:-"/Library/Tomcat/Home"}
export JENKINS_HOME=${JENKINS_HOME:-"/Library/jenkins/Home"}
export JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8 -server -Xms1536m -Xmx1536m -XX:NewSize=512m -XX:MaxNewSize=512m -XX:PermSize=512m -XX:MaxPermSize=512m -XX:+DisableExplicitGC $JAVA_OPTS"

###

# Fully qualified binaries
LOGGER_B="/usr/bin/logger"
BASENAME_B="/usr/bin/basename"
MKTEMP_B="/usr/bin/mktemp"
CAT_B="/bin/cat"

BASENAME=`$BASENAME_B $0`
DEBUG=${DEBUG:-1}
export DEBUG

# NOTE: Do NOT `set -eu`! The script will not function properly.
[ $DEBUG -ne 0 ] && set -x

function log {
	MESSAGE="$1"
	$LOGGER_B -i -p daemon.notice -t $BASENAME $MESSAGE
}

function fail()
{
    log "Failed: $@" >&2
    exit 1
}

function shutdown() {
	log "Shutting down Tomcat"
    "$CATALINA_HOME/bin/catalina.sh" stop
}

log "Starting Tomcat"

TMP_TEMPLATE=$BASENAME
TMP_FILE=`$MKTEMP_B -t $TMP_TEMPLATE` || fail "Could not create temp file \"$TMP_TEMPLATE\""
export CATALINA_PID="$TMP_FILE"
 
log "CATALINA_HOME: \"$CATALINA_HOME\""
log "JAVA_OPTS: \"$JAVA_OPTS\""
log "JENKINS_HOME: \"$JENKINS_HOME\""
log "CATALINA_PID: \"$CATALINA_PID\""

. "$CATALINA_HOME/bin/catalina.sh" start
 
# Allow any signal which would kill a process to stop Tomcat
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP
 
log "Waiting for process \"`$CAT_B $CATALINA_PID`\""

# Here we wait for the catalina process to finish. This keeps this script alive so launchd
# knows the process is running as expected.
# The `trap` above catches the signals needed to properly call catalina.sh stop if needed.
wait `$CAT_B $CATALINA_PID`

log "Done waiting."
