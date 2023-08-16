#!/bin/sh

# Nginx Proxy Manager Settings
NPM_HOST_URL='root@10.1.1.251'
# As they set in Docker ENV
NPM_DATA='/docker/nginx-proxy-manager/data'
NPM_LE='/docker/nginx-proxy-manager/letsencrypt'

# Target Host
TARGET_HOST='mail.eg23.ru'
TARGET_CRT_PATH='/opt/mailcow-dockerized/data/assets/ssl/cert.pem'
TARGET_KEY_PATH='/opt/mailcow-dockerized/data/assets/ssl/key.pem'

after_cmd() {
  postfix_c=$(docker ps -qaf name=postfix-mailcow)
  dovecot_c=$(docker ps -qaf name=dovecot-mailcow)
  nginx_c=$(docker ps -qaf name=nginx-mailcow)
  docker restart ${postfix_c} ${dovecot_c} ${nginx_c}
}

RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

msg_info() {
  local msg="$1"
  echo " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

ssh_cmd() {
    local cmd="$1"
    ssh $NPM_HOST_URL $cmd
}

find_remote_cert_id() {
    get_cert_id_cmd="grep -rwl --include=\*.conf '${NPM_DATA}/nginx/proxy_host' -e '${TARGET_HOST}' | xargs grep "fullchain" | grep -oP '(?<=npm-)\d+'"
    ssh_cmd "$get_cert_id_cmd"
}

copy_remote_certs() {
    local live_path=${NPM_LE}/live/npm-$1
    local live_fullchain=${live_path}/fullchain.pem
    local live_key=${live_path}/privkey.pem
    scp -qp ${NPM_HOST_URL}:${live_fullchain} ${TARGET_CRT_PATH}
    msg_ok "Certificate copied: ${live_fullchain} -> ${TARGET_CRT_PATH}"
    scp -qp ${NPM_HOST_URL}:${live_key} ${TARGET_KEY_PATH}
    msg_ok "Private key copied: ${live_key} -> ${TARGET_KEY_PATH}"
    msg_info "Execute after_cmd()"
    after_cmd
}

get_certificates() {

    msg_info "Trying to find Nginx Proxy Manager Certificate ID for: ${TARGET_HOST}"

    cert_id=$(find_remote_cert_id)

    if [ -z "$cert_id" ]
    then
        msg_error "Certificate for $TARGET_HOST not found in Nginx Proxy Manager"
        msg_info "Check path settings and if certifivate exists in NPM WebUI, and try again"
        exit 1
    else
        msg_ok "Certificate for target host found. NPM Cert ID: ${cert_id}"

        live_path=${NPM_LE}/live/npm-$cert_id
        live_fullchain=${live_path}/fullchain.pem

        live_timestamp=$(ssh_cmd "date -r ${live_fullchain} +%s")
        msg_info "Certificate timestamp is: ${live_timestamp}"
        msg_info "Certificate path is: ${live_fullchain}"

        if [ -f "$TARGET_CRT_PATH" ]; then
            local_timestamp=$(date -r ${TARGET_CRT_PATH} +%s)
            msg_info "Local certificate timestamp is: ${local_timestamp}"
            if [ $live_timestamp -gt $local_timestamp ]; then
                msg_info "Remote Certificate is newer then local. Copy new certificate"
                copy_remote_certs $cert_id
            elif [ $live_timestamp -lt $local_timestamp ]; then
                msg_error "Ahm.... Local certificate is newer then remote one... This is very weird. Stop here!"
                exit 1
            else
                msg_info "Local certificate is actual. Just exit"
                exit 0
            fi
        else
            msg_error "Local certificate not found, please check if ${TARGET_CRT_PATH} exist."
            while true; do
                read -p " - Do we need to copy new certificate in ${TARGET_CRT_PATH} (y/n)?" yn
                case $yn in
                [Yy]*) break ;;
                [Nn]*) clear; exit ;;
                *) echo "Please answer yes or no." ;;
                esac
            done
            copy_remote_certs $cert_id
            msg_info "All is OK. Now you can add this script into cron"
        fi
    fi
}

get_certificates

exit 0