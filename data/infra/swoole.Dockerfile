FROM php:7.4.11-alpine3.12
MAINTAINER Alejandro Celaya <alejandro@alejandrocelaya.com>

ENV APCU_VERSION 5.1.18
ENV APCU_BC_VERSION 1.0.5
ENV INOTIFY_VERSION 2.0.0
ENV SWOOLE_VERSION 4.5.9

RUN apk update

# Install common php extensions
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install iconv
RUN docker-php-ext-install calendar

RUN apk add --no-cache oniguruma-dev
RUN docker-php-ext-install mbstring

RUN apk add --no-cache sqlite-libs
RUN apk add --no-cache sqlite-dev
RUN docker-php-ext-install pdo_sqlite

RUN apk add --no-cache icu-dev
RUN docker-php-ext-install intl

RUN apk add --no-cache libzip-dev zlib-dev
RUN docker-php-ext-install zip

RUN apk add --no-cache libpng-dev
RUN docker-php-ext-install gd

RUN apk add --no-cache postgresql-dev
RUN docker-php-ext-install pdo_pgsql

RUN apk add --no-cache gmp-dev
RUN docker-php-ext-install gmp

# Install APCu extension
ADD https://pecl.php.net/get/apcu-$APCU_VERSION.tgz /tmp/apcu.tar.gz
RUN mkdir -p /usr/src/php/ext/apcu\
  && tar xf /tmp/apcu.tar.gz -C /usr/src/php/ext/apcu --strip-components=1
# configure and install
RUN docker-php-ext-configure apcu\
  && docker-php-ext-install apcu
# cleanup
RUN rm /tmp/apcu.tar.gz

# Install APCu-BC extension
ADD https://pecl.php.net/get/apcu_bc-$APCU_BC_VERSION.tgz /tmp/apcu_bc.tar.gz
RUN mkdir -p /usr/src/php/ext/apcu-bc\
  && tar xf /tmp/apcu_bc.tar.gz -C /usr/src/php/ext/apcu-bc --strip-components=1
# configure and install
RUN docker-php-ext-configure apcu-bc\
  && docker-php-ext-install apcu-bc
# cleanup
RUN rm /tmp/apcu_bc.tar.gz

# Load APCU.ini before APC.ini
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini
RUN echo extension=apcu.so > /usr/local/etc/php/conf.d/20-php-ext-apcu.ini

# Install inotify extension
ADD https://pecl.php.net/get/inotify-$INOTIFY_VERSION.tgz /tmp/inotify.tar.gz
RUN mkdir -p /usr/src/php/ext/inotify\
  && tar xf /tmp/inotify.tar.gz -C /usr/src/php/ext/inotify --strip-components=1
# configure and install
RUN docker-php-ext-configure inotify\
  && docker-php-ext-install inotify
# cleanup
RUN rm /tmp/inotify.tar.gz

# Install swoole, pcov and mssql driver
RUN wget https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.5.1.1-1_amd64.apk && \
    apk add --allow-untrusted msodbcsql17_17.5.1.1-1_amd64.apk && \
    apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS unixodbc-dev && \
    pecl install swoole-${SWOOLE_VERSION} pdo_sqlsrv pcov && \
    docker-php-ext-enable swoole pdo_sqlsrv pcov && \
    apk del .phpize-deps && \
    rm msodbcsql17_17.5.1.1-1_amd64.apk

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Make home directory writable by anyone
RUN chmod 777 /home

VOLUME /home/shlink
WORKDIR /home/shlink

# Expose swoole port
EXPOSE 8080

CMD \
    # Install dependencies if the vendor dir does not exist
    if [[ ! -d "./vendor" ]]; then /usr/local/bin/composer install ; fi && \
    # When restarting the container, swoole might think it is already in execution
    # This forces the app to be started every second until the exit code is 0
    until php ./vendor/bin/laminas mezzio:swoole:start; do sleep 1 ; done
