#!/bin/bash
#--
# install_html.sh
#
# A script which will output HTML to be used as an iOS AdHoc installation landing page.
#
# This script takes three arguments:
# * The user facing name for the application build [required]
# * An installation URL of the form "itms-services://?action=download-manifest&url=<url_to_manifest.plist>" [required]
# * A URL to the application icon image file.
#
# Levi Brown
# mailto:levigroker@gmail.com
# August 15, 2016
# https://github.com/levigroker/iOSContinuousIntegration
##

function usage()
{
	[[ "$@" = "" ]] || echo "$@" >&2
	echo "Usage:" >&2
	echo "$0 <archive_build_name> <install_url> <icon_url>" >&2
    exit 1
}

function fail()
{
    echo "Failed: $@" >&2
    exit 1
}

DEBUG=${DEBUG:-0}

set -eu
[ $DEBUG -ne 0 ] && set -x

ARCHIVE_BUILD_NAME=${1:-""}
INSTALL_URL=${2:-""}
ICON_URL=${3:-""}

if [ "$ARCHIVE_BUILD_NAME" = "" ]; then
	usage "Please supply a user facing name for the application build."
fi
if [ "$INSTALL_URL" = "" ]; then
	usage "Please supply an installation URL ( itms-services://?action=download-manifest&url=<url_to_manifest.plist> )."
fi
if [ "$ICON_URL" = "" ]; then
	usage "Please supply a URL to the application icon image file."
fi

# Fully qualified binaries (_B suffix to prevent collisions)
export CAT_B="/bin/cat"

HTML=$($CAT_B <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	 "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en" style="-webkit-text-size-adjust: none;">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta name="viewport" content="width=320">
<style type="text/css">
body {
margin: 0; padding: 0; border: 0; font-family: "Helvetica Neue", Arial, sans-serif; background: black; color: white;
}
img {
display: block;
}
</style>
</head>
<body marginheight="0" topmargin="0" marginwidth="0" leftmargin="0" style="font-family: 'Helvetica Neue', Arial, sans-serif; color: white; background: black; margin: 0; padding: 0; border: 0;">
  <!--100% body table-->
  <table bgcolor="black" cellspacing="0" cellpadding="0" border="0" width="100%" class="full-wrapper" style="font-family: 'Helvetica Neue', Arial, sans-serif; color: white; background: black; margin: 0; padding: 0; border: 0;">
    <tr>
      <td align="center" style="color: white;">
        <table border="0" cellspacing="0" cellpadding="0" width="320"><tr><td class="main-cell" align="center" style="color: white; padding-bottom: 80px;">
          <table id="stage" border="0" cellspacing="0" cellpadding="0">
            <tr><td class="stage-cell" align="center" style="color: white; padding: 96px 0 31px;" width="320">
              <div class="icon-wrapper">
                <img src="$ICON_URL" width="60" height="60" alt="" class="icon60" style="display: block; border-radius: 11px; moz-border-radius: 11px; khtml-border-radius: 11px; o-border-radius: 11px; webkit-border-radius: 11px; ms-border-radius: 11px;" />
              </div>
            </td></tr>
            <tr><td class="stage-footer-cell" style="color: white; height: 10px;"></td></tr>
          </table>

          <table border="0" cellspacing="0" cellpadding="0" width="320" align="center">
  <tr><td class="content-cell" style="color: white; text-align: center; padding: 0 20px 30px;" align="center">
    <h3 style="font-family: 'HelveticaNeue-Light', 'Helvetica Neue', Arial, sans-serif; font-size: 34px; font-weight: normal; color: #fff; line-height: 1.2; margin: 0;">$ARCHIVE_BUILD_NAME</h3>
  </td></tr>

  <tr>
    <td class="message-cell" style="color: white; padding: 0 10px;">
      <div class="p" style="color: #ccc; font-size: 16px; line-height: 20px; padding: 0 0 20px;">
        Download and install the build by tapping the button below on your mobile device.
      </div>

      <div class="action-wrapper" style="padding: 20px 0;">
        <a href="$INSTALL_URL">
          <img src="https://fabric.io/mobile/img/install_2x.png" alt="Install Update" width="155" height="35" style="display: block; margin: 0 auto;" />
        </a>
      </div>
    </td>
  </tr>
</table>
</body>
</html>
EOF
)

echo "$HTML"
