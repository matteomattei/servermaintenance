#!/bin/bash
set -e
ADMIN_EMAIL="info@yourdomain.com"
DOMAIN="${1}"
CREATE_ALIAS=""

if [ -z "${DOMAIN}" ]
then
  	echo "Usage: ${0} domain.tld"
  	exit 1
fi


if [ -d /var/www/vhosts/${DOMAIN} ]
then
    echo "DOMAIN ${DOMAIN} already present"
    exit 1
fi

while true
do
    echo "Do you want to create www.${DOMAIN} alias for ${DOMAIN} ? [Y/n]"
    read CREATE_ALIAS
    if [ -z "${CREATE_ALIAS}" -o "${CREATE_ALIAS}" = "Y" -o "${CREATE_ALIAS}" = "y" ]
    then
        CREATE_ALIAS="Y"
        break
    elif [ "${CREATE_ALIAS}" = "n" -o "${CREATE_ALIAS}" = "N" ]
    then
        CREATE_ALIAS="N"
        break
    fi
done

# ADD USER
PASSWORD=$(pwgen 10 1)
LAST_USER=$(grep -o "^web[0-9]:" /etc/passwd | sort | tail -n1 | grep -o "[0-9]*" || true)
NEXT_USER="web"
if [ -z "${LAST_USER}" ]
then
    NEXT_USER=${NEXT_USER}1
else
    NEXT_USER=${NEXT_USER}$((${LAST_USER}+1))
fi
useradd -M -s /usr/sbin/nologin -d /var/www/vhosts/${DOMAIN} -U ${NEXT_USER} > /dev/null
echo "${NEXT_USER}:${PASSWORD}" | chpasswd
usermod -G sftponly ${NEXT_USER} > /dev/null
mkdir -p /var/www/vhosts/${DOMAIN}/{httpdocs,logs}
chown root:root /var/www/vhosts/${DOMAIN}
chmod 755 /var/www/vhosts/${DOMAIN}
chown ${NEXT_USER}:sftponly /var/www/vhosts/${DOMAIN}/httpdocs
chown ${NEXT_USER}:${NEXT_USER} /var/www/vhosts/${DOMAIN}/logs

# PHP
CONF_FILE="/etc/php/7.3/fpm/pool.d/${NEXT_USER}.conf"

cp /etc/php/7.3/fpm/pool.d/www.conf ${CONF_FILE}
sed -i "s/\[www\]/[${NEXT_USER}]/g" ${CONF_FILE}
sed -i "s/^user = www-data/user = ${NEXT_USER}/g" ${CONF_FILE}
sed -i "s/^group = www-data/group = ${NEXT_USER}/g" ${CONF_FILE}
sed -i "s/^listen =.*/listen = \/run\/php\/php7.3-fpm_${NEXT_USER}.sock/g" ${CONF_FILE}

# APACHE
CONF_FILE="/etc/apache2/sites-available/${DOMAIN}.conf"

echo "<VirtualHost *:80>" > ${CONF_FILE}
echo "    ServerAdmin ${ADMIN_EMAIL}" >> ${CONF_FILE}
echo "    ServerName ${DOMAIN}" >> ${CONF_FILE}
echo "    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE" >> ${CONF_FILE}
if [ "${CREATE_ALIAS}" = "Y" ]
then
        echo "    ServerAlias www.${DOMAIN}" >> ${CONF_FILE}
fi
echo "    DocumentRoot /var/www/vhosts/${DOMAIN}/httpdocs/" >> ${CONF_FILE}
echo "    # ENABLE THE FOLLOWING LINES TO FORCE REDIRECT TO HTTPS" >> ${CONF_FILE}
echo "    # RewriteEngine On" >> ${CONF_FILE}
echo "    # RewriteCond %{HTTPS} off" >> ${CONF_FILE}
echo "    # RewriteRule (.*) https://%{SERVER_NAME}/$1 [R,L]" >> ${CONF_FILE}
echo "    <Directory /var/www/vhosts/${DOMAIN}/httpdocs>" >> ${CONF_FILE}
echo "        Options FollowSymLinks" >> ${CONF_FILE}
echo "        AllowOverride All" >> ${CONF_FILE}
echo "        Allow from All" >> ${CONF_FILE}
echo "    </Directory>" >> ${CONF_FILE}
echo "    <FilesMatch \".+\.ph(ar|p|tml)$\">" >> ${CONF_FILE}
echo "        SetHandler \"proxy:unix:/run/php/php7.3-fpm_${NEXT_USER}.sock|fcgi://localhost\"" >> ${CONF_FILE}
echo "    </FilesMatch>" >> ${CONF_FILE}
echo "    ErrorLog /var/www/vhosts/${DOMAIN}/logs/error.log" >> ${CONF_FILE}
echo "    CustomLog /var/www/vhosts/${DOMAIN}/logs/access.log combined" >> ${CONF_FILE}
echo "</VirtualHost>" >> ${CONF_FILE}
echo "" >> ${CONF_FILE}
echo "<VirtualHost *:443>" >> ${CONF_FILE}
echo "    ServerAdmin ${ADMIN_EMAIL}" >> ${CONF_FILE}
echo "    ServerName ${DOMAIN}" >> ${CONF_FILE}
echo "    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE" >> ${CONF_FILE}
if [ "${CREATE_ALIAS}" = "Y" ]
then
        echo "    ServerAlias www.${DOMAIN}" >> ${CONF_FILE}
fi
echo "    DocumentRoot /var/www/vhosts/${DOMAIN}/httpdocs/" >> ${CONF_FILE}
echo "    <Directory /var/www/vhosts/${DOMAIN}/httpdocs>" >> ${CONF_FILE}
echo "        Options FollowSymLinks" >> ${CONF_FILE}
echo "        AllowOverride All" >> ${CONF_FILE}
echo "        Allow from All" >> ${CONF_FILE}
echo "    </Directory>" >> ${CONF_FILE}
echo "    <FilesMatch \".+\.ph(ar|p|tml)$\">" >> ${CONF_FILE}
echo "        SetHandler \"proxy:unix:/run/php/php7.3-fpm_${NEXT_USER}.sock|fcgi://localhost\"" >> ${CONF_FILE}
echo "    </FilesMatch>" >> ${CONF_FILE}
echo "    SSLEngine on" >> ${CONF_FILE}
echo "    SSLCertificateFile     /etc/ssl/certs/ssl-cert-snakeoil.pem" >> ${CONF_FILE}
echo "    SSLCertificateKeyFile  /etc/ssl/private/ssl-cert-snakeoil.key" >> ${CONF_FILE}
echo "    #SSLCertificateChainFile /path/to/chain.pem" >> ${CONF_FILE}
echo "    Protocols h2 http/1.1" >> ${CONF_FILE}
echo "    <FilesMatch \"\.(cgi|shtml|phtml|php)$\">" >> ${CONF_FILE}
echo "        SSLOptions +StdEnvVars" >> ${CONF_FILE}
echo "    </FilesMatch>" >> ${CONF_FILE}
echo "    ErrorLog /var/www/vhosts/${DOMAIN}/logs/error.log" >> ${CONF_FILE}
echo "    CustomLog /var/www/vhosts/${DOMAIN}/logs/access.log combined" >> ${CONF_FILE}
echo "</VirtualHost>" >> ${CONF_FILE}

echo "<?php echo '${DOMAIN}'; ?>" > /var/www/vhosts/${DOMAIN}/httpdocs/index.php
chown ${NEXT_USER}:${NEXT_USER} /var/www/vhosts/${DOMAIN}/httpdocs/index.php

a2ensite ${DOMAIN} 2> /dev/null
/etc/init.d/php7.3-fpm restart
/etc/init.d/apache2 reload > /dev/null

echo ""
echo "==================================================="
echo "SFTP DATA"
echo "==================================================="
echo "DOMAIN: ${DOMAIN}"
echo "USER: ${NEXT_USER}"
echo "PASS: ${PASSWORD}"
echo "HOME: /var/www/vhosts/${DOMAIN}"
echo "PORT: 22"
echo "HOST: $(curl -s ifconfig.me)"
echo "PHPMYADMIN: https://${DOMAIN}/phpmyadmin"
echo "==================================================="
