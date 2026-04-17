# ============================================
# Base Stage: PHP + Extensions
# ============================================
ARG PHP_BASE_IMAGE_VERSION=8.2-fpm
ARG MSSQL_PROFILE=legacy
FROM php:${PHP_BASE_IMAGE_VERSION} AS base

ARG MSSQL_PROFILE

# Install dependencies & Microsoft ODBC driver/profile
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 apt-transport-https curl unzip git libzip-dev libicu-dev \
        libgssapi-krb5-2 unixodbc unixodbc-dev libmagickwand-dev \
        libxml2-dev libpq-dev libonig-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev zlib1g-dev pkg-config \
    && mkdir -p /etc/apt/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
        && if [ "$MSSQL_PROFILE" = "legacy" ]; then \
                 ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools; \
                 sed -i 's/CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=0\\nMinProtocol = TLSv1.0/g' /etc/ssl/openssl.cnf; \
             else \
                 ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18; \
             fi \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions via mlocati/php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j$(nproc) \
        pdo_mysql mysqli mbstring exif pcntl bcmath intl zip soap opcache ftp pdo_pgsql gd

RUN set -eux; \
    php -v; \
    php -m | sort

RUN set -eux; \
    install-php-extensions imagick mongodb redis xdebug

RUN set -eux; \
    php -v; \
    php -m | sort

RUN set -eux; \
    PHP_MM="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"; \
    if [ "$PHP_MM" = "8.5" ]; then \
        echo "Skipping sqlsrv/pdo_sqlsrv on PHP 8.5 preview"; \
    else \
        install-php-extensions sqlsrv pdo_sqlsrv; \
    fi

# Set environment & working dir
ENV PATH="/app:/app/vendor/bin:/root/.composer/vendor/bin:$PATH" \
    PHP_USER_ID=33 \
    PHP_ENABLE_XDEBUG=0 \
    COMPOSER_ALLOW_SUPERUSER=1
WORKDIR /app

# Copy PHP base configs
COPY image-files/base/php.ini /usr/local/etc/php/conf.d/
COPY image-files/base/.bashrc /root/

# Add non-root user for better security
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# ============================================
# Composer Stage
# ============================================
FROM base AS composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# ============================================
# Dev Stage
# ============================================
FROM composer AS dev
USER root
RUN apt-get update && apt-get install -y --no-install-recommends procps supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy dev configs
COPY image-files/dev/xdebug.ini /usr/local/etc/php/conf.d/
COPY image-files/dev/error_reporting.ini /usr/local/etc/php/conf.d/
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

# ============================================
# Nginx Stage
# ============================================
FROM dev AS nginx
USER root
RUN apt-get update && apt-get install -y --no-install-recommends nginx-full \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_NGINX=true
COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443
CMD ["php-fpm"]

# ============================================
# Apache Stage
# ============================================
FROM dev AS apache
USER root
RUN apt-get update && apt-get install -y --no-install-recommends apache2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_APACHE=true
COPY image-files/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

EXPOSE 80 443
CMD ["apache2-foreground"]

# ============================================
# Aliases for docker-compose
# ============================================
FROM dev AS php-dev
FROM nginx AS php-nginx
FROM apache AS php-apache
