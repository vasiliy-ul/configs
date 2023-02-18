#!/bin/bash

set -euo pipefail

IPADDR=${1}

ssh \
    -i /tmp/ssh/id_rsa \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    root@${IPADDR}
