#!/bin/bash
set -e

DOMAIN="${1}"
BASE_ROOT="/var/www"
DB_DOMAINS="/root/domains"

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
echo "${DOMAIN}:${NEW_UID}" > ${DB_DOMAINS}
useradd --comment="WEB_USER_${NEW_UID},,," --home-dir=${BASE_ROOT}/${DOMAIN} --no-log-init --create-home --shell=/bin/false --uid=${NEW_UID} web${NEW_UID}

# Make sure to have the folder for php pools
mkdir -p /var/run/php5-fpm

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
sed -i "{s#^listen = .*.sock#listen = /var/run/php5-fpm/${DOMAIN}.sock#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;chroot =.*#chroot = ${BASE_ROOT}/${DOMAIN}/public_html#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TMP\] =.*#env[TMP] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TMPDIR\] =.*#env[TMPDIR] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf
sed -i "{s#^;env\[TEMP\] =.*#env[TEMP] = ${BASE_ROOT}/${DOMAIN}/tmp#g}" /etc/php5/fpm/pool.d/${DOMAIN}.conf

service php5-fpm restart

# Write NGINX configuration for domain
cat << EOF > /etc/nginx/sites-available/${DOMAIN}
server {
 listen       80;
 server_name  www.${DOMAIN} ${DOMAIN};
 access_log   ${BASE_ROOT}/${DOMAIN}/logs/nginx.access.log;
 error_log    ${BASE_ROOT}/${DOMAIN}/logs/nginx.error.log;

 location / {
    proxy_pass         http://127.0.0.1:8080/;
    proxy_redirect     off;
    proxy_set_header   Host             \$host;
    proxy_set_header   X-Real-IP        \$remote_addr;
    proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
    client_max_body_size       10m;
    client_body_buffer_size    128k;
    proxy_connect_timeout      90;
    proxy_send_timeout         90;
    proxy_read_timeout         90;
    proxy_buffer_size          4k;
    proxy_buffers               4 32k;
    proxy_busy_buffers_size     64k;
    proxy_temp_file_write_size 64k;
  }

  # PHPMYADMIN
  location /phpmyadmin {
    root /usr/share/;
    index index.php index.html index.htm;
    location ~ ^/phpmyadmin/(.+\.php)\$ {
      try_files \$uri =404;
      root /usr/share/;
      fastcgi_pass unix:/var/run/php5-fpm.sock;
      fastcgi_index index.php;
      include fastcgi_params;
    }
    location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))\$ {
      root /usr/share/;
      expires 7d;
    }
  }
  location /phpMyAdmin {
    rewrite ^/* /phpmyadmin last;
  }

  location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)\$ {
    root ${BASE_ROOT}/${DOMAIN}/public_html;
    access_log off;
    log_not_found off;
    expires 7d;
  }
}
EOF

# Write Apache2 configuration for domain
cat << EOF > /etc/apache2/sites-available/${DOMAIN}
<VirtualHost *:8080>
    ServerAdmin info@${DOMAIN}
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DirectoryIndex index.html, index.php

    DocumentRoot ${BASE_ROOT}/${DOMAIN}/public_html
    <Directory />
        Options FollowSymLinks
        AllowOverride All
    </Directory>
    <Directory ${BASE_ROOT}/${DOMAIN}/public_html>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Directory "/usr/lib/cgi-bin">
            AllowOverride All
            Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
            Order allow,deny
            Allow from all
    </Directory>

    LogLevel warn
    ErrorLog ${BASE_ROOT}/${DOMAIN}/logs/apache.error.log
    CustomLog ${BASE_ROOT}/${DOMAIN}/logs/apache.access.log combined

    <IfModule mod_fastcgi.c>
        AddHandler php5-fcgi .php
        Action php5-fcgi /php5-fcgi
        Alias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi_${DOMAIN}
        FastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi_${DOMAIN} -socket /var/run/php5-fpm_${DOMAIN}.sock -pass-header Authorization
    </IfModule>
</VirtualHost>
EOF

cd /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/${DOMAIN} .
cd /etc/apache2/sites-enabled
ln -s /etc/apache2/sites-available/${DOMAIN} .
service nginx reload
service apache2 reload

echo "Domain ${DOMAIN} successfully added"
