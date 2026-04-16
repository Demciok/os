#!/bin/bash
docker build -t apache2 .
docker images
docker run -d --name apache2-container -p 8080:80 apache2