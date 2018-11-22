#!/bin/bash

# NextCloud Installation Script for Ubuntu
# with SSL certificate provided by Let's Encrypt (letsencrypt.org)
# Author: Subhash (serverkaka.com)

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

datapath='/myData' # Path where user data is stored
read -p 'nextcloud_url [xx.xx or xx.xx.xx]: ' nextcloud_url
read -p 'nextcloud_version [x.x.x]: ' nextcloud_version
read -p 'letsencrypt_email [xx@xx.xx]: ' letsencrypt_email
read -p 'db_root_password [secretpasswd]: ' db_root_password
read -p 'db_user_password [passwd]: ' db_user_password
echo

# Check All variable have a value
if [ -z $nextcloud_url ]|| [ -z $nextcloud_version ] || [ -z $letsencrypt_email ]|| [ -z $db_root_password ] || [ -z $db_user_password ]
then
      echo run script again please insert all value. do not miss any value
else
    
# Installation start

ocpath='/var/www/html' # Path where NextCloud is installed
htuser='www-data' # User Apache runs as
htgroup='www-data' # Group Apache runs as
rootuser='root'

# Add PHP 7.0 Repository
add-apt-repository ppa:ondrej/php -y
apt-get update

# Install Apache, Redis and PHP extensions
apt-get install apache2 -y

# Install Redis and PHP extensions
apt-get install php7.0 php7.0-curl php7.0-gd php7.0-fpm php7.0-cli php7.0-opcache php7.0-mbstring php7.0-xml php7.0-zip -y
apt-get install redis-server php-redis -y

# Install MySQL database server
export DEBIAN_FRONTEND="noninteractive"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_root_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_root_password"
apt-get install mysql-server php7.0-mysql -y

# Enable Apache extensions
a2enmod proxy_fcgi setenvif
a2enconf php7.0-fpm
service apache2 reload
apt-get install libxml2-dev php7.0-zip php7.0-xml php7.0-gd php7.0-curl php7.0-mbstring -y
a2enmod rewrite
service apache2 reload

# Download Nextcloud and move to web directory
wget https://download.nextcloud.com/server/releases/nextcloud-$nextcloud_version.zip
apt-get install unzip -y
unzip nextcloud-$nextcloud_version.zip
cd nextcloud
mv * $ocpath
mv .* $ocpath 
cd ..
rm nextcloud-$nextcloud_version.zip

# Create data directory
mkdir -p $datapath

# Set file and folder permissions
printf "Creating possible missing Directories\n"
mkdir -p $ocpath/data
mkdir -p $ocpath/assets
mkdir -p $ocpath/updater

printf "chmod Files and Directories\n"
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${datapath}/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/updater/
chown -R ${htuser}:${htgroup} /tmp
chmod +x ${ocpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ocpath}/.htaccess ]
then
 chmod 0644 ${ocpath}/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi

if [ -f ${ocpath}/data/.htaccess ]
then
 chmod 0644 ${ocpath}/data/.htaccess
 chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi

# Configure Apache
touch /etc/apache2/sites-available/nextcloud.conf
printf "<VirtualHost *:80>\n\nServerName $nextcloud_url\nAlias /nextcloud "/var/www/html/"\n\n<Directory /var/www/html/>\n Options +FollowSymlinks\n AllowOverride All\n\n<IfModule mod_dav.c>\n Dav off\n</IfModule>\n\nSetEnv HOME /var/www/html\nSetEnv HTTP_HOME /var/www/html\n\n</Directory>\n\n</VirtualHost>" > /etc/apache2/sites-available/nextcloud.conf
ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/nextcloud.conf
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
service apache2 reload

# Configure MySQL database
mysql -uroot -p$db_root_password <<QUERY_INPUT
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$db_user_password';
GRANT ALL PRIVILEGES ON nextcloud.* TO nextclouduser@localhost;
FLUSH PRIVILEGES;
EXIT
QUERY_INPUT

# Enable NextCloud cron job every 15 minutes
crontab -u www-data -l > cron
echo "*/15  *  *  *  * php -f /var/www/html/cron.php" >> cron
crontab -u www-data cron
rm cron

# Enable HTTPS with Let's Encrypt SSL Certificate 
apt-get install git -y
cd /etc
git clone https://github.com/certbot/certbot
cd certbot
./letsencrypt-auto --non-interactive --agree-tos --email $letsencrypt_email --apache -d $nextcloud_url --hsts
printf "<VirtualHost *:80>\n     ServerName $nextcloud_url\n     Redirect / https://nextcloud_url/\n</VirtualHost>" > /etc/apache2/sites-enabled/nextcloud.conf
service apache2 reload
# Set up cron job for certificate auto-renewal every 90 days
crontab -l > cron
echo "* 1 * * 1 /etc/certbot/certbot-auto renew --quiet" >> cron
crontab cron
rm cron

# Install complete
printf "\n\nInstall complete.\nNavigate to your NextCloud instance in a web browser to complete the setup wizard, before you run the optimization script.\n\n"
fi
