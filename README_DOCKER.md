# Docker image of lstu

You can build a Docker image to start `lstu` in a breeze!

## What is bundled with this image

The image starts en `lstu` instance ready to work with a SQLite, MySQL or PostgreSQL database. It is based on alpine 3.7.

## Requirements

- Some knowledge of Docker
- Docker 17.06.0+

## Howto

### The `lstu.conf` file

Configure lstu as you would normally (duplicate the lstu.conf.template and updates it), but also update the hypnotoad's listen property to `0.0.0.0:8080` for the web server to listen to any ip/interface given by docker. 

### With plain Docker

You can build your own image of `lstu` with this command: `docker build --pull -t lstu .`

You will then be able to start a container with the following command (example for a SQLite backend):
```
docker run -p 8080:8080 -v "$(pwd)/lstu.conf:/home/lstu/lstu.conf" -v "$(pwd)/lstu.db:/home/lstu/lstu.db" lstu
```

### With docker-compose

With Docker Compose, starting a database and lstu is easier than never! You can look at the `docker-compose.yml` file exemple to start.

1. Duplicate the `lstu.conf.template` file and name it `lstu.conf`. This file will be used in the container as the lstu config file.
2. Simply execute this command in the source directory of lstu: `docker-compose up`

The first time you launch this command, Docker will download the mariadb image and build the lstu image. It will take some time (only this first time, as later everything will be cached).

### Development environment

The image is also set up for bootstraping a local development environment. Simply set the container command to `dev` to enter this mode (see the `docker-compose.dev.yml` file). The container is then waiting for you to connect on it. The local directory is bind mounted in the container so that every change you make on your host is available in the container.
Usage example:

Launch the container on a first terminal
```
$ docker-compose -f docker-compose.dev.yml up
```

Then connect to it with the root user (by default, a restricted user is used)
```Second terminal
$ docker-compose -f docker-compose.dev.yml exec -u root app_dev sh
```

## Unsupported

Actually, the Docker image is not suited to work with Minion.