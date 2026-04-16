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

if ! systemctl is-active --quiet sshd; then
    systemctl start sshd
fi

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

curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker volume create portainer_data >/dev/null 2>&1
docker rm -f portainer >/dev/null 2>&1
docker run -d \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

docker rm -f alpine-ping >/dev/null 2>&1
docker run -d --name alpine-ping alpine sh -c "ping wp.pl"

docker build -t apache2 ./apache2
docker run -d --name apache2-container -p 8080:80 apache2

cd getting-started && docker-compose up -d && cd ..

cd php-db-wordpress && docker-compose up -d && cd ..

docker version
docker images
sudo -u "$USERNAME" ls -a

echo "Portainer: http://localhost:9000"
echo "Koniec 🚀"