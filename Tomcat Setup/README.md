
1. Instal Xcode
via the App Store  
Launch it and get past the software license so it can setup properly.

2. Install OS X Server
via the App Store  
Launch it and get past the software license so it can setup properly.

3. Install &lt;gasp&gt; [Java](http://www.oracle.com/technetwork/java/javase/downloads/index.html)  
    Mac OS X no longer comes with Java preinstalled, and Jenkins requires it, so we need to install the JDK.  
    (JDK 8 update 40, at time of writing)
    * Verify the install by issuing the `java -version` command in a terminal. You should see `java version "1.8.0_40"` or similar.
    * Disable Java in your browser, because it is not generally safe: System Preferences > Java > Security > uncheck "Enable Java content in the browser"

### Tomcat

http://tomcat.apache.org
(Tomcat 8.0.21 at time of writing)

Create `/usr/local` if it does not already exist:

    sudo mkdir -p /usr/local

Unzip the Tomcat zip and move the whole `apache-tomcat-8.0.21` directory  into `/usr/local`:

    sudo cp -R apache-tomcat-8.0.21 /usr/local

The tomcat process will run as `_www` so we need to change ownership of the directory:

	sudo chown -R _www:wheel /usr/local/apache-tomcat-8.0.21

Setup a couple admin users for tomcat.  
In `/usr/local/apache-tomcat-8.0.21/conf/tomcat-users.xml` add these lines to the bottom of the file, above the `</tomcat-users>` line:

	<role rolename="manager-gui"/>
	<user username="tomcat" password="0u812!" roles="manager-gui"/>
	<role rolename="admin"/>
	<user username="jenkins-admin" password="0u81too?" roles="admin"/>

(NOTE: obviously set your own passwords!!)

Add `URIEncoding="UTF-8"` to the Connector in `/usr/local/apache-tomcat-8.0.21/conf/server.xml`

i.e. edit `/usr/local/apache-tomcat-8.0.21/conf/server.xml` so that:

    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />

gets changed to:

    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443"
               URIEncoding="UTF-8" />

This is needed for jenkins to load properly (see the **i18n** section in [https://wiki.jenkins-ci.org/display/JENKINS/Tomcat](https://wiki.jenkins-ci.org/display/JENKINS/Tomcat))(

Now we will create `/Library/Tomcat/logs` to hold the tomcat logs, and `/Library/Tomcat` for tomcat's meta configuration.

	sudo mkdir -p /Library/Tomcat/logs
	
Copy the meta configuration files from this repo into `/Library/Tomcat`

	org.apache.tomcat_webapp.plist
	org.apache.tomcat.plist
	tomcat_apache2.conf
	tomcat_launchd.sh
	tomcat_webapp_setup.sh

root owns `/Library/Tomcat` and it's contents:

	sudo chown -R root:wheel /Library/Tomcat

Except, tomcat will run as `_www` so, we need the `logs` directory to be writable to `_www`:

	sudo chown -R _www:wheel /Library/Tomcat/logs

Create a symbolic link to the tomcat install

	cd /Library/Tomcat
	sudo ln -s /usr/local/apache-tomcat-8.0.21 Home
	
Your `/Library/Tomcat` directory should look like this now:

	drwxr-xr-x   9 root  wheel   306 Apr  7 17:14 .
	drwxr-xr-x+ 62 root  wheel  2108 Apr  6 11:34 ..
	lrwxr-xr-x   1 root  wheel    31 Apr  7 17:14 Home -> /usr/local/apache-tomcat-8.0.21
	drwxr-xr-x   2 _www  wheel    68 Apr  6 11:34 logs
	-rw-r--r--   1 root  wheel  1191 Apr  7 17:13 org.apache.tomcat.plist
	-rw-r--r--   1 root  wheel  1902 Apr  7 17:13 org.apache.tomcat_webapp.plist
	-rw-r--r--@  1 root  wheel   529 Apr  7 17:13 tomcat_apache2.conf
	-rwxr-xr-x   1 root  wheel  1986 Apr  7 17:13 tomcat_launchd.sh
	-rwxr-xr-x   1 root  wheel  1588 Apr  7 17:13 tomcat_webapp_setup.sh

Now execute the `tomcat_webapp_setup.sh` script to setup needed symbolic links:

	sudo /Library/Tomcat/tomcat_webapp_setup.sh

You should see messages like the following (among other output):

	+ MESSAGE='Linked webapp configuration.'
	+ MESSAGE='Linked webapp launchd configuration.'

Now tomcat is setup as a Server.app web app, but we still need to prepare for Jenkins.

Create JENKINS_HOME at `/Library/jenkins/Home`

	sudo mkdir -p /Library/jenkins/Home
	
The `_www` user will be what tomcat (and therefore jenkins) is running as, so we want jenkins to be able to "own" it's home:

	sudo chown -R _www:wheel /Library/jenkins/Home

**Restart**

All the configuration changes we've made need to be put in place, and because of OS level caching of these configurations, it's best to restart the machine.

* Once logged back in, open the Server.app and turn on "Websites".
* Once "Websites" are enabled, select "Server Website" from the list, and click on the pencil icon to edit it.
* From the resulting dialog, click on the "Edit Advanced Settings..." button.
* From the "Advanced Settings" you should see a list of webapps. By default there is a `Python "Hello World" app at /wsgi` app in the list. You should also now see `Tomcat`
* Enable (check) the `Tomcat` application, click "OK" to exit "Advanced Settings" and then "OK" again to exit out or "Server Website"

You should be able to open a browser (from the server machine!) to [http://localhost:8080](http://localhost:8080) and see Tomcat running.

If not, take a look in `/var/log/system.log` to see if anything is getting logged with regards to tomcat.

Now that we have tomcat running, we need to setup Jenkins!

### Install Jenkins

Download the `jenkins.war` from [http://jenkins-ci.org](http://jenkins-ci.org) (version 1.608 as of time of writing)

Copy the `jenkins.war` into tomcat's webapps directory so we can deploy it:

	sudo cp jenkins.war /Library/Tomcat/Home/webapps
	sudo chown _www /Library/Tomcat/Home/webapps/jenkins.war

Login to Tomcat as a manager. Remember the `tomcat` user we setup in `tomcat-users.xml` (above)?

Open [http://localhost:8080/manager/html](http://localhost:8080/manager/html) and login with the `tomcat` user credentials you setup previously.

You should see `/jenkins` in the list of webapps, and should be able to click the "Start" button in the tomcat manager UI.

Now you should be able to see jenkins at [http://localhost:8080/jenkins](http://localhost:8080/jenkins)

### Configure Jenkins Slave

Here we will configure a Jenkins slave to run on the same machine as the server, but as the GUI user. We do this for a couple reasons.

1. Tomcat, and therefore Jenkins, is running as _www and is configured as a Launch Daemon. This means these processes can't interact with the GUI, so if we needed to have them open a window or anything else, we can't. A slave running as a fully qualified GUI user can.
2. Running as a fully qualified GUI user means we can login as that user and inspect the slave build directory, open the project in Xcode and generally be able to debug the build process without being in the dark.

Setup the ssh keys Jenkins will use to connect to the slave.

	sudo mkdir -p /Library/jenkins/ssh
	
	sudo ssh-keygen -t rsa

Save the key to `/Library/jenkins/ssh/id_rsa` with no password.

	sudo chown -R _www:wheel /Library/jenkins/ssh

Add these credentials to Jenkins... Go to Jenkins web interface: Jenkins > Manage Jenkins > Manage Credentials > Add Credentials > "SSH Username with private key"

Now add these credentials to your GUI user. In this example the user is `admin`

First, ensure you can ssh as `admin` to localhost:

	$ ssh admin@localhost
	The authenticity of host 'localhost (::1)' can't be established.
	RSA key fingerprint is 4b:3a:b9:54:d9:d4:27:0b:2e:bc:81:0b:4a:3e:8d:81.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added 'localhost' (RSA) to the list of known hosts.
	Password:
	Last login: Tue Apr  7 17:31:15 2015
	$ exit
	logout
	Connection to localhost closed.

Now we append the `id_rsa.pub` we created to the `.ssh/authorized_keys` file of the `admin` user:

	sudo cat /Library/jenkins/ssh/id_rsa.pub | ssh admin@localhost 'cat >> .ssh/authorized_keys'

To test that this is setup properly, we can initiate an ssh connection as admin to localhost using the private key we just created:

	$ sudo ssh -i /Library/jenkins/ssh/id_rsa admin@localhost
	The authenticity of host 'localhost (::1)' can't be established.
	RSA key fingerprint is 4b:3a:b9:54:d9:d4:27:0b:2e:bc:81:0b:4a:3e:8d:81.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added 'localhost' (RSA) to the list of known hosts.
	Last login: Wed Apr  8 15:17:34 2015 from localhost
	buildcoradinecom:~ admin$ exit
	logout
	Connection to localhost closed.
	
As you can see, we needed to accept the public key. Let's do it one more time to validate there are no more prompts:

	$ sudo ssh -i /Library/jenkins/ssh/id_rsa admin@localhost
	Last login: Wed Apr  8 15:26:45 2015 from localhost
	$ exit
	logout
	Connection to localhost closed.

Looks good.

There is a decent general writup on setting up ssh login over at [http://www.linuxproblem.org/art_9.html](http://www.linuxproblem.org/art_9.html)

Let's now create a directory for the slave to install itself and maintain build artifacts, etc.:

	sudo mkdir -p /Library/jenkins/slave
	sudo chown -R admin:wheel /Library/jenkins/slave
	
(this assumes the `admin` user is your GUI user)	

Now that we have the credentials setup and a root for the slave, we need to create the Jenkins slave node... Go to Jenkins web interface: Jenkins > Manage Jenkins > Manage Nodes > New Node

Add a Node Name (something like "Xcode Build Slave").

Choose "Dumb Slave" (no other option)

Set the remote root directory to `/Library/jenkins/slave` (which we created above)

Ensure "Launch Method" is "Launch slave agents on Unix machines via SSH". "Host" is "localhost", and "Credentials" are the credentials we setup previously.

Save the node.

You should be able to "Refresh status" and see the "Xcode Build Slave" stats show up.

### Jenkins AutoUpdate

Install the "GitHub Plugin"

Create a new "Freestyle" job called "Jenkins AutoUpdate"

In the job configuration:

"GitHub Project" is `https://github.com/levigroker/iOSContinuousIntegration/`

Under "Source Code Managemen" choose "Git" and the "Repository URL" is `https://github.com/levigroker/iOSContinuousIntegration.git`

"Build Triggers" > select "Build periodically" and in the "Schedule" field enter "@daily"

Build > Add Build Step > Execute Shell: `WAR_DEPLOY_PATH="/Library/Tomcat/Home/webapps/" /bin/bash Jenkins/jenkins_autoupdate.sh`

Save.