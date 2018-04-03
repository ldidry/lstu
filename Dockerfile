FROM debian:jessie-slim

# install operating system level packages
RUN apt-get -y update \
        && apt-get -y install \
            build-essential \
            libmysqld-dev \
            libpng-dev \
            libpq-dev \
            libssl-dev \
            openssl \
        && rm -rf /var/lib/apt/lists/*

# install Carton
RUN cpan Carton \
        && rm -rf ~/.cpan

# install LSTU
COPY . /lstu/
WORKDIR /lstu
RUN rm -rf log \
        && make installdeps \
        && rm -rf local/cache \
        && rm -rf ~/.cpanm

# run as uid/gid daemon:daemon
USER daemon:daemon

# start lstu web server
ENTRYPOINT [ "carton", "exec", "hypnotoad", "-f", "script/lstu" ]
