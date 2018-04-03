FROM debian:stretch-slim

# install operating system level packages
RUN apt-get -y update \
        && apt-get -y install \
            build-essential \
            libmariadbclient-dev \
            libmariadbd-dev \
            libpng-dev \
            libpq-dev \
            libssl-dev \
            openssl \
        && rm -rf /var/lib/apt/lists/*

# install Carton
RUN cpan Carton \
        && cpan inc::Module::Install::DSL \
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
ENTRYPOINT [ "/lstu/utilities/docker-entrypoint.sh" ]
