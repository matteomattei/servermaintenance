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

if [ ! -f /etc/apache2/sites-enabled/${DOMAIN}.conf ]
then
    echo "VIRTUALHOST NOT PRESENT FOR ${DOMAIN}"
    exit 1
fi

# OBTAIN CERTIFICATES
ALIASES=$(grep "ServerAlias" /etc/apache2/sites-enabled/${DOMAIN}.conf | awk '{print $2}' | xargs)
echo "${DOMAIN} ${ALIASES}" >> /root/dehydrated/domains.txt
cd /root/dehydrated
/root/dehydrated/dehydrated -c

cp /etc/apache2/sites-enabled/${DOMAIN}.conf /tmp/backup_vhost

sed -i "s@SSLCertificateFile.*@SSLCertificateFile /root/dehydrated/certs/${DOMAIN}/cert.pem@g" /etc/apache2/sites-enabled/${DOMAIN}.conf
sed -i "s@SSLCertificateKeyFile.*@SSLCertificateKeyFile /root/dehydrated/certs/${DOMAIN}/privkey.pem@g" /etc/apache2/sites-enabled/${DOMAIN}.conf
sed -i "s@#SSLCertificateChainFile.*@/SSLCertificateChainFile root/dehydrated/certs/${DOMAIN}/chain.pem@g" /etc/apache2/sites-enabled/${DOMAIN}.conf

apachectl configtest 2> /dev/null || :
if [ ${?} -ne 0 ]
then
    echo "ERROR SETTING UP VIRTUALHOST CONFIGURATION!!!"
    cp /tmp/backup_vhost /etc/apache2/sites-enabled/${DOMAIN}.conf
    exit 1
fi

/etc/init.d/apache2 reload
rm -f /tmp/backup_vhost

echo "DONE"
