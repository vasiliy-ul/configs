#!/bin/bash

set -euo pipefail

IPADDR=${1}

sshuttle \
    -r root@${IPADDR} \
    -e 'ssh -i /tmp/ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' \
    -x ${IPADDR} \
    -v --dns \
    0/0
