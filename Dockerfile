FROM alpine:3.19

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
RUN apk --update add ca-certificates perl perl-netaddr-ip perl-io-socket-ssl perl-dbd-pg mariadb-connector-c-dev libpng zlib openssl perl-dbd-mysql
RUN apk add --virtual .build-deps build-base perl-utils perl-dev make sudo zlib-dev libpng-dev postgresql-dev mariadb-dev openssl-dev
RUN cpan -T Carton
RUN sudo -u lstu carton install --deployment --without=test --without=cache
RUN perl -MCPAN -e 'install inc::latest'
RUN perl -MCPAN -e 'install Config::FromHash'
RUN apk del .build-deps
RUN rm -rf /var/cache/apk/*
USER lstu

ENTRYPOINT ["/bin/sh", "/home/lstu/docker/entrypoint.sh"]
