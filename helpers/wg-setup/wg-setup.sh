#!/bin/bash

set -euo pipefail

# Yandex DNS
DNS1=77.88.8.88
DNS2=77.88.8.2

# Server external IP address
SERVER_IPADDR=${1}

# Server keys
SERVER_PRIVATEKEY=$(wg genkey)
SERVER_PUBLICKEY=$(echo ${SERVER_PRIVATEKEY} | wg pubkey)

# Client keys
CLIENT_PRIVATEKEY=$(wg genkey)
CLIENT_PUBLICKEY=$(echo ${CLIENT_PRIVATEKEY} | wg pubkey)

umask 077

#rm -Ivr /tmp/wg-conf-*
WGCONF_DIR=$(mktemp --directory --tmpdir "wg-conf-XXXXXXXXXX")
SERVER_DIR=$(mktemp --directory --tmpdir=${WGCONF_DIR} "server-XXXXXXXXXX")
CLIENT_DIR=$(mktemp --directory --tmpdir=${WGCONF_DIR} "client-XXXXXXXXXX")

# WireGuard server config
cat > ${SERVER_DIR}/wg0.conf <<EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = 34567
Privatekey = ${SERVER_PRIVATEKEY}
PostUp = ${SERVER_DIR}/post-up
#PostDown =

[Peer]
PublicKey = ${CLIENT_PUBLICKEY}
AllowedIPs = 10.20.0.101/24
EOF
cp post-up ${SERVER_DIR}/

# WireGuard client config
cat > ${CLIENT_DIR}/wg1.conf <<EOF
[Interface]
Address = 10.20.0.101/24
Privatekey = ${CLIENT_PRIVATEKEY}
DNS = ${DNS1}, ${DNS2}

[Peer]
PublicKey = ${SERVER_PUBLICKEY}
AllowedIPs = 10.20.0.0/24, 0.0.0.0/0
Endpoint = ${SERVER_IPADDR}:34567
PersistentKeepalive = 25
EOF
qrencode -t ansiutf8 < ${CLIENT_DIR}/wg1.conf > ${CLIENT_DIR}/qr.txt

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
