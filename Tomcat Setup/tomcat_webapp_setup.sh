#!/bin/bash
#
# A script to perform initial configuration of the Tomcat webapp.
#
# This assumes Tomcat is "based" in /Library/Tomcat.
# For further details on setup and configuration, please see the repository.
#
# Levi Brown
# mailto:levigroker@gmail.com
# April 7, 2015
# Version 1.0
# https://github.com/levigroker/iOSContinuousIntegration
##

# Configuration
HOME="/Library/Tomcat"
WEBAPP_CONF="org.apache.tomcat_webapp.plist"
LAUNCHD_CONF="org.apache.tomcat.plist"

WEBAPP_HOME_DIR="/Library/Server/Web/Config/apache2/webapps"
WEBAPP_LAUNCHD_DIR="/Applications/Server.app/Contents/ServerRoot/System/Library/LaunchDaemons"

# Fully qualified binaries
LOGGER_B="/usr/bin/logger"
BASENAME_B="/usr/bin/basename"
LN_B="/bin/ln"

BASENAME=`$BASENAME_B $0`
DEBUG=${DEBUG:-1}
export DEBUG

set -eu
[ $DEBUG -ne 0 ] && set -x

function log {
	MESSAGE="$1"
	$LOGGER_B -i -p daemon.notice -t $BASENAME $MESSAGE
}

# Create a symbolic link to the webapp configuration in the webapp directory
if [ -f "$WEBAPP_HOME_DIR/$WEBAPP_CONF" ]; then
	log "Webapp configuration already present at \"$WEBAPP_HOME_DIR/$WEBAPP_CONF\""
else
	cd "$WEBAPP_HOME_DIR"
	$LN_B -s "$HOME/$WEBAPP_CONF" "$WEBAPP_CONF"
	log "Linked webapp configuration."
fi

# Create a symbolic link to the launchd configuration from the webapp launchd directory
if [ -f "$WEBAPP_LAUNCHD_DIR/$LAUNCHD_CONF" ]; then
	log "Webapp launchd configuration already present at \"$WEBAPP_LAUNCHD_DIR/$LAUNCHD_CONF\""
else
	cd "$WEBAPP_LAUNCHD_DIR"
	$LN_B -s "$HOME/$LAUNCHD_CONF" "$LAUNCHD_CONF"
	log "Linked webapp launchd configuration."
fi
