# Lstu Docker Howto

These instructions will show you how to get started running Lstu using the
[Docker](https://www.docker.com/) container platform. General familiarity with
Docker is recommended.

## Building the Docker image

This image can be built using the `docker build` command:

    docker build --pull -t lstu .

## Usage

The Docker image assumes that the configuration file and all other persistent
data is located within the Docker container at `/lstu-data`. This directory
must be mounted into your container from your host system.

Create a directory on your host system to store the important configuration
information. Set the permissions to match the user/group `daemon:daemon` within
the container (uid/gid 1/1).

    mkdir /path/to/lstu-data
    chown -R 1:1 /path/to/lstu-data

If no configuration file is present, the container will create a minimal
configuration file when it starts. This configuration file will provide you
with reasonable defaults. You can customize this file later, as necessary for
your deployment. Please see [lstu.conf.template](lstu.conf.template) for the
full list of configuration options.

Now we can run our container on port 8080 using the `lstu-data` directory from
our host system:

    docker run --daemon --name=lstu -p 8080:8080 -v /path/to/lstu-data:/lstu-data lstu

For more advanced scenarios, please refer to the many Docker tutorials
available online.
