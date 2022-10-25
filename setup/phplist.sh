#!/bin/bash
# Mail Subbscribe with phplist
# ----------------------

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# ### Installing phplist

# We install phplist from sources, rather than from Ubuntu, because:

# So we'll use apt-get to manually install the dependencies of phplist that we know we need,
# and then we'll manually install phplist from source.

# These dependencies are from `apt-cache showpkg phplist-core`.
echo "Installing phplist (subscriber)..."
sudo apt purge mariadb*
apt_install \
	php-net-socket php${PHP_VER}-gd php${PHP_VER}-mysql php-xml-util \
	php${PHP_VER}-gettext php${PHP_VER}-bcmath mariadb-server
# Install phplist from source if it is not already present or if it is out of date.
# Combine the phplist version number with the commit hash of plugins to track
# whether we have the latest version of everything.
# For the latest versions, see:
#   https://github.com/phplist/phplist/releases

VERSION=3.6.10
HASH=8c3ef484fbdbeed6c13b79f238629bd93ececb77
# paths that are often reused.
RCM_DIR=/usr/local/lib/phplist
RCM_CONFIG=${RCM_DIR}/config/config.php
DB_PASSWORD='Strong*1Password'

needs_update=0 #NODOC
if [ ! -f /usr/local/lib/phplist/version ]; then
	# not installed yet #NODOC
	needs_update=1 #NODOC
fi
if [ $needs_update == 1 ]; then

	# install phpList
	wget_verify \
	https://github.com/phpList/phplist3/archive/refs/tags/v$VERSION.tar.gz \
	$HASH \
		/tmp/phpList.tgz
	tar -C /usr/local/lib --no-same-owner -zxf /tmp/phpList.tgz
	rm -rf /usr/local/lib/phplist
	mv /usr/local/lib/phplist3-$VERSION/public_html/lists $RCM_DIR
	rm -f /tmp/phpList.tgz


	# record the version we've installed
	echo $VERSION > ${RCM_DIR}/version
fi

# ### Configuring phplist

# Generate a secret key of PHP-string-safe characters appropriate
# for the cipher algorithm selected below.
SECRET_KEY=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 | sed s/=//g)

# Create a configuration file.
#
# For security, temp and log files are not stored in the default locations
# which are inside the roundcube sources directory. We put them instead
# in normal places.
cat > $RCM_CONFIG <<EOF;
<?php

/*
* ==============================================================================================================
*
*
* The minimum requirements to get phpList working are in this file.
* If you are interested in tweaking more options, check out the config_extended.php file
* or visit http://resources.phplist.com/system/config
*
* ** NOTE: To use options from config_extended.php, you need to copy them to this file **
*
==============================================================================================================
*/

// what is your Mysql database server hostname
\$database_host = 'localhost';

// what is the name of the database we are using
\$database_name = 'phplistdb';

// what user has access to this database
\$database_user = 'phplist';

// and what is the password to login to control the database
\$database_password = $DB_PASSWORD;

// if you have an SMTP server, set it here. Otherwise it will use the normal php mail() function
//# if your SMTP server is called "smtp.mydomain.com" you enter this below like this:
//#
//#     define("PHPMAILERHOST",$PRIMARY_HOSTNAME);

define('PHPMAILERHOST', '');

// if TEST is set to 1 (not 0) it will not actually send ANY messages, but display what it would have sent
// this is here, to make sure you edited the config file and mails are not sent "accidentally"
// on unmanaged systems

define('TEST', 0);
/*
==============================================================================================================
*
* Settings for handling bounces
*
* This section is OPTIONAL, and not necessary to send out mailings, but it is highly recommended to correctly
* set up bounce processing. Without processing of bounces your system will end up sending large amounts of
* unnecessary messages, which overloads your own server, the receiving servers and internet traffic as a whole
*
==============================================================================================================
*/

// Message envelope.

// This is the address that most bounces will be delivered to
// Your should make this an address that no PERSON reads
// but a mailbox that phpList can empty every so often, to process the bounces

// \$message_envelope = 'listbounces@afroware.ma';

// Handling bounces. Check README.bounces for more info
// This can be 'pop' or 'mbox'
\$bounce_protocol = 'pop';

// set this to 0, if you set up a cron to download bounces regularly by using the
// commandline option. If this is 0, users cannot run the page from the web
// frontend. Read README.commandline to find out how to set it up on the
// commandline
define('MANUALLY_PROCESS_BOUNCES', 1);

// when the protocol is pop, specify these three
\$bounce_mailbox_host = 'localhost';
\$bounce_mailbox_user = 'popuser';
\$bounce_mailbox_password = 'password';

// the "port" is the remote port of the connection to retrieve the emails
// the default should be fine but if it doesn't work, you can try the second
// one. To do that, add a # before the first line and take off the one before the
// second line
\$bounce_mailbox_port = '110/pop3/notls';
// bounce_mailbox_port = "110/pop3";

// it's getting more common to have secure connections, in which case you probably want to use
// bounce_mailbox_port = "995/pop3/ssl/novalidate-cert";

// when the protocol is mbox specify this one
// it needs to be a local file in mbox format, accessible to your webserver user
\$bounce_mailbox = '/var/mail/listbounces';

// set this to 0 if you want to keep your messages in the mailbox. this is potentially
// a problem, because bounces will be counted multiple times, so only do this if you are
// testing things.
\$bounce_mailbox_purge = 1;

// set this to 0 if you want to keep unprocessed messages in the mailbox. Unprocessed
// messages are messages that could not be matched with a user in the system
// messages are still downloaded into phpList, so it is safe to delete them from
// the mailbox and view them in phpList
\$bounce_mailbox_purge_unprocessed = 1;

// how many bounces in a row need to have occurred for a user to be marked unconfirmed
\$bounce_unsubscribe_threshold = 5;

// choose the hash method for password
// check the extended config for more info
// in most cases, it is fine to leave this as it is
define('HASH_ALGO', 'sha256');
EOF


# Create writable directories.
mkdir -p /var/log/phplist /var/tmp/phplist
chown -R www-data.www-data /var/log/phplist /var/tmp/phplist

# Ensure the log file monitored by fail2ban exists, or else fail2ban can't start.
sudo -u www-data touch /var/log/phplist/errors.log

#cretae datatbase

sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('Strong*1Password');
exit
EOF

mysql_secure_installation --password=$DB_PASSWORD
mysql --user=root --password=$DB_PASSWORD <<EOF
CREATE DATABASE phplist;
GRANT ALL PRIVILEGES ON phplist.* TO 'phplist'@'localhost' IDENTIFIED BY 'Strong*1Password';
FLUSH PRIVILEGES;
exit
EOF
