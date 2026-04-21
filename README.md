# rsdk-php

Official Docker images suitable for PHP Developer RSDK

## Supported PHP Versions

- `7.4`
- `8.0`
- `8.1`
- `8.2`
- `8.3`
- `8.4`
- `8.5`

`php-dev` and `php-nginx` use `-fpm` variants. `php-apache` uses `-apache` variants.

For `php-nginx`, the container runs both `nginx` and `php-fpm` under `supervisord`.
Nginx forwards PHP requests through Unix socket `/var/run/php-fpm.sock`.

## MSSQL Profiles

- `legacy` (default): ODBC 17 + OpenSSL compatibility downgrade for SQL Server `2008` and `2012`
- `modern` (optional): ODBC 18 for newer SQL Server deployments

Legacy profile applies this OpenSSL patch inside the image:

```sh
sed -i 's/CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=0\nMinProtocol = TLSv1.0/g' /etc/ssl/openssl.cnf
```

## Enabled PHP Extensions

Core and commonly used:

- `pdo_mysql`
- `mysqli`
- `mbstring`
- `exif`
- `pcntl`
- `bcmath`
- `intl`
- `zip`
- `soap`
- `opcache`
- `ftp`
- `pdo_pgsql`
- `gd` (configured with freetype and jpeg)

Database, cache, and drivers:

- `mongodb`
- `redis`
- `sqlsrv`
- `pdo_sqlsrv`

Developer and utilities:

- `xdebug`
- `imagick`

## Using Published Images from Docker Hub

Published images are pushed to Docker Hub as `rskariadi/rsdk-php` with tags like:

- `dev-php7.4-legacy`
- `dev-php8.2-legacy`
- `nginx-php8.4-legacy`
- `apache-php8.1-legacy`

Pull an image:

```sh
docker pull rskariadi/rsdk-php:dev-php8.2-legacy
```

Run a PHP shell inside the image:

```sh
docker run --rm -it \
  -v "$PWD":/app \
  -w /app \
  rskariadi/rsdk-php:dev-php8.2-legacy \
  bash
```

Run Composer from the published image:

```sh
docker run --rm -it \
  -v "$PWD":/app \
  -w /app \
  rskariadi/rsdk-php:dev-php8.2-legacy \
  composer install
```

Use the published image in `docker-compose.yml` by overriding the image name:

```yaml
services:
  php-dev:
    image: rskariadi/rsdk-php:dev-php8.2-legacy
```

Complete `docker-compose.yml` example (no local build):

```yaml
services:
  php-dev:
    image: rskariadi/rsdk-php:dev-php8.2-legacy
    container_name: rsdk-php-dev
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "9000:9000"
    environment:
      PHP_ENABLE_XDEBUG: 1

  php-nginx:
    image: rskariadi/rsdk-php:nginx-php8.2-legacy
    container_name: rsdk-php-nginx
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8080:80"

  php-apache:
    image: rskariadi/rsdk-php:apache-php8.2-legacy
    container_name: rsdk-php-apache
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8081:80"
```

Run the published-image stack:

```sh
docker compose up -d
```

Run with modern MSSQL profile image tags (if published):

```yaml
services:
  php-dev:
    image: rskariadi/rsdk-php:dev-php8.2-modern
```

If you need the web server variant, use the matching tag:

```sh
docker pull rskariadi/rsdk-php:nginx-php8.2-legacy
docker pull rskariadi/rsdk-php:apache-php8.2-legacy
```

## Local Usage (docker-compose)

Default:

```sh
docker compose up --build
```

Custom PHP versions:

```sh
PHP_DEV_BASE_IMAGE_VERSION=8.3-fpm \
PHP_NGINX_BASE_IMAGE_VERSION=8.3-fpm \
PHP_APACHE_BASE_IMAGE_VERSION=8.3-apache \
docker compose up --build
```

Use legacy MSSQL profile for SQL Server 2008/2012:

```sh
docker compose up --build php-dev
```

Use modern MSSQL profile only when needed:

```sh
MSSQL_PROFILE=modern docker compose up --build php-dev
```

Dedicated legacy service:

```sh
docker compose up --build php-dev-legacy
```

## CI/CD Matrix

Workflow `.github/workflows/docker-publish.yml` now:

- Builds and tests matrix PHP `7.4` through `8.5`
- Builds targets: `dev`, `nginx`, `apache`
- Uses MSSQL profile `legacy` as default CI baseline
- Runs a preflight legacy job first (`dev + PHP 7.4`) before full matrix
- Runs extension smoke checks and validates OpenSSL legacy config
- Pushes tags in format:
  - `rskariadi/rsdk-php:dev-php7.4-legacy`
  - `rskariadi/rsdk-php:dev-php8.2-legacy`
  - `rskariadi/rsdk-php:nginx-php8.4-legacy`
  - `rskariadi/rsdk-php:apache-php8.1-legacy`

Notes for web targets:

- `nginx` target starts via `supervisord` to run `nginx` and `php-fpm` in one container.
- `nginx` target uses FastCGI Unix socket (`/var/run/php-fpm.sock`) instead of service hostname.
- `apache` target relies on `php:<version>-apache` base image and does not reinstall Apache via apt.

## Compatibility Notes

- SQL Server extension `sqlsrv` and `pdo_sqlsrv` are skipped on PHP `8.5` preview builds until official compatibility is available.
