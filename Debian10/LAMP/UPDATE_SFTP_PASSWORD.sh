#!/bin/bash
set -e

USERNAME="${1}"
SFTP_PASSWORD="$(pwgen 10 1)"

if [ ! $# = 1 ]; then
        echo "USAGE: ${0} USER"
        exit 1
fi
if ! grep -q "^${USERNAME}$" /etc/passwd
then
        echo "USER ${USERNAME} NOT PRESENT"
        exit 1
fi
echo "${USERNAME}:${SFTP_PASSWORD}" | chpasswd

echo ""
echo "SFTP USER: ${USERNAME}"
echo "SFTP PASSWORD: ${SFTP_PASSWORD}"
echo ""
