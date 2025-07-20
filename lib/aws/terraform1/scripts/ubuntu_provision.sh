#!/usr/bin/env bash

echo "==============================================="
echo "==== Provisioning virtual machine  ============"

apt update
apt upgrade -y
apt install ripgrep

cp /home/${user}/.ssh/authorized_keys /root/.ssh/authorized_keys
# cat /home/ubuntu/.ssh/authorized_keys >> /root/.ssh/authorized_keys
