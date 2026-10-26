#!/usr/bin/env bash
# Sections 4.1 - 4.4: base packages, LAMP, DVWA, and Apache on port 8080.
# Run on the Ubuntu Server VM:  bash scripts/ubuntu-setup.sh
# LAB USE ONLY - this installs an intentionally vulnerable application.
set -euo pipefail

DB_NAME="dvwa"
DB_USER="dvwa_user"
DB_PASS="${DVWA_DB_PASS:-p@ssw0rd}"   # override: DVWA_DB_PASS='something' bash scripts/ubuntu-setup.sh

echo "[+] 4.1 Updating system and installing base tools"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y net-tools openssl git

echo "[+] 4.2 Installing LAMP stack"
sudo apt-get install -y apache2 php php-mysql php-gd mysql-server

echo "[+] 4.3 Installing DVWA"
cd /var/www/html
if [ ! -d DVWA ]; then
  sudo git clone https://github.com/digininja/DVWA.git
fi
[ -f DVWA/config/config.inc.php ] || sudo cp DVWA/config/config.inc.php.dist DVWA/config/config.inc.php
sudo sed -i "s/^\(\$_DVWA\[ *'db_user' *\] *= *\).*/\1'${DB_USER}';/" DVWA/config/config.inc.php
sudo sed -i "s/^\(\$_DVWA\[ *'db_password' *\] *= *\).*/\1'${DB_PASS}';/" DVWA/config/config.inc.php
sudo chown -R www-data:www-data DVWA
sudo chmod -R 755 DVWA

echo "[+] Creating database and user"
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "[+] 4.4 Moving Apache to port 8080"
sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf
sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf
sudo systemctl restart apache2

IP=$(hostname -I | awk '{print $1}')
echo
echo "[done] Open: http://${IP}:8080/DVWA/setup.php and click 'Create / Reset Database'."
echo "       Optional: sudo mysql < sql/custom-data.sql  (section 4.5)"
echo "       Recommended: sudo mysql_secure_installation"
