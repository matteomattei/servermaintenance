#!/bin/bash
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="yourrootpassword"

mysqlcheck -Aos -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} > /dev/null 2>&1
