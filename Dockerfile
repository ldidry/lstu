FROM alpine:3.7

RUN adduser -D lstu
COPY --chown=lstu:lstu . /home/lstu
WORKDIR /home/lstu
RUN apk --update add ca-certificates perl perl-netaddr-ip perl-dbd-pg mariadb-client-libs libpng zlib \
 && apk add --virtual .build-deps build-base perl-utils perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev \
 && cpan Carton \
 && sudo -u lstu carton install --deployment --without=test \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/*
USER lstu

ENTRYPOINT ["/bin/sh", "/home/lstu/docker/entrypoint.sh"]