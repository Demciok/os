#!/bin/bash
set -e

# ============================================================
# Skrypt konfiguracyjny – Politechnika Wrocławska
# Realizuje zadania z dokumentów 2024 i 2025
# ============================================================

# ── Aktualizacja systemu ────────────────────────────────────
yum check-update -y || true
yum upgrade -y

systemctl daemon-reload
systemctl start docker
systemctl enable docker

# ── Użytkownik student ──────────────────────────────────────
USERNAME=student
if id "$USERNAME" &>/dev/null; then
    :
else
    useradd -m -G sudo,docker "$USERNAME"
    yes y | passwd "$USERNAME"
fi

# ── Narzędzia ───────────────────────────────────────────────
yum install -y nano unzip

if ! systemctl is-active --quiet sshd; then
    systemctl start sshd
fi

# ── Sieć DHCP ───────────────────────────────────────────────
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

# ── docker-compose ──────────────────────────────────────────
curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ============================================================
# ZADANIE 1 (2024): Budowa własnego obrazu apache2
# ============================================================
mkdir -p apache2

cat <<'DOCKERFILE' > apache2/Dockerfile
###########################################
# Dockerfile dla obrazu z apache2
###########################################
# Obraz bazowy Ubuntu
FROM ubuntu:latest
MAINTAINER Student PWr

# Instalacja pakietu apache2
RUN apt-get update && \
    apt-get install -y apache2 && \
    apt-get clean

# Ustawienie ścieżki dla logów dziennika
ENV APACHE_LOG_DIR /var/log/apache2

# Uruchom serwer apache2 w pierwszym planie
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
DOCKERFILE

docker build -t apache2 ./apache2
docker rm -f apache2-container >/dev/null 2>&1 || true
docker run -d --name apache2-container -p 8080:80 apache2
echo "✅ Zadanie 1 – apache2 działa na porcie 8080"

# ============================================================
# ZADANIE 2 & 3 (2024): getting-started (Python + Redis)
# https://docs.docker.com/compose/gettingstarted/
# ============================================================
mkdir -p getting-started

cat <<'PYEOF' > getting-started/app.py
import time
import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route('/')
def hello():
    count = get_hit_count()
    return f'Hello World! I have been seen {count} times.\n'
PYEOF

cat <<'REQEOF' > getting-started/requirements.txt
flask
redis
REQEOF

cat <<'DFEOF' > getting-started/Dockerfile
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
DFEOF

cat <<'DCEOF' > getting-started/docker-compose.yml
services:
  web:
    build: .
    ports:
      - "8000:5000"
  redis:
    image: "redis:alpine"
DCEOF

cd getting-started
docker-compose down -v >/dev/null 2>&1 || true
docker-compose up -d
cd ..
echo "✅ Zadanie 3 – getting-started działa na porcie 8000"

# ============================================================
# ZADANIE 4 (2024): WordPress + MariaDB + phpMyAdmin
# + ZADANIE I.2.C (2025): Ten sam stos uruchamiany też przez Portainer
# ============================================================
mkdir -p php-db-wordpress

# ETAP 1→2→3: wordpress + mariadb + phpmyadmin
cat <<'WPEOF' > php-db-wordpress/docker-compose.yml
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
WPEOF

cd php-db-wordpress
docker-compose down -v >/dev/null 2>&1 || true
docker-compose up -d
cd ..
echo "✅ Zadanie 4 – WordPress:8081 | phpMyAdmin:8082"

# ============================================================
# ZADANIE I (2025): Portainer CE – zarządzanie GUI
# ============================================================
docker volume create portainer_data >/dev/null 2>&1 || true
docker rm -f portainer >/dev/null 2>&1 || true
docker run -d \
    -p 9000:9000 \
    -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
echo "✅ Zadanie I – Portainer CE działa na porcie 9000"

# ── Zadanie I.2.A – alpine ping wp.pl ──────────────────────
docker rm -f alpine-ping >/dev/null 2>&1 || true
docker run -d --name alpine-ping alpine sh -c "ping wp.pl"
echo "✅ Zadanie I.2.A – alpine-ping uruchomiony"

# ── Zadanie I.2.C – stos WP przez Portainer ────────────────
# Stos wordpress+mariadb+phpmyadmin jest już uruchomiony przez
# docker-compose powyżej. Aby zademonstrować go PRZEZ Portainer:
# 1. Otwórz http://<IP>:9000
# 2. Wybierz środowisko: local
# 3. Przejdź do Stacks → Add stack
# 4. Wklej zawartość php-db-wordpress/docker-compose.yml
# Uwaga: najpierw zatrzymaj istniejący stos aby uniknąć konfliktu portów:
#   cd php-db-wordpress && docker-compose down -v && cd ..

# ── Podsumowanie ────────────────────────────────────────────
echo ""
echo "============================================================"
docker version
echo "------------------------------------------------------------"
docker images
echo "------------------------------------------------------------"
docker ps
echo "============================================================"
echo "🌐 Portainer        → http://localhost:9000"
echo "🌐 Apache2          → http://localhost:8080"
echo "🌐 Getting-started  → http://localhost:8000"
echo "🌐 WordPress        → http://localhost:8081"
echo "🌐 phpMyAdmin       → http://localhost:8082"
echo "============================================================"
echo "🚀 Koniec konfiguracji"