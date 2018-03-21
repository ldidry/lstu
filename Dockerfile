FROM ubuntu:18.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libssl-dev libpq-dev libmysqld-dev libpng-dev libnet-ssleay-perl libcrypt-ssleay-perl
RUN cpan Carton \
 && useradd -m -d /home/lstu -u 1000 -s /bin/bash lstu

COPY --chown=lstu:lstu . /home/lstu

WORKDIR /home/lstu
USER lstu
RUN make installdeps

ENTRYPOINT ["/bin/bash", "/home/lstu/docker/entrypoint.sh"]