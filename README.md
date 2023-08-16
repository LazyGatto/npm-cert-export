# Nginx Proxy Manager Certificate Export to Mailcow

This shell script export certificate from [Nginx Proxy Manager](https://nginxproxymanager.com) to use with [mailcow](https://mailcow.email) mail server.

* [How does it work](#how-does-it-work)
* [Usage](#usage)

## How does it work

This script has to added into crontab, and executed on machine where you need your certificate to be copied.

It was developed for use with mailcow mail server, but actullay you can run it with any application, that runs behind Nginx Proxy Manager (NPM).

This script logins over SSH into machine where NPM is running, then it finds appropriate certificate file for your domain.

If local certificate already outdated, it will be replaced with the new one from NPM.

## Usage

1. Clone repository & make script executable 
```sh
cd /opt
git clone https://github.com/LazyGatto/npm-cert-export
cd npm-cert-export
chmod +x sync_certs.sh
```
2. Edit script
```sh
# Nginx Proxy Manager Settings

# 1. Here you have to enter your user and host, where NPM is running
NPM_HOST_URL='root@192.168.1.100' 

# 2. Set paths on the remote NPM host to its files, as they set in Docker ENV for NPM
NPM_DATA='/docker/nginx-proxy-manager/data'
NPM_LE='/docker/nginx-proxy-manager/letsencrypt'

# 3. Here set your target machine settings: domain name, and paths to certificate and private key
# Target Host
TARGET_HOST='mail.eg23.ru'
TARGET_CRT_PATH='/opt/mailcow-dockerized/data/assets/ssl/cert.pem'
TARGET_KEY_PATH='/opt/mailcow-dockerized/data/assets/ssl/key.pem'

# 4. Here you can set additional commands, that have to be run after certificate renew. By default it will try to restart certain Mailcow containers. But you can write here everything you need.
after_cmd() {
  postfix_c=$(docker ps -qaf name=postfix-mailcow)
  dovecot_c=$(docker ps -qaf name=dovecot-mailcow)
  nginx_c=$(docker ps -qaf name=nginx-mailcow)
  docker restart ${postfix_c} ${dovecot_c} ${nginx_c}
}
```

3. Make sure to add your local user public ssh key from target machine to `authorized_keys` on remote machine, where NPM is running. [Here](https://linuxhandbook.com/add-ssh-public-key-to-server/) is breief instructions how to do this, if you little confused with that.

4. After you run script and check everything is OK, you can add this to crontab
```
crontab -e
# Add 
0 * * * * /opt/npm-cert-export/sync_certs.sh > /opt/npm-cert-export/sync_certs.log
```

5. Don't forget to disable certificate renew process in mailcow server.
```
# cat mailcow.conf | grep SKIP_LE
SKIP_LETS_ENCRYPT=y
```