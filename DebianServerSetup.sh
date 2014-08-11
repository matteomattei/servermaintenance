#!/bin/bash

VERSION="0.1"
AUTHOR="Matteo Mattei <info@matteomattei.com>"

is_installed()
{
    dpkg -l "${1}" > /dev/null 2>&1
    return ${?}
}

pretty_echo()
{
    echo -e "\e[1;32m${1}\e[0m"
}

select_yes()
{
    MESSAGE="${1}"
    while true; do
        pretty_echo "\n${MESSAGE} [Y|n]"
        read RES
        case "${RES}" in
            y|Y|yes|Yes|YES|"")
                return 0
                ;;
            n|N|no|NO)
                return 1
                ;;
            *)
                pretty_echo "I don't understand..."
                ;;
        esac
    done
}

##############################
###### MAIN STARTS HERE ######
##############################

# Make sure to be root
if [ ! $(id -u) -eq 0 ]; then pretty_echo "You have to execute this program with root credentials"; exit 1; fi

# PRINT STARTUP MESSAGE
COPYRIGHT_DATE=$(date +%Y)
[ ${COPYRIGHT_DATE} -gt 2014 ] && COPYRIGHT_DATE="2014-${COPYRIGHT_DATE}"
pretty_echo "

DebianServerSetup v.${VERSION} - copyright ${COPYRIGHT_DATE} ${AUTHOR}
This program will updated the whole system and install a set of common services
needed for a production Web Server based on Debian based distribution.
This is the list of the services supported:

1) MySQL (database server)
2) NGINX (web server)
3) PHP (web backend)
4) EXIM (MTA mail server)
5) SHOREWALL (firewall)

During the installation you will be prompted to insert the following information:

HOSTNAME: hostname of the server ("web1" for example)
FQDN: a Fully Qualified Domain Name ("web1.mydomain.com" for example)
IP_ADDRESS: a public IP address
MYSQL ROOT PASSWORD: only if you decide to install MySQL
-----------------------------------------------------------------------------------------"

if ! select_yes "Do you want to proceed?"; then exit 0; fi

# SETUP APT SOURCE
# This is just for clean-up in case some server has an old repository configured
sed -i "/non\-us\.debian\.org/d" /etc/apt/sources.list

# SETTING UP LOCALES
# This is needed in case the server does not have any locale already configured
if [ -z "${LC_ALL}" ] || [ -z "${LANGUAGE}" ] || [ -z "${LANG}" ]
then
    export LC_ALL="en_US.UTF-8"
    export LANGUAGE="en_US.UTF-8"
    export LANG="en_US.UTF-8"
    sed -i "{s/^# en_US\.UTF\-8 UTF\-8/en_US.UTF-8 UTF-8/g}" /etc/locale.gen
    update-locale LC_ALL=en_US.UTF-8
    update-locale LANGUAGE=en_US.UTF-8
    update-locale LANG=en_US.UTF-8
    locale-gen en_US.UTF-8
    . /etc/default/locale
fi

# UPDATE THE WHOLE SYSTEM
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

# INSTALL USEFUL TOOLS
apt-get -y install vim

# SETUP IP ADDRESS AND HOSTNAME
IP_ADDRESS=$(ifconfig | grep "inet addr:" | grep -v "127\.0\.0\.1" | awk '{print $2}' | awk -F':' '{print $2}')
if [ -n "${IP_ADDRESS}" ]
then
    if ! select_yes "Do you want to use the IP address ${IP_ADDRESS}?"
    then
        while true
        do
            pretty_echo "Plesae provide your IP address"
            read IP_ADDRESS
            if [ -n "${IP_ADDRESS}" ]
            then
                if echo "${IP_ADDRESS}" | grep -Eq "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
                then
                    break
                else
                    pretty_echo "Unknown IP address"
                fi
            fi
        done
    fi
else
    while true
    do
        pretty_echo "Plesae provide your IP address"
        read IP_ADDRESS
        if [ -n "${IP_ADDRESS}" ]
        then
            if echo "${IP_ADDRESS}" | grep -Eq "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
            then
                break
            else
                pretty_echo "Unknown IP address"
            fi
        fi
    done
fi

# Now that we have the IP address we setup /etc/hosts
while true
do
    pretty_echo "Current hostname: $(hostname)"
    pretty_echo "Current FQDN: $(hostname -f)"
    if select_yes "Do you want to change them?"
    then
        while true
        do
            pretty_echo "Please provide a new hostname (something like 'web1')"
            read HOSTNAME_NAME
            if [ -n "${HOSTNAME_NAME}" ]
            then
                echo "${HOSTNAME_NAME}" > /etc/hostname
                break
            fi
        done
        while true
        do
            pretty_echo "Please provide a new FQDN (something like 'web1.mydomain.tld')"
            read HOSTNAME_FQDN
            if [ -n "${HOSTNAME_FQDN}" ]
            then
                break
            fi
        done
        # remove all lines with localhost and the public IP from /etc/hosts
        sed -i "/^${IP_ADDRESS}.*/d" /etc/hosts
        sed -i "/^127\.0\..*/d" /etc/hosts
        
        # Insert the correct values in the top of the /etc/hosts
        sed -i "1i ${IP_ADDRESS} ${HOSTNAME_FQDN} ${HOSTNAME_NAME}" /etc/hosts
        sed -i "1i 127.0.0.1 localhost.localdomain localhost" /etc/hosts
        
        # Set up hostname
        echo "${HOSTNAME_NAME}" > /etc/hostname
        hostname -F /etc/hostname
    else
        break
    fi
done

# MYSQL
if select_yes "Do you want to install MySQL server and client?"
then
    # MYSQL-SERVER
    if ! $(is_installed mysql-server)
    then
        while true
        do
            pretty_echo "Please provide a MySQL root password"
            read MYSQL_ROOT_PASSWORD
            if [ -z "${MYSQL_ROOT_PASSWORD}" ]
            then
                pretty_echo "Password cannot be empty!"
                continue
            fi
            pretty_echo "Please type the MySQL root password again"
            read MYSQL_ROOT_PASSWORD_2
            if [ ! "${MYSQL_ROOT_PASSWORD}" = "${MYSQL_ROOT_PASSWORD_2}" ]
            then
                pretty_echo "The two entered passwords do not match"
                continue
            else
                break
            fi
        done
        echo "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
        apt-get -y install mysql-server

        # Configure MYSQL
        sed -i "{s/^key_buffer\s/key_buffer_size/g}" /etc/mysql/my.cnf
        sed -i "{s/^myisam-recover\s/myisam-recover-options/g}" /etc/mysql/my.cnf
    else
        pretty_echo "MYSQL server already installed... nothing done"
    fi

    # MYSQL-CLIENT
    if ! $(is_installed mysql-client)
    then
        apt-get -y install mysql-client
    else
        pretty_echo "MYSQL client already installed... nothing done"
    fi
fi

# NGINX
if select_yes "Do you want to install NGINX web server?"
then
    if ! $(is_installed nginx)
    then
        apt-get -y install nginx
        
        # Configure NGINX for production
        sed -i "{s/# gzip on;/gzip on;/g}" /etc/nginx/nginx.conf
        sed -i "{s/# gzip_/gzip_/g}" /etc/nginx/nginx.conf
        sed -i "{s/# server_tokens off;/server_tokens off;/g}" /etc/nginx/nginx.conf
        sed -i "/gzip_types/s/;/ image\/svg+xml;/" /etc/nginx/nginx.conf
    else
        pretty_echo "NGINX already installed... nothing done"
    fi
fi

# PHP-FPM
if select_yes "Do you want to install PHP-FPM for NGINX?"
then
    if ! $(is_installed php5-fpm)
    then
        apt-get -y install php5-fpm
        
        # Configure PHP-FPM for NGINX
        sed -i "{s/^;cgi\.fix_pathinfo=1/cgi.fix_pathinfo=0/g}" /etc/php5/fpm/php.ini
        
        # PHP-MYSQL
        if $(is_installed mysql-server)
        then
            if ! $(is_installed php5-mysql)
            then
                apt-get -y install php5-mysql
            fi
        fi
    fi
fi

# EXIM
if select_yes "Do you want to install Exim mail server?"
then
    if ! $(is_installed exim4)
    then
        apt-get -y install exim4
    fi
    # Clean mail queue
    [ -n "$(mailq)" ] && rm -f /var/spool/exim4/input/*
    
    # Configuration
    sed -i "{s/^dc_eximconfig_configtype=.*/dc_eximconfig_configtype='internet'/g}" /etc/exim4/update-exim4.conf.conf
    sed -i "{s/^dc_other_hostnames=.*/dc_other_hostnames='${HOSTNAME_FQDN}; ${HOSTNAME_NAME}; localhost.localdomain; localhost'/g}" /etc/exim4/update-exim4.conf.conf
    echo "${HOSTNAME_FQDN}" > /etc/mailname
fi

# SHOREWALL
if select_yes "Do you want to install Shorewall firewall?"
then
    if ! $(is_installed shorewall)
    then
        apt-get -y install shorewall
    fi
    
    # Configuration
    sed -i "{s/^startup=0$/startup=1/g}" /etc/default/shorewall
    cp /usr/share/doc/shorewall/examples/one-interface/interfaces /etc/shorewall/interfaces
    cp /usr/share/doc/shorewall/examples/one-interface/policy /etc/shorewall/policy
    cp /usr/share/doc/shorewall/examples/one-interface/rules /etc/shorewall/rules
    cp /usr/share/doc/shorewall/examples/one-interface/zones /etc/shorewall/zones
    echo -e "\n# Custom rules\n" >> /etc/shorewall/rules
    if $(is_installed nginx); then
        echo "HTTP/ACCEPT     net             \$FW" >> /etc/shorewall/rules
    fi
    if $(is_installed openssh-server); then
        echo "SSH/ACCEPT      net             \$FW" >> /etc/shorewall/rules
    fi
    if $(is_installed vsftp); then
        echo "FTP/ACCEPT      net             \$FW" >> /etc/shorewall/rules
    fi
fi

# SSH KEY
if select_yes "Do you want to add a public key for SSH access?"
then
    while true
    do
        pretty_echo "Please paste your public key here:"
        read PUBKEY
        if [ -n "${PUBKEY}" ]
        then
            mkdir -p /root/.ssh/
            echo "${PUBKEY}" >> /root/.ssh/authorized_keys
            chmod 660 /root/.ssh/authorized_keys
            chmod 770 /root/.ssh
            break
        else
            pretty_echo "Please specify a key"
        fi
    done
fi

# DOWNLOAD MANAGEMENT TOOLS
# TODO

# RESTART SERVICES
pretty_echo "Restarting all services..."
if $(is_installed mysql-server); then
    service mysql restart
fi
if $(is_installed php5-fpm); then
    service php5-fpm restart
fi
if $(is_installed nginx); then
    service nginx restart
fi
if $(is_installed exim4); then
    service exim4 restart
fi
if $(is_installed shorewall); then
    service shorewall restart
fi

pretty_echo "Installation complete. You should restart the server now"
if select_yes "Do you want to restart the server now?"
then
    reboot
fi
exit 0
