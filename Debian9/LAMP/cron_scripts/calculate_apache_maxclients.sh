#!/bin/bash

TOTAL_MEMORY=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
MYSQL_MEMORY=$(ps aux | grep mysql | grep -v "grep" | awk '{print $6}' | sort | head -n 1)
APACHE_MEMORY_PROCESSES=$(ps aux | grep 'apache2' | grep -v "grep" | awk '{print $6}' | sort)

APACHE_INSTANCES=0
APACHE_TOTAL_MEMORY=0
for i in ${APACHE_MEMORY_PROCESSES}
do
        APACHE_TOTAL_MEMORY=$(( ${APACHE_TOTAL_MEMORY} + ${i} ))
        APACHE_INSTANCES=$(( ${APACHE_INSTANCES} + 1 ))
done
APACHE_MEMORY=$(( ${APACHE_TOTAL_MEMORY} / ${APACHE_INSTANCES} ))

TOTAL_MEMORY_MB=$(( ${TOTAL_MEMORY} / 1024 ))
APACHE_MEMORY_MB=$(( ${APACHE_MEMORY} / 1024 ))
LEFT_MEMORY=0
if [ ! -z "${MYSQL_MEMORY}" ]; then
        MYSQL_MEMORY_MB=$(( ${MYSQL_MEMORY} / 1024 ))
        LEFT_MEMORY=$(( ${TOTAL_MEMORY_MB} - ${MYSQL_MEMORY_MB} - 50 ))
else
        LEFT_MEMORY=$(( ${TOTAL_MEMORY_MB} - 50 ))
fi

MAX_CLIENTS=$(( ${LEFT_MEMORY} / ${APACHE_MEMORY_MB} ))

echo "MaxClients="${MAX_CLIENTS}
