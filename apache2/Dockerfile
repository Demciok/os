FROM ubuntu:latest
MAINTAINER Mateusz Mucha
RUN apt-get update && \
apt-get install -y apache2 && \
apt-get clean
# Ustawienie ścieżki dla logów dziennika
ENV APACHE_LOG_DIR /var/log/apache2
# Uruchom serwer apache2 w pierwszym planie
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]