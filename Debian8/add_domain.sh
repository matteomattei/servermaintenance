#!/bin/bash
set -e

DOMAIN="${1}"
BASE_ROOT="/var/www"
DB_DOMAINS="/root/domains"
DB_PASSWORD=""
DB_USER="root"

if [ -z "${DOMAIN}" ]; then
	echo "Please specify a domain (without www)"
	exit 1
fi

if [ -d "${BASE_ROOT}/${DOMAIN}" ]; then
	echo "Domain ${DOMIAN} alrady exist"
	exit 1
fi

if [ ! -f "${DB_DOMAINS}" ]; then
	NEW_UID=5000
else
	# read last UID
	LAST_UID=`tail -n1 "${DB_DOMAINS}" | awk -F':' '{print $2}'`
	if [ -z "${LAST_UID}" ]; then
		echo "${DB_DOMAINS} has a wrong format, please check"
		exit 1
	fi
	NEW_UID=$((${LAST_UID}+1))
fi
echo "${DOMAIN}:${NEW_UID}" >> ${DB_DOMAINS}
useradd --comment="WEB_USER_${NEW_UID},,," --home-dir=${BASE_ROOT}/${DOMAIN} --no-log-init --create-home --shell=/bin/bash --uid=${NEW_UID} web${NEW_UID}
passwd -l web${NEW_UID}

PASSWORD=$(pwgen 12 1)
echo "Do you need a database for this domain? [Yes|no]"
read answer
if [ -z "${answer}" -o "${answer}" = "yes" -o "${answer}" = "Yes" -o "${answer}" = "YES" ]; then
    mysql -u${DB_USER} -hlocalhost -p${DB_PASSWORD} -e " \
        CREATE USER 'web${NEW_UID}'@'localhost' IDENTIFIED BY  '${PASSWORD}'; \
        GRANT USAGE ON * . * TO  'web${NEW_UID}'@'localhost' IDENTIFIED BY  '${PASSWORD}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ; \
        CREATE DATABASE IF NOT EXISTS  \`web${NEW_UID}\` ; \
        GRANT ALL PRIVILEGES ON  \`web${NEW_UID}\` . * TO  'web${NEW_UID}'@'localhost';"
fi

# Create needed folders
mkdir -p ${BASE_ROOT}/${DOMAIN}/logs
mkdir -p ${BASE_ROOT}/${DOMAIN}/tmp
mkdir -p ${BASE_ROOT}/${DOMAIN}/public_html
chown -R web${NEW_UID}.web${NEW_UID} ${BASE_ROOT}/${DOMAIN}/public_html ${BASE_ROOT}/${DOMAIN}/tmp

# Write php pool configuration
cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^user = www-data#user = web${NEW_UID}#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^group = www-data#group = web${NEW_UID}#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^\[www\]#[${DOMAIN}]#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^listen = .*.sock#listen = /var/run/php5-fpm_${DOMAIN}.sock#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TMP\] =.*#env[TMP] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TMPDIR\] =.*#env[TMPDIR] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TEMP\] =.*#env[TEMP] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
#sed -i "{s#^;chroot =.*#chroot = ${BASE_ROOT}/${DOMAIN}/public_html#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf

service php5-fpm restart

# Write NGINX configuration for domain
cat << EOF > /etc/nginx/sites-available/${DOMAIN}
server {
    listen       80;
    server_name ${DOMAIN};
    return 301 \$scheme://www.${DOMAIN}\$request_uri;
}
server {
    server_name  www.${DOMAIN};
    access_log   ${BASE_ROOT}/${DOMAIN}/logs/nginx.access.log;
    error_log    ${BASE_ROOT}/${DOMAIN}/logs/nginx.error.log;
    root ${BASE_ROOT}/${DOMAIN}/public_html;
    #set \$php_sock_name ${DOMAIN};

    include /etc/nginx/global/common.conf;
    #include /etc/nginx/global/phpmyadmin.conf;
    #include /etc/nginx/global/wordpress.conf;
    #include /etc/nginx/global/dokuwiki.conf;
    #include /etc/nginx/global/plainphp.conf;
}
EOF

cd /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/${DOMAIN} .
service nginx reload

echo "Domain ${DOMAIN} successfully added"
if [ ! -z "${PASSWORD}" ]; then
    echo "DB NAME: web${NEW_UID}"
    echo "DB USER: web${NEW_UID}"
    echo "DB PASSWORD: ${PASSWORD}"
fi
