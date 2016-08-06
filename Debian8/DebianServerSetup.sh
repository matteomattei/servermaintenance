#!/bin/bash

VERSION="0.1"
AUTHOR="Matteo Mattei <info@matteomattei.com>"

is_installed()
{
    dpkg -l "${1}" 2> /dev/null | grep "^ii" > /dev/null
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

Debian 8 ServerSetup v.${VERSION} - copyright ${COPYRIGHT_DATE} ${AUTHOR}
This program will updated the whole system and install a set of common services
needed for a production Web Server based on Debian based distribution.
This is the list of the services supported:

1) MySQL (database server)
2) NGINX (web server)
3) PHP-FPM (web backend)
4) POSTFIX (mail server)
5) SHOREWALL (firewall)

During the installation you will be prompted to insert the following information:

HOSTNAME: hostname of the server (\"web1\" for example)
FQDN: a Fully Qualified Domain Name (\"web1.mydomain.com\" for example)
IP_ADDRESS: a public IP address
MYSQL ROOT PASSWORD: only if you decide to install MySQL
-----------------------------------------------------------------------------------------"

if ! select_yes "Do you want to proceed?"; then exit 0; fi

# SETUP APT SOURCE
# This is just for clean-up in case some server has an old repository configured
sed -i "/non\-us\.debian\.org/d" /etc/apt/sources.list

# Make sure to use jessie repository
sed -i "{s#squeeze.*#jessie/updates main contrib non-free#g}" /etc/apt/sources.list

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
apt-get -y remove --purge exim*
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

# INSTALL USEFUL TOOLS
apt-get -y install vim screen git pwgen

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
        CPU_CORES=`grep "^processor" /proc/cpuinfo | wc -l`
        sed -i "{s/# gzip/gzip/g}" /etc/nginx/nginx.conf
        sed -i "{s/# server_tokens off;/server_tokens off;/g}" /etc/nginx/nginx.conf
        sed -i "/gzip_types/s/;/ image\/svg+xml;/" /etc/nginx/nginx.conf
        sed -i "{s/^worker_processes.*/worker_processes ${CPU_CORES};/g}" /etc/nginx/nginx.conf
        sed -i "{s/worker_connections.*/worker_connections 1024;/g}" /etc/nginx/nginx.conf
	rm -f /etc/nginx/sites-enabled/default
    else
        pretty_echo "NGINX already installed... nothing done"
    fi
fi

# PHP-FPM
if select_yes "Do you want to install PHP-FPM?"
then
    if ! $(is_installed php5-fpm)
    then
        apt-get -y install php5 php5-fpm php5-mcrypt

        # Configure PHP-FPM
        sed -i "{s/^;cgi\.fix_pathinfo=1/cgi.fix_pathinfo=0/g}" /etc/php5/fpm/php.ini
	sed -i "{s/;pm.max_requests = 500/pm.max_requests = 500/g}" /etc/php5/fpm/pool.d/www.conf
        sed -i -e 's|^;*request_terminate_timeout.*|request_terminate_timeout = 600|' /etc/php5/fpm/pool.d/www.conf
        sed -i "{s/;pm.max_requests =.*/pm.max_requests = 500/g}" /etc/php5/fpm/pool.d/www.conf

        # PHP-MYSQL
        if $(is_installed mysql-server)
        then
            if ! $(is_installed php5-mysql)
            then
                apt-get -y install php5-mysql
            fi

            # PHPMYADMIN
            if select_yes "Do you want to install PHPMYADMIN"
            then
                if ! $(is_installed phpmyadmin)
                then
                    AUTOGENERATED_PASS=`pwgen -c -1 20`
                    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
                    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
                    echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
                    echo "phpmyadmin phpmyadmin/mysql/admin-pass password ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
                    echo "phpmyadmin phpmyadmin/mysql/app-pass password ${AUTOGENERATED_PASS}" |debconf-set-selections
                    echo "phpmyadmin phpmyadmin/app-password-confirm password ${AUTOGENERATED_PASS}" | debconf-set-selections
                    apt-get -y install phpmyadmin
                fi
            fi
        fi
    fi
fi


# POSTFIX 
if select_yes "Do you want to install Postfix mail server?"
then
    if ! $(is_installed postfix)
    then
        echo "postfix postfix/protocols select all" | debconf-set-selections
        echo "postfix postfix/relayhost string " | debconf-set-selections
        echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
        echo "postfix postfix/mailname string test.chip2bit.com" | debconf-set-selections
        apt-get -y install postfix 
    fi
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
    echo "HTTP/ACCEPT     net             \$FW" >> /etc/shorewall/rules
    echo "SSH/ACCEPT      net             \$FW" >> /etc/shorewall/rules
fi

# BACKUP ON MEGA.CO.NZ
if select_yes "Do you want to install megatools?"
then
    echo "[Login]" > /root/.megarc
    while true
    do
        pretty_echo "Please provide Mega.co.nz username (email):"
        read MEGA_USERNAME
        if [ -n "${MEGA_USERNAME}" ]
        then
            echo "Username = ${MEGA_USERNAME}" >> /root/.megarc
            break
        else
            pretty_echo "Please specify Mega.co.nz username"
        fi
    done
    while true
    do
        pretty_echo "Please provide Mega.co.nz password:"
        read MEGA_PASSWORD
        if [ -n "${MEGA_PASSWORD}" ]
        then
            echo "Password = ${MEGA_PASSWORD}" >> /root/.megarc
            break
        else
            pretty_echo "Please provide Mega.co.nz password"
        fi
    done
    chmod 640 /root/.megarc
    if ! $(is_installed megatools)
    then
        apt-get install -y \
            glib-networking \
            libproxy1 \
            glib-networking-services \
            glib-networking-common \
            gsettings-desktop-schemas \
            dconf-gsettings-backend \
            dconf-service \
            libdconf1 \
            libcurl3
        wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/backup/megatools_1.9.97-1_amd64.deb
        dpkg -i megatools_*.deb
        rm -f megatools_*.deb
        wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/backup/megabackup.sh && chmod +x megabackup.sh
        sed -i "{s/MyRootPassword/${MYSQL_ROOT_PASSWORD}/g}" megabackup.sh
        echo "04 04 * * * root /root/megabackup.sh" >> /etc/crontab
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
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/add_domain.sh && chmod 750 add_domain.sh
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/del_domain.sh && chmod 750 del_domain.sh
mkdir /etc/nginx/global
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/nginx/global/common.conf -O /etc/nginx/global/common.conf
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/nginx/global/dokuwiki.conf -O /etc/nginx/global/dokuwiki.conf
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/nginx/global/phpmyadmin.conf -O /etc/nginx/global/phpmyadmin.conf
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/nginx/global/plainphp.conf -O /etc/nginx/global/plainphp.conf
wget -q https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian8/nginx/global/wordpress.conf -O /etc/nginx/global/wordpress.conf

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
if $(is_installed postfix); then
    service postfix restart
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

