#!/bin/bash

set -e

DOMAIN=${1}

if [ $# -lt 1 ]; then
    echo "USAGE: ${0} DOMAIN.TLD"
    exit 1
fi

if [ ! -d /var/www/vhosts/${DOMAIN} ]
then
    echo "DOCUMENT ROOT /var/www/vhosts/${DOMAIN} NOT PRESENT!"
    exit 1
fi

if grep -q "^${DOMAIN}" /root/dehydrated/domains.txt
then
    echo "CERTIFICATE ALREADY REQUESTED FOR ${DOMAIN}"
    exit 1
fi

if [ -d "/root/dehydrated/certs/${DOMAIN}" ]
then
    echo "CERTIFICATE ALREADY INSTALLED FOR ${DOMAIN}"
    exit 1
fi

if grep -q "VirtualHost.*443" /etc/apache2/sites-enabled/${DOMAIN}.conf
then
    echo "VIRTUALHOST ALREADY CONFIGURED FOR SSL FOR ${DOMAIN}"
    exit 1
fi

# OBTAIN CERTIFICATES
ALIASES=$(grep "ServerAlias" /etc/apache2/sites-enabled/${DOMAIN}.conf | awk '{print $2}' | xargs)
echo "${DOMAIN} ${ALIASES}" >> /root/dehydrated/domains.txt
cd /root/dehydrated
/root/dehydrated/dehydrated -c

cp /etc/apache2/sites-enabled/${DOMAIN}.conf /tmp/backup_vhost
cp /etc/varnish/default.vcl /tmp/backup_default.vcl

cat << EOF >> /etc/apache2/sites-enabled/${DOMAIN}.conf

<VirtualHost *:443>
    ServerAdmin info@altrosito.it
    ServerName ${DOMAIN}
    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE
EOF
for a in ${ALIASES}
do
    echo "    ServerAlias ${a}" >> /etc/apache2/sites-enabled/${DOMAIN}.conf
done
cat << EOF >> /etc/apache2/sites-enabled/${DOMAIN}.conf

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:80/
    ProxyPassReverse / http://127.0.0.1:80/
    RequestHeader set X-Forwarded-Port "443"
    RequestHeader set X-Forwarded-Proto "https"

    SSLEngine on
    SSLCertificateFile       /root/dehydrated/certs/${DOMAIN}/cert.pem
    SSLCertificateKeyFile    /root/dehydrated/certs/${DOMAIN}/privkey.pem
    SSLCertificateChainFile  /root/dehydrated/certs/${DOMAIN}/chain.pem

    <FilesMatch "\.(cgi|shtml|phtml|php)\$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>

    BrowserMatch "MSIE [2-6]" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0

    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>
EOF

apachectl configtest 2> /dev/null || :
if [ ${?} -ne 0 ]
then
    echo "ERROR SETTING UP VIRTUALHOST CONFIGURATION!!!"
    cp /tmp/backup_vhost /etc/apache2/sites-enabled/${DOMAIN}.conf
    exit 1
fi

sed -i "s@# ENSURE HTTPS - DO NOT REMOVE THIS LINE@# ENSURE HTTPS - DO NOT REMOVE THIS LINE\n         \|\| \(req.http.host ~ \"^\(\?i\)\(www\\\\.\)\?${DOMAIN}\"\)@g" /etc/varnish/default.vcl

varnishd -C -f /etc/varnish/default.vcl > /dev/null 2>&1 || :
if [ ${?} -ne 0 ]
then
    echo "ERROR SETTING UP VARNISH CONFIGURATION!!!"
    cp /tmp/backup_vhost /etc/apache2/sites-enabled/${DOMAIN}.conf
    cp /tmp/backup_default.vcl /etc/varnish/default.vcl
    exit 1
fi

/etc/init.d/apache2 reload > /dev/null
/etc/init.d/varnish reload > /dev/null

rm -f /tmp/backup_vhost
rm -f /tmp/backup_default.vcl

echo "DONE"
