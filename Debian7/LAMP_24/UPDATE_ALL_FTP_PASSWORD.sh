#!/bin/bash
set -e

[ -f /root/ftp_password_backup.txt ] && rm -f /root/ftp_password_backup.txt
[ -f /root/ftp_password.txt ] && mv /root/ftp_password.txt /root/ftp_password_backup.txt

for USERNAME in $(cat /etc/vsftpd.user_list)
do
	FTP_PASSWORD="$(apg -n 1 -m 8 -d)"
	echo ${USERNAME}:"${FTP_PASSWORD}" | chpasswd
	echo -e ${USERNAME}"\t${FTP_PASSWORD}" >> /root/ftp_password.txt
done
/etc/init.d/vsftpd reload
chmod 640 /root/ftp_password.txt

echo ""
echo "FTP PASSWORDS UPDATED FOR ALL USERS"
echo "NEW FTP PASSWORDS LIST SAVED IN /root/ftp_password.txt"
echo ""
