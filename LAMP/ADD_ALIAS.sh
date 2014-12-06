#!/bin/bash
set -e
if [ ! $# = 2 ]; then
	echo "USAGE ${0} DOMAIN.TLD NEWALIAS.TLD"
	exit 1
fi

DOMAIN=${1}
ALIAS=${2}

sed -i "{s%^    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE$%    #ALIAS DO-NOT-REMOVE-OR-ALTER-THIS-LINE\n    ServerAlias ${ALIAS}%g}" /etc/apache2/sites-available/${DOMAIN}

/etc/init.d/apache2 restart

echo ""
echo "ALIAS ${ALIAS} ADDED TO ${DOMAIN}"
echo ""
