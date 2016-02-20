#!/bin/bash
set -e
DOMAIN=${1}

if [ -z "${DOMAIN}" ]; then
    while true; do
        echo "Are you sure to clean varnish cache for all domains? [Y,n]"
        read res
        if [ "${res}" = "y" ] || [ "${res}" = "Y" ]; then
            varnishadm "ban.url ."
            echo "Varnish cache cleaned for all domains"
            exit 0
        elif [ "${res}" = "n" ] || [ "${res}" = "N" ]; then
            echo "Please insert a single domain without www"
            read domain
            if [ ! -z "${domain}" ] && [ -d /var/www/vhosts/${DOMAIN} ]; then
                varnishadm "ban req.http.host == ${domain}"
                varnishadm "ban req.http.host == www.${domain}"
                echo "Varnish cache cleaned for ${domain}"
                exit 0
            else
                echo "Domain ${domain} not present!"
                exit 1
            fi
        else
            continue
        fi
    done
fi
