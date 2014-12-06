#!/bin/bash
set -e

USERNAME="${1}"
FTP_PASSWORD="$(apg -n 1 -m 8 -d)"

if [ ! $# = 1 ]; then
        echo "USAGE: ${0} USER"
        exit 1
fi
if ! grep -q "^${USERNAME}$" /etc/vsftpd.user_list
then
	echo "USER ${USERNAME} NOT PRESENT"
	exit 1
fi
echo ${USERNAME}:"${FTP_PASSWORD}" | chpasswd
/etc/init.d/vsftpd reload

echo ""
echo "FTP USER: ${USERNAME}"
echo "FTP PASSWORD: ${FTP_PASSWORD}"
echo ""
