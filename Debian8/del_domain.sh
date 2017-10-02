#!/bin/bash

set -e

DOMAIN="${1}"
BASE_ROOT="/var/www"
DB_DOMAINS="/root/domains.txt"
DB_PASSWORD=""
DB_USER="root"

if [ -z "${DOMAIN}" ]; then
        echo "Please specify a domain (without www)"
        exit 1
fi

if [ ! -d "${BASE_ROOT}/${DOMAIN}" ]; then
        echo "Domain ${DOMIAN} does not exist"
        exit 1
fi

USER_ID=`grep "^${DOMAIN}:" ${DB_DOMAINS} | awk -F':' '{print $2}'`
if [ -z "${USER_ID}" ]; then
	echo "User ID for ${DOMAIN} does not exist"
	exit 1
fi

USER_ID="web${USER_ID}"

rm -rf ${BASE_ROOT}/${DOMAIN}
rm -f /etc/php5/fpm/pool.d/${DOMAIN}.conf
rm -f /etc/nginx/sites-available/${DOMAIN}
rm -f /etc/nginx/sites-enabled/${DOMAIN}
grep -v "^${DOMAIN}:" ${DB_DOMAINS} > ${DB_DOMAINS}.tmp; mv ${DB_DOMAINS}.tmp ${DB_DOMAINS}

service php5-fpm stop
service nginx stop

userdel -f -r ${USER_ID}

service php5-fpm start
service nginx start

mysql -u${DB_USER} -hlocalhost -p${DB_PASSWORD} -e " \
    DROP USER ${USER_ID}@localhost; \
    DROP DATABSE IF EXISTS ${USER_ID}; "

echo "Domain ${DOMAIN} successfully removed"
