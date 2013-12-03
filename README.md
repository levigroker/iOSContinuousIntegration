iOS Continuous Integration
===========
A collection of scripts to automate the build and deploy steps of iOS applications for
continuous integration via the excellent [Jenkins](http://jenkins-ci.org).

# Jenkins Automation

`jenkins_autoupdate.sh`
A script to automatically update the Jenkins web application if a new version is
available. The intention is for this script to be executed periodically as a Jenkins Job.

# Continuous Integration

The following files make up the CI portion of this repository:

`build.sh`
`download_profile.sh`
`last_success_rev.sh`
`testflight.sh`

## Dependencies
[cupertino](https://github.com/mattt/cupertino) is used to fetch the latest distribution
provisioning profile from the Apple iOS Developer portal.

## Install

Let's say you have a workspace set up called Foo.xcworkspace. At the same level of your
workspace, there's typically a directory called "Foo" which contains your sources. These
scrips are designed to reside in a directory named `jenkins` inside of that directory. So
your directory structure should look like this:

	Foo.xcworkspace
	Foo
		jenkins
			build.sh
			download_profile.sh
			last_success_rev.sh
			testflight.sh


## Configuration

Assuming you've created a Jenkins freeform job for your build, create an "Execute Shell"
build step, and pass in the needed configuration values, like this:

	#!/bin/bash -e
	DEBUG=0 \
	TF_UPLOAD=1 \
	APP_NAME="Foo" \
	PROJECT_NAME="Bar" \
	DEV_USER="levi" \
	DEV_PASSWORD="devsecret" \
	KEYCHAIN_PASSWORD="supersecret" \
	JENKINS_USER="levi" \
	JENKINS_API_TOKEN="somereallylonggoop" \
	TF_API_TOKEN="otherreallylonggoop" \
	TF_TEAM_TOKEN="evenlongergoop" \
	/bin/bash Archer/Archer/jenkins/build.sh

`DEBUG` (if set to `1`) will enable verbose output of the script.

`TF_UPLOAD` (if set to `1`) will upload the generated `.ipa`'s and `DSYM` files to [TestFlight](http://testflightapp.com).

`APP_NAME` is the name of the application being built; i.e. `Foo.ipa`

`PROJECT_NAME` is the name of the Xcode project (workspace) being built; i.e. `Bar.xcworkspace`

`DEV_USER` and `DEV_PASSWORD` are the credentials for the Apple Developer account which
contains the desired distribution mobileprovision. If not supplied, the script will assume
[cupertino](https://github.com/mattt/cupertino) has the needed credentials in the keychain
already.

`KEYCHAIN_PASSWORD` is the password for the default keychain on the build machine which
contains the certificates and keys needed for the build.

To figure out your `JENKINS_API_TOKEN` visit the [Jenkins Wiki](https://wiki.jenkins-ci.org/display/JENKINS/Authenticating+scripted+clients)

NOTE: You may want to specify the shell which Jenkins uses so sensitive information in
your configuration is not output to the Jenkins log. To do this, simply add `#!/bin/sh -e`
as the first line of the "Execute Shell" script. This will replace the default of
`#!/bin/sh -ex` (note the 'x') which prints out all evaluations.

### Build Configurations

Additional configuration may be desired within the `build.sh` script to specify the
different Xcode schemes to build. See the `Build Configurations` section in `build.sh`:

In the example below, there will be three builds. A "Tests" build, AdHoc and Enterprise.
The following configurations are index-representative for each config type. For instance,
the "Tests" scheme (defined in `SCHEMES`) is enabled (`SCHEME_ENABLEDS`) has the label
"Tests" (`SCHEME_LABELS`), is of type `$TEST_TYPE` (`BUILD_TYPES`), uses the "AdHoc" Xcode
configuration (`CONFIGS`), uses the mobileprovision profile called `$PROJECT_NAME AdHoc`
(`PROFILE_NAMES`) which is of type "distribution" (`PROFILE_TYPES`) and uses the
`local_profile.sh` (`PROFILE_ACQUISITION_SCRIPTS`) to provide the actual mobileprovision
file.

	SCHEMES=("Tests" "$PROJECT_NAME" "$PROJECT_NAME Enterprise")
	SCHEME_ENABLEDS=("$YES" "$YES" "$YES")
	SCHEME_LABELS=("Tests" "AdHoc" "Enterprise")
	BUILD_TYPES=("$TEST_TYPE" "$IPA_TYPE" "$IPA_TYPE")
	CONFIGS=("AdHoc" "AdHoc" "Enterprise")
	PROFILE_NAMES=("$PROJECT_NAME AdHoc" "$PROJECT_NAME AdHoc" "$PROJECT_NAME Enterprise")
	# The type of profile (used to download the profile from the Apple Developer portal)
	PROFILE_TYPES=("distribution" "distribution" "distribution")
	# Script relative to $RESOURCE_DIR/$CI_DIR which will download mobileprovision profile files
	PROFILE_ACQUISITION_SCRIPTS=("local_profile.sh" "local_profile.sh" "local_profile.sh")

#### TestFlight

Each scheme listed in `SCHEMES` should have a corresponding TestFlight list defined.

In the example below, the "Tests" build does not get distributed to TestFlight, yet the
second build will be distributed to the "Development" list while the third build wil go
to the "Enterprise" list.

	TF_DIST_LISTS=("" "Development" "Enterprise")

#### local_profile.sh

Additional configuration is needed within the `local_profile.sh` script to specify the
different hardcoded profiles to fetch from the filesystem. See the `Configuration Section`
section in `local_profile.sh`:

	#The hardcoded profile names we are expecting
	PROFILE_NAMES=("CHANGE_ME AdHoc" "CHANGE_ME Enterprise")
	#The matching profile files
	PROFILE_FILES=("CHANGE_ME_AdHoc.mobileprovision" "CHANGE_ME_Enterprise.mobileprovision")

# Licence

This work is licensed under the [Creative Commons Attribution 3.0 Unported License](http://creativecommons.org/licenses/by/3.0/).
Please see the included LICENSE.txt for complete details.

# About
A professional iOS engineer by day, my name is Levi Brown. Authoring a technical
blog [grokin.gs](http://grokin.gs), I am reachable via:

Twitter [@levigoker](https://twitter.com/levigroker)  
App.net [@levigroker](https://alpha.app.net/levigroker)  
EMail [levigroker@gmail.com](mailto:levigroker@gmail.com)  

Your constructive comments and feedback are always welcome.
