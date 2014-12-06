#!/bin/bash
set -e
if [ ! $# = 2 ]; then
	echo "USAGE ${0} DOMAIN.TLD ALIAS_TO_REMOVE.TLD"
	exit 1
fi

DOMAIN=${1}
ALIAS=${2}

if [ ! -f /etc/apache2/sites-available/${DOMAIN} ]
then
	echo "Error: domain file /etc/apache2/sites-available/${DOMAIN} does not exist!"
	exit 1
fi

if ! grep -q "ServerAlias ${ALIAS}" /etc/apache2/sites-available/${DOMAIN}
then
	echo "Error: alias ${ALIAS} not present in /etc/apache2/sites-available/${DOMAIN}"
	exit 1
fi
grep -v "ServerAlias ${ALIAS}" /etc/apache2/sites-available/${DOMAIN} > /etc/apache2/sites-available/${DOMAIN}.mod
mv /etc/apache2/sites-available/${DOMAIN}.mod /etc/apache2/sites-available/${DOMAIN}

/etc/init.d/apache2 reload

echo ""
echo "ALIAS ${ALIAS} REMOVED FROM ${DOMAIN}"
echo ""
