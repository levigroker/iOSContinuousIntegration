iOS Continuous Integration
===========
A collection of scripts to automate the build and deploy steps of iOS applications for
continuous integration via the excellent [Jenkins](http://jenkins-ci.org).

### Installing

#### Dependencies
[cupertino](https://github.com/mattt/cupertino) is used to fetch the latest distribution
provisioning profile from the Apple iOS Developer portal.

#### Install

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


#### Configuration

Assuming you've created a Jenkins freeform job for your build, create an "Execute Shell"
build step, and pass in the needed configuration values, like this:

	DEBUG=0 \
	APP_NAME="Foo" \
	KEYCHAIN_PASSWORD="supersecret" \
	DEV_USER="levi" \
	DEV_PASSWORD="devsecret" \
	JENKINS_USER="levi" \
	JENKINS_API_TOKEN="somereallylonggoop" \
	TF_API_TOKEN="otherreallylonggoop" \
	TF_TEAM_TOKEN="evenlongergoop" \
	/bin/sh Foo/Foo/jenkins/build.sh

`DEV_USER` and `DEV_PASSWORD` are the credentials for the Apple Developer account which
contains the desired distribution mobileprovision. If not supplied, the script will assume
[cupertino](https://github.com/mattt/cupertino) has the needed credentials in the keychain
already.

To figure out your `JENKINS_API_TOKEN` visit the [Jenkins Wiki](https://wiki.jenkins-ci.org/display/JENKINS/Authenticating+scripted+clients)

The `build.sh` script is configured (by default) to assume your `origin/master` branch
will be deployed to a [TestFlight](http:/testflightapp.com) distribution list named
`Internal Release` and any other branch to a distribution list named `Development`.

NOTE: You may want to specify the shell which Jenkins uses so sensitive information in
your configuration is not output to the Jenkins log. To do this, simply add `#!/bin/sh -e`
as the first line of the "Execute Shell" script. This will replace the default of
`#!/bin/sh -ex` (note the 'x') which prints out all evaluations.

#### Licence

This work is licensed under the [Creative Commons Attribution 3.0 Unported License](http://creativecommons.org/licenses/by/3.0/).
Please see the included LICENSE.txt for complete details.

#### About
A professional iOS engineer by day, my name is Levi Brown. Authoring a technical
blog [grokin.gs](http://grokin.gs), I am reachable via:

Twitter [@levigoker](https://twitter.com/levigroker)
App.net [@levigroker](https://alpha.app.net/levigroker)
EMail [levigroker@gmail.com](mailto:levigroker@gmail.com).

Your constructive comments and feedback are always welcome.
