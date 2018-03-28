#!/bin/bash

sudo apt-get install -y python-software-properties curl

# add ondrej/php repository for php 7.1
sudo add-apt-repository -y ppa:ondrej/php

# add nginx/development repository
sudo add-apt-repository -y ppa:nginx/development

# add redis repository
sudo apt-add-repository -y ppa:chris-lea/redis-server

# add node 8x repository
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

# apt update
sudo apt-get update

# install some apt stuff
sudo apt-get install -y \
    php7.1-fpm php7.1-cli php7.1-sqlite3 php7.1-mysql \
    php7.1-gd php7.1-curl php7.1-memcached php7.1-imap \
    php7.1-mbstring php7.1-xml php7.1-zip php7.1-bcmath \
    php7.1-soap php7.1-intl php7.1-readline php7.1-mcrypt \
    php7.1-dev php-pear nginx redis-server nodejs mysql-server \
    mysql-client dnsmasq

# install composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# update some php.ini settings
sudo sed -i -e 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/g' /etc/php/7.1/fpm/php.ini
sudo sed -i -e 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php/7.1/fpm/php.ini
sudo sed -i -e 's/;date.timezone =/date.timezone = UTC/g' /etc/php/7.1/fpm/php.ini
sudo sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/7.1/fpm/php.ini

# update php-fpm user
sudo sed -i -e "s/user = www-data/user = $USER/g" /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i -e "s/owner = www-data/owner = $USER/g" /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i -e "s/group = www-data/group = $(id -gn)/g" /etc/php/7.1/fpm/pool.d/www.conf

# set up the ~/Code directory and http://info.test website
mkdir -p /home/"$USER"/Code/info/public
echo "<?php phpinfo();" > /home/"$USER"/Code/info/public/index.php

# remove default nginx config and create our own test.conf
sudo rm /etc/nginx/sites-enabled/default
sudo dd of=/etc/nginx/sites-available/test.conf << EOF
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name ~^(?<vhost>.+)\\.test\$;
  root /home/$USER/Code/\$vhost/public;

  index index.php index.html;

  server_name _;

  location / {
    try_files \$uri \$uri/ /index.php\$is_args\$args;
  }

  location ~ \.php\$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm.sock;
  }
}
EOF
sudo rm /etc/nginx/sites-enabled/test.conf
sudo ln -s /etc/nginx/sites-available/test.conf /etc/nginx/sites-enabled/

# update the nginx user
sudo sed -i -e "s/user www-data;/user $USER;/g" /etc/nginx/nginx.conf

# install some npm utils
sudo npm install -g gulp
sudo npm install -g yarn

# fix permissions on ~/.config directory so npm globals work
sudo chown -R $USER:$(id -gn $USER) /home/$USER/.config

# allow non sudo for mysql
sudo mysql -u root -e "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root' AND plugin = 'auth_socket';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# set up *.test to point to localhost
sudo dd of=/etc/dnsmasq.d/test-tld << EOF
local=/test/
address=/test/127.0.0.1
EOF
sudo dd of=/etc/resolvconf/resolv.conf << EOF
nameserver 127.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
sudo rm /etc/resolv.conf
sudo ln -s /etc/resolvconf/resolv.conf /etc/resolv.conf


# restart all services
sudo systemctl restart php7.1-fpm
sudo systemctl restart nginx
sudo systemctl restart mysqld
sudo systemctl restart redis-server
sudo systemctl restart dnsmasq
