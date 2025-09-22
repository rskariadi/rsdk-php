# =========================
# Base Stage
# =========================
ARG PHP_BASE_IMAGE_VERSION
FROM php:${PHP_BASE_IMAGE_VERSION} as min

# Install dependencies minimal + SQL Server ODBC
RUN apt-get update && apt-get install -y \
    unzip git curl gnupg2 apt-transport-https unixodbc unixodbc-dev libicu-dev libmagickwand-dev libzip-dev \
    && mkdir -p /etc/apt/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 libgssapi-krb5-2 \
    && docker-php-ext-install pdo \
    && pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions via mlocati/php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions intl gd zip bcmath exif opcache mysqli pdo_mysql pdo_pgsql imagick mongodb xdebug

# Environment settings
ENV PHP_USER_ID=33 \
    PATH=/app:/app/vendor/bin:/root/.composer/vendor/bin:$PATH \
    TERM=linux

# Copy base config files
COPY image-files/base/php.ini /usr/local/etc/php/conf.d/
COPY image-files/base/.bashrc /root/

# Enable mod_rewrite untuk apache
RUN if command -v a2enmod >/dev/null 2>&1; then \
        a2enmod rewrite headers \
    ;fi

# Application environment
WORKDIR /app
RUN chmod 755 /usr/local/bin/docker-php-entrypoint


# =========================
# Dev Stage
# =========================
FROM min as php-dev

# Install dev tools
RUN apt-get update && apt-get -y install --no-install-recommends \
    git unzip procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Disable git's automatic conversion
RUN git config --global core.autocrlf input

# Copy dev config files
COPY image-files/dev/xdebug.ini /usr/local/etc/php/conf.d/
COPY image-files/dev/error_reporting.ini /usr/local/etc/php/conf.d/

# Disable xdebug by default
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

# Install Composer via script resmi, lebih stabil
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');" \
    && composer --version \
    && composer clear-cache

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_ENABLE_XDEBUG=0


# =========================
# Nginx Stage
# =========================
FROM php-dev as php-nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx-full cron supervisor procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /usr/sbin/cron /usr/sbin/crond

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
EXPOSE 80 443


# =========================
# Apache Stage
# =========================
FROM min as php-apache
RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 cron supervisor procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV SUPERVISOR_START_APACHE=true

COPY image-files/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /usr/sbin/cron /usr/sbin/crond

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
EXPOSE 80 443


# =========================
# Aliases untuk docker-compose
# =========================
FROM php-dev as dev
FROM php-nginx as nginx
FROM php-apache as apache
