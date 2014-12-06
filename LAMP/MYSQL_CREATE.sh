#!/bin/bash
set -e
MYSQL_ROOT_PASSWORD="yourrootpassword"
MYSQL_ROOT_USER="root"

DB_NAME="${1}"
USERNAME="${2}"
PASSWORD="${3}"

if [ $# -lt 3 ]; then
        echo "USAGE: ${0} DB_NAME DB_USERNAME DB_PASSWORD"
        exit 1
fi

mysql -u${MYSQL_ROOT_USER} -hlocalhost -p${MYSQL_ROOT_PASSWORD} -e " \
CREATE USER '${USERNAME}'@'localhost' IDENTIFIED BY  '${PASSWORD}'; \
GRANT USAGE ON * . * TO  '${USERNAME}'@'localhost' IDENTIFIED BY  '${PASSWORD}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ; \
CREATE DATABASE IF NOT EXISTS  \`${DB_NAME}\` ; \
GRANT ALL PRIVILEGES ON  \`${DB_NAME}\` . * TO  '${USERNAME}'@'localhost'; \
"

echo ""
echo "**********************************"
echo "MYSQL DATA"
echo "**********************************"
echo "DB_NAME: ${DB_NAME}"
echo "DB_USER: ${USERNAME}"
echo "DB_PASS: ${PASSWORD}"
echo ""

