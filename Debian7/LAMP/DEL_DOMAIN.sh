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
DOMAINUSER="${DOMAIN}"
if echo "${DOMAIN}" | egrep -q "^[0-9]+"
then
        DOMAINUSER="a${DOMAIN}"
fi
DOMAINUSER=$(echo ${DOMAINUSER} | sed "{s/[.-]//g}")
if ! grep -q "^${DOMAINUSER}:" /etc/passwd
then
	echo "NO USER ${DOMAINUSER} FOUND"
	exit 1
fi

rm -rf /var/www/vhosts/${DOMAIN}
rm -f /etc/apache2/sites-enabled/${DOMAIN}
rm -f /etc/apache2/sites-available/${DOMAIN}
userdel ${DOMAINUSER}
sed -i "/^${DOMAINUSER}$/d" /etc/vsftpd.user_list

for i in $(ls /etc/vsftpd/users/${DOMAINUSER}*)
do
	NAME=$(basename ${i})
	/root/DEL_FTP_VIRTUAL_USER.sh ${NAME} &> /dev/null
done
rm -f /etc/vsftpd/users/${DOMAINUSER}

/etc/init.d/apache2 reload > /dev/null
/etc/init.d/vsftpd restart > /dev/null

echo ""
echo "DOMAIN ${DOMAIN} REMOVED"
echo ""
