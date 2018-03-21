#!/bin/sh

set -eu

cd ~lstu

if [ "${1:-}" == "dev" ]
then
    echo ""
    echo ""
    echo "Container started in dev mode. Connect to the container with the following command:"
    echo "    docker-compose exec -u root app_dev sh"
    echo ""
    echo ""
    echo "You can then install the build dependencies with this command"
    echo "    apk --update add vim build-base perl-utils perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev"
    
    tail -f /dev/null
    exit 0
fi

carton exec hypnotoad -f script/lstu