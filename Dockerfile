ARG nominatim_version=3.5.2

FROM rclone/rclone:1.53 AS rclone

FROM postgis/postgis:13-3.0 as builder
ARG nominatim_version

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && \
   apt-get install -y -qq --no-install-recommends \
      build-essential \
      cmake \
      g++ \
      libboost-dev \
      libboost-system-dev \
      libboost-filesystem-dev \
      libexpat1-dev \
      zlib1g-dev \
      libxml2-dev \
      libbz2-dev \
      libpq-dev \
      libgeos-dev \
      libgeos++-dev \
      libproj-dev \
      postgresql-server-dev-13 \
      php \
      curl

# Build Nominatim
RUN cd /srv \
 && curl --silent -L http://www.nominatim.org/release/Nominatim-${nominatim_version}.tar.bz2 -o v${nominatim_version}.tar.bz2 \
 && tar xf v${nominatim_version}.tar.bz2 \
 && rm v${nominatim_version}.tar.bz2 \
 && mv Nominatim-${nominatim_version} nominatim \
 && cd nominatim \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make


FROM postgis/postgis:13-3.0
ARG nominatim_version

RUN apt-get -y update && \
   apt-get install -y -qq --no-install-recommends \
      postgresql-server-dev-13 \
      postgresql-contrib-13 \
      apache2 \
      php \
      php-pgsql \
      libapache2-mod-php \
      libboost-filesystem-dev \
      php-pear \
      php-intl \
      python3-dev \
      python3-psycopg2 \
      curl \
      ca-certificates \
      sudo && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* && \
   rm -rf /tmp/* /var/tmp/*

COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone
COPY --from=builder /srv/nominatim /srv/nominatim
COPY local.php /srv/nominatim/build/settings/local.php
COPY nominatim.conf /etc/apache2/sites-enabled/000-default.conf

RUN echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/13/main/pg_hba.conf \
 && echo "listen_addresses='*'" >> /etc/postgresql/13/main/postgresql.conf

COPY docker-entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

EXPOSE 8080
