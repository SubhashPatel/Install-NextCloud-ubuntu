#!/bin/bash

# NextCloud Optimization Script
# with PHP Opcache and Redis Memcache
# Important: Do not run until the setup wizard in your browser is complete (has initialized the config.php file).
# Author: Subhash (serverkaka.com)

upload_max_filesize=4G # Largest filesize users may upload through the web interface
post_max_size=4G # Same as above
memory_limit=512M # Amount of memory NextCloud may consume
datapath='/data' # Path where user data is stored

# DO NOT EDIT BELOW THIS LINE

dirpath='/var/www/html' # Path where NextCloud is installed

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Server Stop
service apache2 stop

# Enable PHP Opcache
cd /etc/php/7.2/apache2/
rm php.ini
wget https://s3.amazonaws.com/serverkaka-pubic-file/nextcloud/php.ini

# Enable Redis memory caching
sed -i '$i'"'"'memcache.local'"'"' => '"'"'\\OC\\Memcache\\Redis'"'"','''  ${dirpath}/config/config.php
sed -i '$i'"'"'memcache.locking'"'"' => '"'"'\\OC\\Memcache\\Redis'"'"','''  ${dirpath}/config/config.php
sed -i '$i'"'"'redis'"'"' => array('"\n""'"'host'"'"' => '"'"'localhost'"'"','"\n""'"'port'"'"' => 6379,'"\n"'),'''  ${dirpath}/config/config.php

# Change the upload cache directory
# Makes it easier to exclude cache from rsync-style backups
sed -i '$i'"'"'cache_path'"'"' => '"'"${datapath}'/cache'"'"','''  ${dirpath}/config/config.php

# Change the PHP upload and memory limits

for key in upload_max_filesize post_max_size memory_limit
do
sed -i "s/^\($key\).*/\1=$(eval echo \${$key})/" ${dirpath}/.user.ini
done

printf "\n\nOptimization complete."
