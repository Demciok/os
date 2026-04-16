#!/bin/bash

systemctl start docker
systemctl enable docker

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

sleep 2

echo "Portainer: http://localhost:9000"