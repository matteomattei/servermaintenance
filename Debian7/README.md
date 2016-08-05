Full web server setup with Debian 8:
------

This is an automatic script that installs and configure the following services on top of Debian 8 Jessie:

 - MySQL (database server)
 - NGINX (reverse proxy web server)
 - APACHE (web server)
 - PHP (web backend)
 - EXIM (MTA mail server)
 - SHOREWALL (firewall)


```
wget https://raw.githubusercontent.com/matteomattei/servermaintenance/master/Debian7/DebianServerSetup.sh && /bin/bash DebianServerSetup.sh && rm DebianServerSetup.sh
```

