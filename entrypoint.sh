#!/bin/sh
set -e
set -x

BACKUPPC_USERNAME=`getent passwd "${BACKUPPC_UUID:-1000}" | cut -d: -f1`
BACKUPPC_GROUPNAME=`getent group "${BACKUPPC_GUID:-1000}" | cut -d: -f1`

if [ -f /firstrun ]; then
	echo 'First run of the container. BackupPC will be installed.'
	echo 'If exist, configuration and data will be reused and upgraded as needed.'

	# Configure timezone if needed
	if [ -n "$TZ" ]; then
		cp /usr/share/zoneinfo/$TZ /etc/localtime 
	fi

	# Create backuppc user/group if needed
	if [ -z "$BACKUPPC_GROUPNAME" ]; then
		groupadd -r -g "${BACKUPPC_GUID:-1000}" backuppc
		BACKUPPC_GROUPNAME="backuppc"
	fi
	if [ -z "$BACKUPPC_USERNAME" ]; then
		useradd -r -d /home/backuppc -g "${BACKUPPC_GUID:-1000}" -u ${BACKUPPC_UUID:-1000} -M -N backuppc
		BACKUPPC_USERNAME="backuppc"
	else
		usermod -d /home/backuppc "$BACKUPPC_USERNAME"
	fi
	chown "$BACKUPPC_USERNAME":"$BACKUPPC_GROUPNAME" /home/backuppc

	# Generate cryptographic key
	if [ ! -f /home/backuppc/.ssh/id_rsa ]; then
		#su "$BACKUPPC_USERNAME" -s /bin/sh -c "ssh-keygen -t rsa -N '' -f /home/backuppc/.ssh/id_rsa"
	fi

	# Extract BackupPC
	cd /root
	tar xf BackupPC-$BACKUPPC_VERSION.tar.gz
	cd /root/BackupPC-$BACKUPPC_VERSION

	# Configure WEB UI access
	configure_admin=""
	if [ ! -f /etc/backuppc/htpasswd ]; then
		htpasswd -b -c /etc/backuppc/htpasswd "${BACKUPPC_WEB_USER:-backuppc}" "${BACKUPPC_WEB_PASSWD:-password}"
		configure_admin="--config-override CgiAdminUsers='${BACKUPPC_WEB_USER:-backuppc}'"
	elif [ -n "$BACKUPPC_WEB_USER" -a -n "$BACKUPPC_WEB_PASSWD" ]; then
		touch /etc/backuppc/htpasswd
		htpasswd -b /etc/backuppc/htpasswd "${BACKUPPC_WEB_USER}" "${BACKUPPC_WEB_PASSWD}"
		configure_admin="--config-override CgiAdminUsers='$BACKUPPC_WEB_USER'"
	fi

	# Install BackupPC (existing configuration will be reused and upgraded)
	perl configure.pl \
		--batch \
		--config-dir /etc/backuppc \
		--cgi-dir /var/www/cgi-bin/BackupPC \
		--data-dir /data/backuppc \
		--log-dir /data/backuppc/log \
		--hostname localhost \
		--html-dir /var/www/html/BackupPC \
		--html-dir-url /BackupPC \
		--install-dir /usr/local/BackupPC \
		--backuppc-user "$BACKUPPC_USERNAME" \
		$configure_admin

	#Preparer httpd
	if [ ! -f /etc/httpd/conf.d/BackupPC.conf ]; then
		cd /etc/httpd/conf.d/BackupPC.conf
		touch BackupPC.conf
		echo "# htpasswd -c /etc/BackupPC/apache.users yourusername" > BackupPC.conf
		echo "<DirectoryMatch>" > BackupPC.conf
		echo "AuthType Basic" > BackupPC.conf
		echo "AuthUserFile /etc/BackupPC/apache.users" > BackupPC.conf
		echo "AuthName \"BackupPC\"" > BackupPC.conf
		echo "<IfModule mod_authz_core.c>" > BackupPC.conf
  		echo "<RequireAll>" > BackupPC.conf
    		echo "Require user backuppc" > BackupPC.conf
    		echo "Require valid-user" > BackupPC.conf
  		echo "</RequireAll>" > BackupPC.conf
		echo "</IfModule>" > BackupPC.conf
		echo "</DirectoryMatch>" > BackupPC.conf
		echo "Alias           /BackupPC/images        /usr/share/BackupPC/html/" > BackupPC.conf
		echo "ScriptAlias     /BackupPC               /usr/libexec/BackupPC/BackupPC_Admin" > BackupPC.conf
		echo "ScriptAlias     /backuppc               /usr/libexec/BackupPC/BackupPC_Admin" > BackupPC.conf
	fi

	# Configure standard mail delivery parameters (may be overriden by backuppc user-wide config)
	echo "account default" > /etc/msmtprc
	echo "host ${SMTP_HOST:-mail.example.org}" >> /etc/msmtprc
	echo "auto_from on" >> /etc/msmtprc
	if [ "${SMTP_MAIL_DOMAIN:-}" != "" ]; then
		echo "maildomain ${SMTP_MAIL_DOMAIN}" >> /etc/msmtprc
	fi

	# Clean
	rm -rf /root/BackupPC-$BACKUPPC_VERSION.tar.gz /root/BackupPC-$BACKUPPC_VERSION /firstrun

	# generate host keys if not present
	#ssh-keygen -A

	# check wether a random root-password is provided
	if [ ! -z ${ROOT_PASSWORD} ] && [ "${ROOT_PASSWORD}" != "root" ]; then
    		echo "root:${ROOT_PASSWORD}" | chpasswd
	fi
fi

export BACKUPPC_USERNAME
export BACKUPPC_GROUPNAME

# Exec given CMD in Dockerfile
#exec /usr/sbin/sshd -D -e "$@"
exec "$@"
