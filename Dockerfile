FROM alpine:3.7

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Let's Shorten That URL" \
      org.label-schema.url="https://lstu.fr/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://framagit.org/fiat-tux/hat-softwares/lstu" \
      org.label-schema.vendor="Luc Didry" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

RUN adduser -D lstu
COPY --chown=lstu:lstu . /home/lstu
WORKDIR /home/lstu
RUN apk --update add ca-certificates perl perl-netaddr-ip perl-io-socket-ssl perl-dbd-pg mariadb-client-libs libpng zlib \
 && apk add --virtual .build-deps build-base perl-utils perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev \
 && cpan Carton \
 && sudo -u lstu carton install --deployment --without=test \
 && perl -MCPAN -e 'install inc::latest' \
 && perl -MCPAN -e 'install Config::FromHash' \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/*
USER lstu

ENTRYPOINT ["/bin/sh", "/home/lstu/docker/entrypoint.sh"]