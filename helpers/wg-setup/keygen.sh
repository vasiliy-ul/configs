#!/bin/bash

set -euo pipefail

mkdir /tmp/ssh && pushd /tmp/ssh && ssh-keygen -f id_rsa -C tmp && popd
