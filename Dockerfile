ARG PHP_BASE_IMAGE_VERSION=8.2-fpm

# =====================
# Stage 1: Base Image
# =====================
FROM php:${PHP_BASE_IMAGE_VERSION} as base

# Install dependencies untuk key & curl
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gnupg2 apt-transport-https ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
        https://packages.microsoft.com/debian/11/prod bullseye main" \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update

# Install php extension installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install base PHP extensions
RUN install-php-extensions intl

# Setup environment
ENV PHP_USER_ID=33 \
    PATH=/app:/app/vendor/bin:/root/.composer/vendor/bin:$PATH \
    TERM=linux

WORKDIR /app

# Copy konfigurasi base
COPY image-files/base/php.ini /usr/local/etc/php/php.ini
COPY image-files/base/.bashrc /root/.bashrc

RUN chmod 755 /usr/local/bin/docker-php-entrypoint

# Enable apache modules jika ada
RUN if command -v a2enmod >/dev/null 2>&1; then \
        a2enmod rewrite headers \
    ;fi


# =====================
# Stage 2: Development
# =====================
FROM base as dev

# Install tools & SQL Server driver
RUN ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        msodbcsql18 \
        mssql-tools18 \
        unixodbc-dev \
        git unzip procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Disable git auto-crlf
RUN git config --global core.autocrlf input

# Install PHP extensions untuk dev
RUN install-php-extensions \
    pcntl soap zip bcmath exif gd mysqli odbc sqlsrv pdo_odbc pdo_sqlsrv pdo_mysql pdo_pgsql imagick mongodb xdebug

# Copy konfigurasi dev
COPY image-files/dev/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
COPY image-files/dev/error_reporting.ini /usr/local/etc/php/conf.d/error_reporting.ini

# Matikan xdebug by default
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- \
        --filename=composer.phar \
        --install-dir=/usr/local/bin && \
    chmod +x /usr/local/bin/composer && \
    composer clear-cache

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_ENABLE_XDEBUG=0


# =====================
# Stage 3: Apache
# =====================
FROM base as apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 libapache2-mod-php \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy konfigurasi apache
COPY image-files/apache/000-default.conf /etc/apache2/sites-available/000-default.conf

CMD ["apache2-foreground"]

EXPOSE 80 443


# =====================
# Stage 4: Nginx Minimal
# =====================
FROM base as nginx-min

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx-full cron supervisor procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

# Copy konfigurasi nginx
COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && ln -sf /usr/sbin/cron /usr/sbin/crond

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

EXPOSE 80 443


# =====================
# Stage 5: Nginx Dev
# =====================
FROM dev as nginx-dev

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx-full cron supervisor procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

# Copy konfigurasi nginx
COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /var/log/nginx/error.log \
 && ln -sf /usr/sbin/cron /usr/sbin/crond

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

EXPOSE 80 443
