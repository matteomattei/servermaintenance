#!/bin/bash
set -e
for i in $(find /var/www/vhosts/ -mindepth 1 -maxdepth 1 -type d); do
	DOMAIN=$(basename ${i})
	echo ${DOMAIN}
done
