#!/bin/bash

set -euo pipefail

# Server external IP address
SERVER_IPADDR=${1}
SERVER_PORT=34567

# Yandex DNS
DNS1=77.88.8.88
DNS2=77.88.8.2

# WireGuard server config

# [Interface] section
function gen::server::interface()
{
    local config=${1}
    local privatekey=${2}
    local postup=${3}

    # Note: overwrite the existing file
    cat > ${config} <<EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = ${SERVER_PORT}
Privatekey = ${privatekey}
PostUp = ${postup}
#PostDown =
EOF
}

# [Peer] section
function gen::server::peer()
{
    local config=${1}
    local publickey=${2}
    local ipaddr=${3}

    # Note: append to the existing file
    cat >> ${config} <<EOF
[Peer]
PublicKey = ${publickey}
AllowedIPs = ${ipaddr}
EOF
}

# WireGuard client config

# [Interface] section
function gen::client::interface()
{
    local config=${1}
    local ipaddr=${2}
    local privatekey=${3}

    # Note: overwrite the existing file
    cat > ${config} <<EOF
[Interface]
Address = ${ipaddr}
Privatekey = ${privatekey}
DNS = ${DNS1}, ${DNS2}
EOF
}

# [Peer] section
function gen::client::peer()
{
    local config=${1}
    local publickey=${2}
    local ipaddr=${3}

    # Note: append to the existing file
    cat >> ${config} <<EOF
[Peer]
PublicKey = ${publickey}
AllowedIPs = 10.20.0.0/24, 0.0.0.0/0
Endpoint = ${ipaddr}:${SERVER_PORT}
PersistentKeepalive = 25
EOF
}

# Generate new WireGuard server and client configs

umask 077

#rm -Ivr /tmp/wg-conf-*
WGCONF_DIR=$(mktemp --directory --tmpdir "wg-conf-XXXXXXXXXX")

# Server vars
SERVER_DIR=$(mktemp --directory --tmpdir=${WGCONF_DIR} "server-XXXXXXXXXX")
SERVER_CONFIG=${SERVER_DIR}/wg0.conf
SERVER_PRIVATEKEY=$(wg genkey)
SERVER_PUBLICKEY=$(echo ${SERVER_PRIVATEKEY} | wg pubkey)
SERVER_POSTUP=${SERVER_DIR}/post-up

# Client vars
CLIENT_DIR=$(mktemp --directory --tmpdir=${WGCONF_DIR} "client-XXXXXXXXXX")
CLIENT_CONFIG=${CLIENT_DIR}/wg1.conf
CLIENT_PRIVATEKEY=$(wg genkey)
CLIENT_PUBLICKEY=$(echo ${CLIENT_PRIVATEKEY} | wg pubkey)
CLIENT_IPADDR=10.20.0.101/24
CLIENT_QR=${CLIENT_DIR}/qr.txt

# WireGuard server config
gen::server::interface ${SERVER_CONFIG} ${SERVER_PRIVATEKEY} ${SERVER_POSTUP}
gen::server::peer ${SERVER_CONFIG} ${CLIENT_PUBLICKEY} ${CLIENT_IPADDR}
cp post-up ${SERVER_DIR}/

# WireGuard client config
gen::client::interface ${CLIENT_CONFIG} ${CLIENT_IPADDR} ${CLIENT_PRIVATEKEY}
gen::client::peer ${CLIENT_CONFIG} ${SERVER_PUBLICKEY} ${SERVER_IPADDR}
qrencode -t ansiutf8 < ${CLIENT_CONFIG} > ${CLIENT_QR}

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
cat <<EOF
Configs written to ${WGCONF_DIR}
Copy ${SERVER_DIR} to ${SERVER_IPADDR}:
  ssh ${SSH_OPTS} root@${SERVER_IPADDR} "mkdir -p ${WGCONF_DIR}"
  scp ${SSH_OPTS} -r ${SERVER_DIR} root@${SERVER_IPADDR}:${WGCONF_DIR}/
To start the server run:
  ssh ${SSH_OPTS} root@${SERVER_IPADDR}
  wg-quick up ${SERVER_DIR}/wg0.conf
EOF
