#!/bin/bash
#
# Backup your server on mega.co.nz with megatools
# Author: Matteo Mattei <info@matteomattei.com>
# Copyright 2016 - Matteo Mattei

SERVER="servername"
DAYS_TO_BACKUP=7:
WORKING_DIR="/root/backup_tmp_dir"

BACKUP_MYSQL="true"
MYSQL_USER="root"
MYSQL_PASSWORD="MyRootPassword"

DOMAINS_FOLDER="/var/www"

##################################
# Create local working directory and collect all data
rm -rf ${WORKING_DIR}
mkdir ${WORKING_DIR}
cd ${WORKING_DIR}

# Backup /etc folder
cd /
tar cJpf ${WORKING_DIR}/etc.tar.xz etc
cd - > /dev/null

# Backup MySQL
if [ "${BACKUP_MYSQL}" = "true" ]
then
        mkdir ${WORKING_DIR}/mysql
        for db in $(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'show databases;' | grep -Ev "^(Database|mysql|information_schema|performance_schema|phpmyadmin)$")
        do
                #echo "processing ${db}"
                mysqldump --opt -u${MYSQL_USER} -p${MYSQL_PASSWORD} "${db}" | gzip > ${WORKING_DIR}/mysql/${db}_$(date +%F_%T).sql.gz
        done
        #echo "all db now"
        mysqldump --opt -u${MYSQL_USER} -p${MYSQL_PASSWORD} --events --ignore-table=mysql.event --all-databases | gzip > ${WORKING_DIR}/mysql/ALL_DATABASES_$(date +%F_%T).sql.gz
fi

cp /root/domains.txt ${WORKING_DIR}/domains.txt

# Backup domains
mkdir ${WORKING_DIR}/domains
for folder in $(find ${DOMAINS_FOLDER} -mindepth 1 -maxdepth 1 -type d)
do
        cd $(dirname ${folder})
        tar cJpf ${WORKING_DIR}/domains/$(basename ${folder}).tar.xz $(basename ${folder}) --warning=no-file-changed --ignore-failed-read
        cd - > /dev/null
done

# Create base backup folder
[ -z "$(megals --reload /Root/backup_${SERVER})" ] && megamkdir /Root/backup_${SERVER}

# Remove old logs
while [ $(megals --reload /Root/backup_${SERVER} | grep -E "/Root/backup_${SERVER}/[0-9]{4}-[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${DAYS_TO_BACKUP} ]
do
        TO_REMOVE=$(megals --reload /Root/backup_${SERVER} | grep -E "/Root/backup_${SERVER}/[0-9]{4}-[0-9]{2}-[0-9]{2}$" | sort | head -n 1)
        megarm ${TO_REMOVE}
done

# Create remote folder
curday=$(date +%F)
megamkdir /Root/backup_${SERVER}/${curday} 2> /dev/null

# Backup now!!!
megacopy --reload --no-progress --disable-previews -l ${WORKING_DIR} -r /Root/backup_${SERVER}/${curday} > /dev/null

# Clean local environment
rm -rf ${WORKING_DIR}
exit 0
