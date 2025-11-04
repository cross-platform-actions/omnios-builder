#!/bin/sh

set -eux
set -o pipefail

configure_ssh() {
  sed -i -E 's/PermitRootLogin no/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config

  cat <<EOF >> /mnt/etc/ssh/sshd_config
PasswordAuthentication yes
PubkeyAuthentication yes
UseDNS no
AcceptEnv *
PermitEmptyPasswords yes
EOF
}

configure_ssh
