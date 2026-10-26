# Web Application Firewall Home Lab using SafeLine WAF

A complete cybersecurity home lab built with **VirtualBox**, **Kali Linux**, **Ubuntu Server**, **DVWA**, and **SafeLine WAF**.

Original guide by **Royden Rebello (The Social Dork)** · Video walkthrough: <https://youtu.be/N0dEC1nuWCQ>

> ⚠️ **Lab use only.** DVWA is intentionally vulnerable. Keep this lab on an isolated network, never expose it to the internet, and only attack systems you own.

## What you will build

- A vulnerable web app (DVWA) running on Ubuntu Server
- A SQL injection attack launched from Kali Linux
- SafeLine WAF sitting in front of DVWA and blocking the attack
- Extra WAF features: HTTP flood defense, auth sign-in, and custom deny rules

```
┌────────────┐   HTTPS (443)   ┌──────────────────────────────────────┐
│ Kali Linux │ ──────────────► │ Ubuntu Server                        │
│ (attacker) │                 │  SafeLine WAF ──► Apache + DVWA:8080 │
└────────────┘                 └──────────────────────────────────────┘
```

## Repository layout

| Path | Purpose |
|---|---|
| `README.md` | The full guide (this file) |
| `docs/Safeline_WAF_Guide.pdf` | Original PDF guide |
| `scripts/ubuntu-setup.sh` | Automates sections 4.1 – 4.4 |
| `scripts/generate-cert.sh` | Automates section 6 (self-signed cert) |
| `scripts/flood-test.sh` | Simple HTTP flood test for section 9.1 |
| `sql/dvwa-setup.sql` | DVWA database and user |
| `sql/custom-data.sql` | Extra tables/data for SQLi demos (section 4.5) |
| `config/` | Example `hosts` file and BIND zone files |

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Lab environment setup](#2-lab-environment-setup)
3. [Ubuntu Server configuration](#3-ubuntu-server-configuration)
4. [DNS resolution setup](#4-dns-resolution-setup)
5. [Self-signed SSL certificate](#5-creating-a-self-signed-ssl-certificate)
6. [Installing and configuring SafeLine WAF](#6-installing-and-configuring-safeline-waf)
7. [Demonstrating SQL injection from Kali](#7-demonstrating-sql-injection-from-kali-linux)
8. [Advanced SafeLine configurations](#8-safeline-waf-advanced-configurations)
9. [Conclusion and further exploration](#9-conclusion-and-further-exploration)
10. [Final notes](#10-final-notes)

---

## 1. Prerequisites

- Host machine with **8 GB RAM or more** and **50 GB+ free disk space**
- Internet connection for downloads and updates
- Basic Linux command-line knowledge

If you hit errors, search the internet for your specific issue or refer to the video walkthrough.

## 2. Lab environment setup

### 2.1 Install VirtualBox

1. Download from <https://www.virtualbox.org/wiki/Downloads> (pick your host OS).
2. Run the installer. Optionally install the Extension Pack (USB 2.0/3.0, etc.).

### 2.2 Create the Kali Linux VM

1. Download the ISO from <https://www.kali.org/get-kali> (64-bit is most common).
2. Create a new VM in VirtualBox:
   - **Name:** `KaliLinux`
   - **Type / Version:** Linux / Debian (64-bit)
   - **Memory:** at least 2 GB (2048 MB)
   - **Disk:** ~20 GB, dynamically allocated
3. Under **Settings → Storage**, attach the Kali ISO and start the VM.
4. Follow the graphical installer and create a username/password you will remember.

### 2.3 Create the Ubuntu Server VM

1. Download the latest LTS ISO from <https://ubuntu.com/download/server> (e.g. 22.04 LTS).
2. Create a new VM:
   - **Name:** `UbuntuServer`
   - **Type / Version:** Linux / Ubuntu (64-bit)
   - **Memory:** at least 2 GB (2048 MB)
   - **Disk:** ~20 GB, dynamically allocated
3. Attach the Ubuntu ISO and start the VM.
4. Create a user during installation. You may optionally install the OpenSSH server for remote access.

> Use your own strong credentials. Don't reuse weak defaults like `ubuntu / ubuntu` on anything beyond a fully isolated lab.

### 2.4 Enable bridged networking

So the VMs appear on the same network as your host and each other:

1. VirtualBox → select the VM → **Settings → Network**.
2. **Adapter 1:** *Bridged Adapter*.
3. Pick your host's network interface (Ethernet or Wi-Fi) and click **OK**.
4. After installing `net-tools` (section 3), run `ifconfig` to get the VM's IP address.

Repeat for the Kali VM.

### 2.5 Install Guest Additions (optional but recommended)

1. With the VM running: **Devices → Insert Guest Additions CD Image**.
2. Follow the on-screen instructions, or install manually:

```bash
sudo apt-get update
sudo apt-get install build-essential dkms linux-headers-$(uname -r)
sudo mount /dev/cdrom /media/cdrom
sudo /media/cdrom/VBoxLinuxAdditions.run
```

3. Restart the VM. Guest Additions give you screen resizing, shared clipboard, and shared folders.

## 3. Ubuntu Server configuration

> **Shortcut:** `bash scripts/ubuntu-setup.sh` performs sections 3.1 – 3.4 automatically. The manual steps are below.

### 3.1 Initial updates and tools

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y net-tools openssl
```

### 3.2 Install the LAMP stack

```bash
sudo apt-get install -y apache2 php php-mysql mysql-server
```

Secure MySQL (optional but recommended). Set a root password, remove anonymous users, disable remote root login:

```bash
sudo mysql_secure_installation
```

### 3.3 Install DVWA

```bash
sudo apt-get install -y git        # if not already installed
cd /var/www/html
sudo git clone https://github.com/digininja/DVWA.git
sudo chown -R www-data:www-data DVWA
sudo chmod -R 755 DVWA
```

DVWA's config lives at `DVWA/config/config.inc.php`. If it doesn't exist yet, copy it from `config.inc.php.dist`, then set:

```php
$_DVWA['db_server']   = 'localhost';
$_DVWA['db_database'] = 'dvwa';
$_DVWA['db_user']     = 'dvwa_user';
$_DVWA['db_password'] = 'p@ssw0rd';
```

Create the database and user (or run `sql/dvwa-setup.sql`):

```sql
CREATE DATABASE dvwa;
CREATE USER 'dvwa_user'@'localhost' IDENTIFIED BY 'p@ssw0rd';
GRANT ALL ON dvwa.* TO 'dvwa_user'@'localhost';
FLUSH PRIVILEGES;
```

Then browse to `http://<Ubuntu IP>/DVWA/setup.php` and click **Create / Reset Database**.

### 3.4 Change the DVWA listening port to 8080

The WAF will take over ports 80/443, so move Apache to 8080.

1. Edit `/etc/apache2/ports.conf` and change `Listen 80` to `Listen 8080`.
2. Edit `/etc/apache2/sites-available/000-default.conf` and change `<VirtualHost *:80>` to `<VirtualHost *:8080>`.
3. Restart Apache:

```bash
sudo systemctl restart apache2
```

DVWA is now at `http://<Ubuntu IP>:8080/DVWA`.

### 3.5 Add custom data to the DVWA database

Gives you something to target in SQL injection experiments (or run `sql/custom-data.sql`):

```sql
USE dvwa;

CREATE TABLE test_users (
  id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  password VARCHAR(50) NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO test_users (username, password) VALUES
  ('alice', 'alice123'),
  ('bob',   'bob123'),
  ('admin', 'admin123');
```

## 4. DNS resolution setup

### 4.1 Using `/etc/hosts` (simplest)

On **both** Ubuntu and Kali, add (see `config/hosts.example`):

```
<Ubuntu IP>    dvwa.local
```

### 4.2 (Optional) BIND DNS server

Install BIND9 on Ubuntu:

```bash
sudo apt-get install -y bind9
```

Append to `/etc/bind/named.conf.local` (see `config/bind/named.conf.local.example`):

```
zone "dvwa.local" {
    type master;
    file "/etc/bind/zones/db.dvwa.local";
};
```

Create the zone directory and zone file (template: `config/bind/db.dvwa.local.example`):

```bash
sudo mkdir -p /etc/bind/zones
sudo nano /etc/bind/zones/db.dvwa.local
```

Restart BIND:

```bash
sudo systemctl restart bind9
```

On Kali, point DNS at the Ubuntu VM in `/etc/resolv.conf` (or NetworkManager):

```
nameserver <Ubuntu IP>
```

Test:

```bash
dig www.dvwa.local
```

## 5. Creating a self-signed SSL certificate

> **Shortcut:** `bash scripts/generate-cert.sh`

On Ubuntu:

```bash
sudo mkdir /etc/ssl/dvwa

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/dvwa/dvwa.key \
  -out /etc/ssl/dvwa/dvwa.crt \
  -subj "/CN=dvwa.local"
```

## 6. Installing and configuring SafeLine WAF

### 6.1 Automatic deployment

1. Go to <https://ly.safepoint.cloud/zfYZD3l> and select **Install**.
2. On the Ubuntu CLI, run the official installer:

   ```bash
   bash -c "$(curl -fsSLk https://waf.chaitin.com/release/latest/manager.sh)" -- --en
   ```

   > Tip: `-k` disables TLS certificate verification for the download. Check SafeLine's current install docs and drop `-k` if the download works without it.
3. Follow the on-screen prompts. You'll receive an admin username/password and the console URL (typically port **9443**).
4. After logging in, upgrading to a PRO license is recommended. A 7-day trial is available at the link above (about $1), and a longer subscription is optional.

### 6.2 Import the self-signed certificate

In the SafeLine web UI, import:

- **Certificate file:** `/etc/ssl/dvwa/dvwa.crt`
- **Key file:** `/etc/ssl/dvwa/dvwa.key`

See the SafeLine documentation for managing certificates via GUI or CLI.

### 6.3 Onboard the DVWA application

In the SafeLine management console, add a new application:

1. **Domain:** `www.dvwa.local` (or whichever domain you chose)
2. **Backend URL (reverse proxy):** `http://<Ubuntu IP>:8080`
3. **Ports:** delete port 80 and leave only 443
4. **Virtual host (for WAF):** e.g. `dvwa-waf.local`, or reuse the same domain
5. **SSL certificate:** attach the one you imported, so the WAF serves HTTPS

## 7. Demonstrating SQL injection from Kali Linux

### 7.1 Launch the attack

1. On Kali, browse to `http://dvwa.local/` (it redirects to HTTPS).
2. Log in to DVWA (default credentials `admin` / `password`, unless changed).
3. Set **DVWA Security** to **Low**.
4. Open **SQL Injection** and try classic payloads, e.g. `admin' OR '1'='1`.

### 7.2 Observe SafeLine's protection

SafeLine should detect and block the injection attempts. Check the WAF logs for blocked requests. If the WAF is in blocking mode you'll also see a block page.

## 8. SafeLine WAF advanced configurations

### 8.1 HTTP flood defense

1. Enable HTTP Flood / DoS protection in SafeLine.
2. Configure thresholds (requests per second) and penalty/ban duration.
3. Test from Kali with `ab`, `siege`, or similar. Example: `bash scripts/flood-test.sh https://dvwa.local/`

### 8.2 Authentication sign-in

SafeLine supports an auth gateway:

1. Enable **Auth Sign-In** in the WAF policy for DVWA.
2. Configure username/password, or integrate an external auth provider.
3. Try to access DVWA from Kali. The WAF should ask for credentials before passing traffic to the server.

### 8.3 Custom deny rules (block the Kali IP)

1. Find your Kali VM's IP (e.g. `192.168.1.50`).
2. Add a deny rule in SafeLine: **Match source IP** `192.168.1.50`, **Action** Block/Deny.
3. Test from Kali. You should get a blocked response.

## 9. Conclusion and further exploration

You now have a home lab with a vulnerable web app, a WAF, and the tools to attack and defend. Ideas for next steps:

- Experiment with other WAF options
- Add more vulnerable apps (e.g. OWASP Juice Shop)
- Try other attacks (XSS, file inclusion, command injection) and see how SafeLine responds
- Integrate with a home SIEM, NGFW, or IPS/IDS for a deeper lab

## 10. Final notes

- **Troubleshooting:** check logs on each layer (Kali, Apache, SafeLine WAF).
- **Security best practices:** keep the lab isolated from production networks.
- **Maintenance:** regularly update Ubuntu, Kali, and SafeLine WAF.

---

## Credits

Based on the guide *Web Application Firewall Home Lab using SafeLine WAF* by Royden Rebello (The Social Dork). Video: <https://youtu.be/N0dEC1nuWCQ>.
