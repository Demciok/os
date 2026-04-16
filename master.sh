#!/bin/bash

echo "Start..."

bash setup/setup.sh
bash apache2/apache2.sh
bash getting-started/compose.sh
bash php-db-wordpress/php.sh
bash portainer/docker_lab.sh

docker images

echo "Koniec 🚀"