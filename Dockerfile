FROM ubuntu:18.04
FROM alpine:3.7

RUN adduser -D lstu
COPY --chown=lstu:lstu . /home/lstu
WORKDIR /home/lstu
RUN apk --update add \
        ca-certificates perl-dbi perl perl-utils make perl-net-ssleay \
        perl-crypt-ssleay perl-lwp-protocol-https mariadb-client-libs \
 && apk add --virtual .build-deps build-base perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev \
 && cpan Carton \
 && sudo -u lstu carton install --deployment --without=test \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/*
USER lstu

ENTRYPOINT ["/bin/sh", "/home/lstu/docker/entrypoint.sh"]