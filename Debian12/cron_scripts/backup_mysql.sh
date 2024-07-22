#!/bin/bash

MAIL_NOTIFICATION="info@yourdomain.com"
BACKUP_FOLDER="/root/mysql_backup"
NUM_COPIES=7

NOW=$(date +%F_%T)

for db in $(mysql -e 'show databases;' | grep -Ev "^(Database|mysql|information_schema|performance_schema|phpmyadmin)$" || true)
do
	echo "processing ${db}"
	[ -d "${BACKUP_FOLDER}/${db}" ] || mkdir -p "${BACKUP_FOLDER}/${db}"
	cd "${BACKUP_FOLDER}/${db}"
	mysqldump --opt "${db}" > dump_${NOW}.sql || mail -s "error backing up database ${db}" ${MAIL_NOTIFICATION}
	gzip dump_${NOW}.sql || mail -s "error compressing database ${db}" ${MAIL_NOTIFICATION}
	while [ `ls dump_*.gz | wc -l` -gt ${NUM_COPIES} ]
	do
		FIRST=`ls -t dump_*.gz | tail -n1`
		rm -f "${FIRST}"
	done
done

mkdir -p ${BACKUP_FOLDER}/ALL_DATABASES
cd ${BACKUP_FOLDER}/ALL_DATABASES
mysqldump --opt --events --ignore-table=mysql.event --all-databases > all_${NOW}.sql || mail -s "error backing up all databases" ${MAIL_NOTIFICATION}
gzip all_${NOW}.sql || mail -s "error compressing all databases" ${MAIL_NOTIFICATION}
while [ `ls all_*.gz | wc -l` -gt ${NUM_COPIES} ]
do
	FIRST=`ls -t all_*.gz | tail -n1`
	rm -f "${FIRST}"
done
