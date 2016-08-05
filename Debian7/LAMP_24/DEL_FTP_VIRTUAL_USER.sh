#!/bin/bash
set -e
if [ $# -lt 1 ]; then
        echo "USAGE: ${0} USER_ALIAS"
        echo "Example: ${0} usernameit_v1"
        exit 0
fi
USERALIAS="${1}"

if [ ! -e /etc/vsftpd/users/${USERALIAS} ]
then
	echo "ERROR: USER ${USERALIAS} DOES NOT EXISTS"
	exit 1
fi

RES=$(echo ${USERALIAS} | egrep "_v[0-9]+$" || true)
if [ -z "${RES}" ]
then
	echo "ERROR: ${USERALIAS} IS NOT A VIRTUAL USER"
	exit 1
fi

sed -i "/^${USERALIAS}$/d" /etc/vsftpd.user_list
htpasswd -D /etc/vsftpd/passwd ${USERALIAS} &> /dev/null
rm -f /etc/vsftpd/users/${USERALIAS}

echo ""
echo "VIRTUAL USER ${USERALIAS} REMOVED"
echo ""
