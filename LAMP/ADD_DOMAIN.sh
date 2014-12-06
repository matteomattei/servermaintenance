#!/bin/bash
set -e

DOMAIN=${1}
FTP_PASSWORD="$(apg -n 1 -m 8 -d)"

if [ $# -lt 1 ]; then
        echo "USAGE: ${0} DOMAIN.TLD"
        exit 1
fi

if [ -d /var/www/vhosts/${DOMAIN} ]
then
        echo "DOMAIN ALREADY PRESENT!"
        exit 1
fi

DOMAINUSER="${DOMAIN}"
if echo "${DOMAIN}" | egrep -q "^[0-9]+"
then
        DOMAINUSER="a${DOMAIN}"
fi
DOMAINUSER=$(echo ${DOMAINUSER} | sed "{s/[.-]//g}")
mkdir -p /var/www/vhosts/${DOMAIN}/{httpdocs,logs}
useradd --home-dir=/var/www/vhosts/${DOMAIN} --gid=www-data --no-create-home --no-user-group --shell=/bin/false ${DOMAINUSER}
echo ${DOMAINUSER}:"${FTP_PASSWORD}" | chpasswd
chown -R ${DOMAINUSER}.www-data -R /var/www/vhosts/${DOMAIN}/httpdocs
chmod 750 /var/www/vhosts/${DOMAIN}/httpdocs

echo ${DOMAINUSER} >> /etc/vsftpd.user_list
echo "guest_username=${DOMAINUSER}" > /etc/vsftpd/users/${DOMAINUSER}
echo "local_root=/var/www/vhosts/${DOMAIN}" >> /etc/vsftpd/users/${DOMAINUSER}

CONF_FILE="/etc/apache2/sites-available/${DOMAIN}"

echo "<VirtualHost *:8080>" > ${CONF_FILE}
echo "    ServerAdmin info@altrosito.it" >> ${CONF_FILE}
echo "    ServerName ${DOMAIN}" >> ${CONF_FILE}
echo "    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE" >> ${CONF_FILE}
echo "    ServerAlias www.${DOMAIN}" >> ${CONF_FILE}
echo "    DocumentRoot /var/www/vhosts/${DOMAIN}/httpdocs/" >> ${CONF_FILE}
echo "    <Directory /var/www/vhosts/${DOMAIN}/httpdocs>" >> ${CONF_FILE}
echo "        Options FollowSymLinks" >> ${CONF_FILE}
echo "        AllowOverride All" >> ${CONF_FILE}
echo "        Allow from All" >> ${CONF_FILE}
echo "    </Directory>" >> ${CONF_FILE}
echo "    ErrorLog /var/www/vhosts/${DOMAIN}/logs/error.log" >> ${CONF_FILE}
echo "    CustomLog /var/www/vhosts/${DOMAIN}/logs/access.log combined" >> ${CONF_FILE}
echo "</VirtualHost>" >> ${CONF_FILE}

a2ensite ${DOMAIN} > /dev/null
/etc/init.d/apache2 restart > /dev/null
/etc/init.d/vsftpd restart > /dev/null

echo ""
echo "**********************************"
echo "FTP DATA"
echo "**********************************"
echo "DOMAIN: ${DOMAIN}"
echo "USER: ${DOMAINUSER}"
echo "PASS: ${FTP_PASSWORD}"
echo "PORT: 21"
echo "PHPMYADMIN: http://${DOMAIN}/phpmyadmin"
echo ""
