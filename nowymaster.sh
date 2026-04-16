#!/bin/bash
set -e

# 1. Przygotowanie systemu
yum check-update -y || true
yum upgrade -y
systemctl enable --now docker

# 2. Użytkownik i narzędzia
USERNAME=student
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G sudo,docker "$USERNAME"
    echo "student:student" | chpasswd
fi

yum install -y nano unzip curl
systemctl enable --now sshd

# 3. Konfiguracja sieci (systemd-networkd)
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

# 4. Instalacja docker-compose v2.26.1
curl -sL "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# --- ZADANIE 1: Budowa obrazu apache2 ---
mkdir -p apache2
cat <<'EOF' > apache2/Dockerfile
FROM ubuntu:latest
LABEL maintainer="Student PWr"
RUN apt-get update && \
    apt-get install -y apache2 && \
    apt-get clean
ENV APACHE_LOG_DIR /var/log/apache2
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
EOF

docker build -t apache2 ./apache2
docker rm -f apache2-container 2>/dev/null || true
docker run -d --name apache2-container -p 8080:80 apache2

# --- ZADANIE 2 & 3: Python + Redis (Getting Started) ---
mkdir -p getting-started
cat <<'EOF' > getting-started/app.py
import time
import redis
from flask import Flask
app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)
def get_hit_count():
    retries = 5
    while True:
        try: return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0: raise exc
            retries -= 1
            time.sleep(0.5)
@app.route('/')
def hello():
    count = get_hit_count()
    return f'Hello World! I have been seen {count} times.\n'
EOF

echo -e "flask\nredis" > getting-started/requirements.txt

cat <<'EOF' > getting-started/Dockerfile
FROM python:3.10-alpine
WORKDIR /code
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
RUN apk add --no-cache gcc musl-dev linux-headers
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
EXPOSE 5000
COPY . .
CMD ["flask", "run"]
EOF

cat <<'EOF' > getting-started/docker-compose.yml
services:
  web:
    build: .
    ports:
      - "8000:5000"
  redis:
    image: "redis:alpine"
EOF

cd getting-started
docker-compose up -d
cd ..

# --- ZADANIE 4: WordPress + MariaDB + phpMyAdmin ---
mkdir -p php-db-wordpress
cat <<'EOF' > php-db-wordpress/docker-compose.yml
services:
  mariadb:
    image: mariadb:latest
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
    volumes:
      - db_data:/var/lib/mysql

  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "8081:80"
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - mariadb

  phpmyadmin:
    image: phpmyadmin:latest
    restart: always
    ports:
      - "8082:80"
    environment:
      PMA_HOST: mariadb
      MYSQL_ROOT_PASSWORD: rootpassword
    depends_on:
      - mariadb

volumes:
  db_data:
EOF

cd php-db-wordpress
docker-compose up -d
cd ..

# --- ZADANIE I (2025): Portainer CE ---
docker volume create portainer_data
docker run -d -p 9000:9000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

# --- Zadanie I.2.A: Alpine Ping ---
docker run -d --name alpine-ping alpine sh -c "ping wp.pl"

# Podsumowanie stanów
echo "Konfiguracja zakończona."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"