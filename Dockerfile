# ============================================
# RSUP Dr. Kariadi PHP Docker Image - Final
# ============================================

ARG PHP_BASE_IMAGE_VERSION
FROM php:${PHP_BASE_IMAGE_VERSION} as base

# ============================================
# Fix Microsoft GPG Key untuk Debian 12 Bookworm
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg2 \
    && mkdir -p /etc/apt/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
        https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update

# ============================================
# Install minimal dependencies
# ============================================
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions intl opcache

# ============================================
# Base environment
# ============================================
ENV PHP_USER_ID=33 \
    PATH=/app:/app/vendor/bin:/root/.composer/vendor/bin:$PATH \
    TERM=linux \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_ENABLE_XDEBUG=0

# Copy base configs
COPY image-files/base/php.ini /usr/local/etc/php/conf.d/
COPY image-files/base/.bashrc /root/.bashrc

WORKDIR /app


# ============================================
# Development Stage
# ============================================
FROM base as dev

# Install dev tools & SQL Server driver
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git unzip procps msodbcsql18 unixodbc-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Git config
RUN git config --global core.autocrlf input

# Install PHP extensions untuk development
RUN install-php-extensions \
    pcntl soap zip bcmath exif gd mysqli odbc sqlsrv pdo_odbc pdo_sqlsrv pdo_mysql pdo_pgsql imagick mongodb xdebug

# Copy dev configs (Xdebug, error reporting)
COPY image-files/dev/ /usr/local/etc/php/conf.d/

# Disable xdebug by default
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --filename=composer.phar \
    --install-dir=/usr/local/bin \
    && composer clear-cache


# ============================================
# Apache Stage
# ============================================
FROM base as apache

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apache2 libapache2-mod-php \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Enable rewrite module
RUN a2enmod rewrite headers

# Copy Apache configs
COPY image-files/apache/ /etc/apache2/sites-available/

EXPOSE 80
CMD ["apache2-foreground"]


# ============================================
# Nginx Stage (Production)
# ============================================
FROM base as nginx

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx supervisor cron procps \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

# Copy Nginx configs
COPY image-files/nginx/ /etc/nginx/conf.d/

# Log binding
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /usr/sbin/cron /usr/sbin/crond

EXPOSE 80 443
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
