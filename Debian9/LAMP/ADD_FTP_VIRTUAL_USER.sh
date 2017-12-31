#!/bin/bash
set -e
CHROOTPATH=${1}
PASSWORD="$(apg -n 1 -m 8 -d)"

if [ $# -lt 1 ]; then
        echo "USAGE: ${0} SECIFIC_ABSOLUTE_PATH"
	echo "Example: ${0} /var/www/vhosts/mysite.com/httpdocs/mydirectory/test"
        exit 0
fi

if [ ! -d ${CHROOTPATH} ]
then
	echo "ERROR: PATH ${CHROOTPATH} DOES NOT EXISTS OR IT IS NOT A DIRECTORY!"
	exit 1
fi
DOMAIN_PATH=$(echo ${CHROOTPATH} | egrep "\/var\/www\/vhosts\/[0-9a-z.-]+\/")
if [ -z "${DOMAIN_PATH}" ]
then
	echo "ERROR: PATH ${CHROOTPATH} IS NOT INSIDE /var/www/vhosts/DOMAIN.TLD"
	exit 1
fi
DOMAIN=$(echo ${CHROOTPATH} | awk -F'/' '{print $5}')

DOMAINUSER="${DOMAIN}"
if echo "${DOMAIN}" | egrep -q "^[0-9]+"
then
        DOMAINUSER="a${DOMAIN}"
fi
DOMAINUSER=$(echo ${DOMAINUSER} | sed "{s/[.-]//g}")
FTP_NUMBER=$(ls /etc/vsftpd/users/${DOMAINUSER}* | wc -l)

htpasswd -d -b /etc/vsftpd/passwd ${DOMAINUSER}_v${FTP_NUMBER} ${PASSWORD} &> /dev/null
echo "guest_username=${DOMAINUSER}" > /etc/vsftpd/users/${DOMAINUSER}_v${FTP_NUMBER}
echo "local_root=${CHROOTPATH}" >> /etc/vsftpd/users/${DOMAINUSER}_v${FTP_NUMBER}

echo ""
echo "FTP VIRTUAL USER: ${DOMAINUSER}_v${FTP_NUMBER}"
echo "FTP VIRTUAL PASS: ${PASSWORD}"
echo "FTP VIRTUAL PATH: ${CHROOTPATH}"
echo "FTP DOMAIN: ${DOMAIN}"
echo ""
