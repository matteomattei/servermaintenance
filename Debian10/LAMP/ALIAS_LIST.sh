#!/bin/bash
set -e
if [ -z "${1}" ]; then
	echo "USAGE: ${0} DOMAIN.TLD"
	exit 1
fi

DOMAIN=${1}
if [ ! -f /etc/apache2/sites-available/${DOMAIN}.conf ]; then
	echo "DOMAIN ${DOMAIN} DOES NOT EXISTS"
	exit 1
fi

egrep "ServerAlias" /etc/apache2/sites-available/${DOMAIN}.conf | egrep -v "www\.${DOMAIN}" | awk '{print $2}'
