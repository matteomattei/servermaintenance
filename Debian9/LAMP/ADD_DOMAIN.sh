#!/bin/bash
set -e
ADMIN_EMAIL="info@yourdomain.com"
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

CREATE_ALIAS=""
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
setfacl -m "u:${DOMAINUSER}:r-x" /var/www/vhosts/${DOMAIN}
setfacl -m "u:www-data:--x" /var/www/vhosts/${DOMAIN}
chmod 750 /var/www/vhosts/${DOMAIN}

echo ${DOMAINUSER} >> /etc/vsftpd.user_list
echo "guest_username=${DOMAINUSER}" > /etc/vsftpd/users/${DOMAINUSER}
echo "local_root=/var/www/vhosts/${DOMAIN}" >> /etc/vsftpd/users/${DOMAINUSER}

CONF_FILE="/etc/apache2/sites-available/${DOMAIN}.conf"

echo "<VirtualHost *:8080>" > ${CONF_FILE}
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
echo "    ErrorLog /var/www/vhosts/${DOMAIN}/logs/error.log" >> ${CONF_FILE}
echo "    CustomLog /var/www/vhosts/${DOMAIN}/logs/access.log combined" >> ${CONF_FILE}
echo "</VirtualHost>" >> ${CONF_FILE}

a2ensite ${DOMAIN} > /dev/null
/etc/init.d/apache2 reload > /dev/null
/etc/init.d/vsftpd reload > /dev/null

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
