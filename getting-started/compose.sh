#!/bin/bash

yum check-update -y
yum upgrade -y

systemctl daemon-reload
systemctl start docker
systemctl enable docker

curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose

docker-compose version

docker-compose up -d