#!/bin/bash

yum check-update -y
yum upgrade -y

systemctl daemon-reload

systemctl start docker
systemctl enable docker

USERNAME=student

if id "$USERNAME" &>/dev/null; then
    :
else
    useradd -m -G sudo,docker "$USERNAME"
    yes y | passwd "$USERNAME"
fi

yum install -y nano unzip

systemctl status sshd

if ! systemctl is-active --quiet sshd; then
    systemctl start sshd
fi

docker version

sudo -u "$USERNAME" ls -a

cat <<EOL > /etc/systemd/network/50-dhcp-en.network
[Match]
Name=e*

[Network]
DHCP=yes
IPv6AcceptRA=no

[DHCPv4]
ClientIdentifier=mac
EOL

systemctl restart systemd-networkd