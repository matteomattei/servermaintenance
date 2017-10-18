Debian 9 - 64 bit
=============
First of all copy SSH key and update the whole system.

```
apt-get update
apt-get dist-upgrade
apt-get install screen
```

Now run screen and execute all other commands inside screen:
```
apt-get install nginx php-fpm php-curl php-mysql git python3-pip certbot mysql-server mysql-client phpmyadmin vim net-tools tree memcached php-memcached man
```

  - When **Web server to reconfigure automatically:** select **NONE**
  - When **Configure database for phpmyadmin with dbconfig-common?** select **Yes**
  - When **MySQL application password for phpmyadmin:** type **ENTER**

Edit ```/usr/share/vim/vim80/defaults.vim``` and comment these lines:
```
" if has('mouse')
" set mouse=a
" endif
```

Install python3 dependencies:
```
pip3 install tld
```

Configure certbot for letsencrypt:
```
certbot register --agree-tos -m matteo.mattei@gmail.com
```

Configure hostname properly in /etc/hosts and /etc/hostname
Configure mysql, set root password and disable UNIX socket authentication:

```
mysql -u root mysql -e "update user set plugin='' where user='root'; flush privileges;"
mysql_secure_intallation
```

Install Firewall:
```
apt-get install iptables shorewall
cp /usr/share/doc/shorewall/examples/one-interface/interfaces /etc/shorewall/interfaces
cp /usr/share/doc/shorewall/examples/one-interface/policy /etc/shorewall/policy
cp /usr/share/doc/shorewall/examples/one-interface/rules /etc/shorewall/rules
cp /usr/share/doc/shorewall/examples/one-interface/zones /etc/shorewall/zones
```

Add the following lines to `/etc/shorewall/rules`:
```
# custom rules
HTTP/ACCEPT     net             $FW
HTTPS/ACCEPT    net             $FW
SSH/ACCEPT      net             $FW

# backup
ACCEPT          $FW             net             tcp     25
ACCEPT          $FW             net             tcp     80
ACCEPT          $FW             net             tcp     443
ACCEPT          $FW             net             tcp     8087
ACCEPT          $FW             net             tcp     8086
ACCEPT          $FW             net             tcp     2546
ACCEPT          $FW             net             tcp     807
```

In `/etc/shorewall/policy` remove **info** in the line that has **DROP**
Then edit `/etc/default/shorewall` and change **startup=0** to **startup=1** and restart shorewall:
```
/etc/init.d/shorewall start
```

Install and configure NTP:
```
apt-get install ntp
systemctl enable ntp
systemctl restart ntp
```

Select correct timezone:
```
dpkg-reconfigure tzdata
# Select Europe/Rome
```

Install and configure **Postfix**
```
apt-get install postfix bsd-mailx
# General type of mail configuration: Internet Site
# System mail name: prod.fontmood.com
```

Limit ssh access to key only editing `/etc/ssh/sshd_config` and setting `PermitRootLogin without-password` and `X11Forwarding no`. 

If IPv6 is configured we have to setup Postfix to send only through IPv4.

```
echo "transport_maps = hash:/etc/postfix/transport" >> /etc/postfix/main.cf
echo "gmail.com       smtp-ipv4:" >> /etc/postfix/transport
echo "smtp-ipv4 unix  -       -       -       -       -       smtp" >> /etc/postfix/master.cf
echo "  -o inet_protocols=ipv4" >> /etc/postfix/master.cf
```

Then add the transport table in Postfix and reload it:

```
postmap /etc/postfix/transport
postfix reload
```

Add 5GB of swap file
```
dd if=/dev/zero of=/swapfile bs=1G count=5
chown root:root /swapfile
chmod 0600 /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
```

Copy all needed nginx configurations and domains manager:

```
mkdir -p /etc/nginx/global
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/codeigniter_production.conf > /etc/nginx/global/codeigniter_production.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/codeigniter_testing.conf > /etc/nginx/global/codeigniter_testing.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/common.conf > /etc/nginx/global/common.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/dokuwiki.conf > /etc/nginx/global/dokuwiki.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/phpmyadmin.conf > /etc/nginx/global/phpmyadmin.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/plainphp.conf > /etc/nginx/global/plpainphp.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/ssl.conf > /etc/nginx/global/ssl.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/nginx/global/wordpress.conf > /etc/nginx/global/wordpress.conf
wget -q -O - https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian9/lemp.py > /root/lemp.py
chmod +x /root/lemp.py
chmod 750 /root/lemp.py

```
