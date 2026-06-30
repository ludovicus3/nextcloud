FROM php:8.3-fpm-trixie

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bzip2 \
      rsync \
      libmagickcore-7.q16-10-extra \
      libldap-common \
      libfcgi-bin \
    ; \
    apt-get dist-clean

RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      libcurl4-openssl-dev \
      libevent-dev \
      libfreetype6-dev \
      libgmp-dev \
      libicu-dev \
      libjpeg-dev \
      libldap2-dev \
      liblz4-dev \
      libmagickwand-dev \
      libmemcached-dev \
      libpng-dev \
      libpq-dev \
      libwebp-dev \
      libxml2-dev \
      libzip-dev \
    ; \
    \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    docker-php-ext-configure ftp --with-openssl-dir=/usr; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
    docker-php-ext-install -j "$(nproc)" \
      bcmath \
      exif \
      ftp \
      gd \
      gmp \
      intl \
      ldap \
      pcntl \
      pdo_mysql \
      pdo_pgsql \
      sysvsem \
      zip \
    ; \
    \
    pecl install APCu-5.1.28; \
    pecl install igbinary-3.2.16; \
    pecl install imagick-3.8.1; \
    pecl install --configureoptions 'enable-memcached-igbinary="yes"' \
        memcached-3.4.0; \
    pecl install --configureoptions 'enable-redis-igbinary="yes" enable-redis-zstd="yes" enable-redis-lz4="yes"' \
        redis-6.3.0; \
    \
    docker-php-ext-enable \
        apcu \
        igbinary \
        imagick \
        memcached \
        redis \
    ; \
    rm -r /tmp/pear; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -rt dpkg-query --search \
# https://manpages.debian.org/trixie/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
        | awk 'sub(":$", "", $1) { print $1 }' \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get dist-clean

ENV PHP_MEMORY_LIMIT=512M
ENV PHP_UPLOAD_LIMIT=512M
ENV PHP_OPCACHE_MEMORY_CONSUMPTION=128
COPY nextcloud.ini ${PHP_INI_DIR}/conf.d/
COPY php-fpm.conf /usr/local/etc/
RUN set -eux; \
    chown -R www-data:root /var/www; \
    chmod -R g=u /var/www

VOLUME /var/www/html

ENV NEXTCLOUD_VERSION=33.0.6

RUN set -ex; \
    fetchDeps=" \
        gnupg \
        dirmngr \
    "; \
    apt-get update; \
    apt-get install -y --no-install-recommends $fetchDeps; \
    \
    curl -fsSL -o nextcloud.tar.bz2 "https://github.com/nextcloud-releases/server/releases/download/v${NEXTCLOUD_VERSION}/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2"; \
    curl -fsSL -o nextcloud.tar.bz2.asc "https://github.com/nextcloud-releases/server/releases/download/v${NEXTCLOUD_VERSION}/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    # gpg key from https://nextcloud.com/nextcloud.asc
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 28806A878AE423A28372792ED75899B9A724937A; \
    gpg --batch --verify nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    tar -xjf nextcloud.tar.bz2 -C /usr/src/; \
    gpgconf --kill all; \
    rm nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    rm -rf "$GNUPGHOME" /usr/src/nextcloud/updater; \
    mkdir -p /usr/src/nextcloud/data; \
    mkdir -p /usr/src/nextcloud/custom_apps; \
    chmod +x /usr/src/nextcloud/occ; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
    apt-get dist-clean;
  
COPY *.sh upgrade.exclude /
COPY config/* /usr/src/nextcloud/config/
COPY php-fpm-healthcheck /usr/local/bin/

USER www-data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]