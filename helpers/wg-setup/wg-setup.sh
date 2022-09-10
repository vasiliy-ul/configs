#!/bin/bash

set -euo pipefail

# Yandex DNS
DNS1=77.88.8.88
DNS2=77.88.8.2

# Server external IP address
SERVER_IPADDR=192.168.1.14

# Server keys
SERVER_PRIVATEKEY=$(wg genkey)
SERVER_PUBLICKEY=$(echo ${SERVER_PRIVATEKEY} | wg pubkey)

# Client keys
CLIENT_PRIVATEKEY=$(wg genkey)
CLIENT_PUBLICKEY=$(echo ${CLIENT_PRIVATEKEY} | wg pubkey)

umask 077

# WireGuard server config
cat > wg0.conf <<EOF
[Interface]
Address = 10.20.0.1/24
ListenPort = 34567
Privatekey = ${SERVER_PRIVATEKEY}
PostUp = $(pwd)/post-up
#PostDown =

[Peer]
PublicKey = ${CLIENT_PUBLICKEY}
AllowedIPs = 10.20.0.101/24
EOF

# WireGuard client config
cat > wg1.conf <<EOF
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
qrencode -t ansiutf8 < wg1.conf
