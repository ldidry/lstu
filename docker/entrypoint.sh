#!/bin/sh

set -eu

cd ~lstu

if [ "${1:-}" == "dev" ]
then
    echo ""
    echo ""
    echo "Container started in dev mode. Connect to the container with the following command:"
    echo "    docker-compose -f docker-compose.dev.yml exec -u root app_dev sh"
    echo ""
    echo ""
    echo "You can then install the build dependencies with this command"
    echo "    apk --update add vim build-base perl-utils perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev"
    
    tail -f /dev/null
    exit 0
fi

# If MySQL/PostgreSQL, wait for database to be up
DB_TYPE=$(perl utilities/read_conf.pl dbtype)
DB_HOST=
DB_PORT=
if [ "$DB_TYPE" == "mysql" ]
then
    DB_HOST=$(perl utilities/read_conf.pl mysqldb/host db)
    DB_PORT=$(perl utilities/read_conf.pl mysqldb/port 3306)
fi
if [ "$DB_TYPE" == "postgresql" ]
then
    DB_HOST=$(perl utilities/read_conf.pl pgdb/host db)
    DB_PORT=$(perl utilities/read_conf.pl pgdb/port 5432)
fi
if [ -n "$DB_HOST" -a -n "$DB_PORT" ]
then
    while ! nc -vz "${DB_HOST}" "${DB_PORT}"; do
        echo "Waiting for database..."
        sleep 1;
    done
fi

if [ "${1:-}" == "minion" ]
then
    exec carton exec script/application minion worker
fi

exec carton exec hypnotoad -f script/lstu