#!/bin/bash
set -e
DOMAIN=${1}

if [ -z "${DOMAIN}" ]; then
        echo "USAGE: ${0} DOMAIN.TLD"
        exit 1
fi
if [ ! -d /var/www/vhosts/${DOMAIN} ]
then
        echo "DOMAIN NOT PRESENT!"
        exit 1
fi

USER=$(stat --print=%U /var/www/vhosts/${DOMAIN}/httpdocs)
if [ -z "${USER}" ]
then
        echo "User does not exist!"
        exit 1
fi

rm -f /etc/php/7.3/fpm/pool.d/${USER}.conf
rm -f /etc/apache2/sites-enabled/${DOMAIN}.conf
rm -f /etc/apache2/sites-available/${DOMAIN}.conf
userdel -f -r ${USER}
rm -rf /var/www/vhosts/${DOMAIN}

/etc/init.d/php7.3-fpm restart
/etc/init.d/apache2 reload

echo "================================================================"
echo "DOMAIN ${DOMAIN} removed"
echo "USER ${USER} removed"
echo "Remember: check if there are some certificates to remove as well"
echo "================================================================"
