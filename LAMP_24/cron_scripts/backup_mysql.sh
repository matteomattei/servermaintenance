#!/bin/bash

DB_USER="root"
DB_PASSWORD="yourrootpassword"
MAIL_NOTIFICATION="matteo.mattei@gmail.com"
BACKUP_FOLDER="/root/mysql_backup"
NUM_COPIES=7

for db in $(mysql -u${DB_USER} -p${DB_PASSWORD} -e 'show databases;' | grep -Ev "^(Database|mysql|information_schema|performance_schema|phpmyadmin)$" || true)
do
	echo "processing ${db}"
	[ -d "${BACKUP_FOLDER}/${db}" ] || mkdir -p "${BACKUP_FOLDER}/${db}"
	cd "${BACKUP_FOLDER}/${db}"
	NOW=$(date +%F_%T)
	mysqldump --opt -u${DB_USER} -p${DB_PASSWORD} "${db}" > dump_${NOW}.sql || mail -s "error backing up database ${db}" ${MAIL_NOTIFICATION}
	gzip dump_${NOW}.sql || mail -s "error compressing database ${db}" ${MAIL_NOTIFICATION}
	while [ `ls dump_*.gz | wc -l` -gt ${NUM_COPIES} ]
	do
		FIRST=`ls -t dump_*.gz | tail -n1`
		rm -f "${FIRST}"
	done
done

mkdir -p ${BACKUP_FOLDER}/ALL_DATABASES
cd ${BACKUP_FOLDER}/ALL_DATABASES
NOW=$(date +%F_%T)
mysqldump --opt -u${DB_USER} -p${DB_PASSWORD} --events --ignore-table=mysql.event --all-databases > all_${NOW}.sql || mail -s "error backing up all databases" ${MAIL_NOTIFICATION}
gzip all_${NOW}.sql || mail -s "error compressing all databases" ${MAIL_NOTIFICATION}
while [ `ls all_*.gz | wc -l` -gt ${NUM_COPIES} ]
do
	FIRST=`ls -t all_*.gz | tail -n1`
	rm -f "${FIRST}"
done
