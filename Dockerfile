# ===============================
# BASE MINIMAL IMAGE
# ===============================
ARG PHP_BASE_IMAGE_VERSION
FROM php:${PHP_BASE_IMAGE_VERSION} as min

# Install dependencies + SQL Server ODBC
RUN apt-get update && apt-get install -y \
    unzip git curl gnupg2 apt-transport-https unixodbc unixodbc-dev libicu-dev \
    libmagickwand-dev libzip-dev libgssapi-krb5-2 procps \
    && mkdir -p /etc/apt/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions via installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    intl bcmath gd exif zip opcache \
    mysqli pdo_mysql pdo_pgsql \
    imagick soap pcntl

# Install SQL Server PHP extensions (pdo_sqlsrv)
RUN pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv

# Copy base configs
COPY image-files/base/php.ini /usr/local/etc/php/conf.d/
COPY image-files/base/.bashrc /root/

# Enable Apache mod_rewrite jika ada Apache
RUN if command -v a2enmod >/dev/null 2>&1; then \
        a2enmod rewrite headers \
    ;fi

WORKDIR /app
RUN chmod 755 /usr/local/bin/docker-php-entrypoint

ENV PHP_USER_ID=33 \
    PATH=/app:/app/vendor/bin:/root/.composer/vendor/bin:$PATH \
    TERM=linux


# ===============================
# DEV IMAGE
# ===============================
FROM min as dev

# Install dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git unzip procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Git config
RUN git config --global core.autocrlf input

# Install MongoDB & Xdebug tanpa versi
RUN install-php-extensions mongodb xdebug

# Copy dev configs
COPY image-files/dev/xdebug.ini /usr/local/etc/php/conf.d/
COPY image-files/dev/error_reporting.ini /usr/local/etc/php/conf.d/

# Disable xdebug by default
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

# Install Composer setelah PHP siap
RUN install-php-extensions openssl phar zip \
    && curl -fsSL https://getcomposer.org/installer | php -- \
        --filename=composer \
        --install-dir=/usr/local/bin \
    && chmod +x /usr/local/bin/composer \
    && composer --version \
    && composer clear-cache

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_ENABLE_XDEBUG=0


# ===============================
# NGINX IMAGE (MIN)
# ===============================
FROM min as nginx-min
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx-full cron supervisor procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf

# Log forwarding
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /usr/sbin/cron /usr/sbin/crond

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
EXPOSE 80 443


# ===============================
# NGINX IMAGE (DEV)
# ===============================
FROM dev as nginx-dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx-full cron supervisor procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY image-files/nginx/default.conf /etc/nginx/conf.d/default.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -sf /usr/sbin/cron /usr/sbin/crond

ENV SUPERVISOR_START_FPM=true \
    SUPERVISOR_START_NGINX=true

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
EXPOSE 80 443
