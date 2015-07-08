#!/bin/bash

# Add swap
fallocate -l 1G /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile	swap 	swap 	auto	0	0' | tee -a /etc/fstab > /dev/null
cat << EOF | tee -a /etc/sysctl.conf > /dev/null
# Swap settings
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
sysctl -p

# Update and upgrade existing packages
apt-get update && apt-get -y upgrade

# Ensure that required packages are installed
apt-get -y install debconf-utils expect pwgen

# Generate a password for this server, assign to a shell variable and save to a file.
PASSWORD=`pwgen -s 15 1`
echo ${PASSWORD} | tee /root/password.txt

# Install Postfix. $DOMAIN is set to 'local' if nothing is exported
echo "postfix postfix/mailname string ${DOMAIN='local'}" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
apt-get install -y postfix

# Lockdown Postfix.
sed -i -e 's/\(mydestination\s=\s\).*/\1localhost, localhost.localdomain/' \
	-e 's/\(inet_interfaces\s=\s\).*/\1localhost/' /etc/postfix/main.cf
cat << EOF | tee -a /etc/postfix/main.cf > /dev/null
default_process_limit = 100
smtpd_client_connection_count_limit = 10
smtpd_client_connection_rate_limit = 30
queue_minfree = 20971520
header_size_limit = 51200
message_size_limit = 10485760
smtpd_recipient_limit = 100
EOF

# Install Apache
apt-get install -y apache2

# Rename web directory, update the 'default' vhost config, then restart Apache
WWW_DIR=$(echo 'suitecrm')
mv /var/www/html /var/www/${WWW_DIR}
sed -i "s/\(DocumentRoot\s\).*/\1\/var\/www\/${WWW_DIR}/" /etc/apache2/sites-enabled/000-default.conf

# Install MySQL
echo "mysql-server mysql-server/root_password password ${PASSWORD='root'}" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password ${PASSWORD='root'}" | debconf-set-selections
apt-get install -y mysql-server

# Secure MySQL
SECURE_MYSQL=$(expect -c "

set timeout 3
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"${PASSWORD}\r\"

expect \"root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")
echo "${SECURE_MYSQL}"

# Install PHP and the needed extensions
apt-get install -y php5 php5-cli php5-mysql php5-curl php5-mcrypt php5-gd php5-json php5-imap

# Download and extract SuiteCRM
cd ~/
wget https://github.com/salesagility/SuiteCRM/archive/v7.2.2.tar.gz -O suitecrm-v7.2.2.tar.gz 
tar -xzf suitecrm-v7.2.2.tar.gz

# Clean up web directory and copy SuiteCRM files
rm -rf /var/www/${WWW_DIR}/*
cd ~/SuiteCRM*
cp -R * /var/www/${WWW_DIR}/

# Update ownership and permissions
chown -R www-data:www-data /var/www/${WWW_DIR}
chmod -R 0775 /var/www/${WWW_DIR}

# Create database for SuiteCRM
SUITECRM_PASSWORD=`pwgen -s 15 -1`
echo ${SUITECRM_PASSWORD} | tee -a ~/password.txt > /dev/null
echo "SuiteCRM credentials: suitecrm/${SUITECRM_PASSWORD}"
mysql -u root -p${PASSWORD} \
-e "create database suitecrm; grant all on suitecrm.* to suitecrm@localhost identified by '${SUITECRM_PASSWORD}'"

# Restart all services
service postfix restart
service apache2 restart
service mysql restart