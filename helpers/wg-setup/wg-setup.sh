#!/bin/bash

set -euo pipefail

# Server external IP address
SERVER_IPADDR=${1}
SERVER_PORT=34567

# Number of client configs to generate
NUM_CLIENTS=${2:-1}

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
AllowedIPs = ${ipaddr}/32
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
Address = ${ipaddr}/24
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

SERVER_DIR=${WGCONF_DIR}/server
SERVER_CONFIG=${SERVER_DIR}/wg0.conf
SERVER_PRIVATEKEY=$(wg genkey)
SERVER_PUBLICKEY=$(echo ${SERVER_PRIVATEKEY} | wg pubkey)
SERVER_POSTUP=${SERVER_DIR}/post-up

mkdir -p ${SERVER_DIR}
cp post-up ${SERVER_POSTUP}
gen::server::interface ${SERVER_CONFIG} ${SERVER_PRIVATEKEY} ${SERVER_POSTUP}

for i in $(seq ${NUM_CLIENTS}); do
    CLIENT_DIR=${WGCONF_DIR}/client${i}
    CLIENT_CONFIG=${CLIENT_DIR}/wg${i}.conf
    CLIENT_PRIVATEKEY=$(wg genkey)
    CLIENT_PUBLICKEY=$(echo ${CLIENT_PRIVATEKEY} | wg pubkey)
    CLIENT_IPADDR=10.20.0.10${i}
    CLIENT_QR=${CLIENT_DIR}/qr.txt

    gen::server::peer ${SERVER_CONFIG} ${CLIENT_PUBLICKEY} ${CLIENT_IPADDR}

    mkdir -p ${CLIENT_DIR}
    gen::client::interface ${CLIENT_CONFIG} ${CLIENT_IPADDR} ${CLIENT_PRIVATEKEY}
    gen::client::peer ${CLIENT_CONFIG} ${SERVER_PUBLICKEY} ${SERVER_IPADDR}
    qrencode -t ansiutf8 < ${CLIENT_CONFIG} > ${CLIENT_QR}
done

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
