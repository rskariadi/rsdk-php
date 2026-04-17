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

## MSSQL Profiles

- `modern` (default): ODBC 18 for newer SQL Server deployments
- `legacy`: ODBC 17 + OpenSSL compatibility downgrade for SQL Server `2008` and `2012`

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
MSSQL_PROFILE=legacy docker compose up --build php-dev
```

Dedicated legacy service:

```sh
docker compose up --build php-dev-legacy
```

## CI/CD Matrix

Workflow `.github/workflows/docker-publish.yml` now:

- Builds and tests matrix PHP `7.4` through `8.5`
- Builds targets: `dev`, `nginx`, `apache`
- Tests MSSQL profiles: `modern` and `legacy` (`legacy` currently on `dev` target)
- Runs extension smoke checks and validates legacy OpenSSL config isolation
- Pushes tags in format:
  - `rskariadi/rsdk-php:dev-php8.2-modern`
  - `rskariadi/rsdk-php:dev-php7.4-legacy`
  - `rskariadi/rsdk-php:nginx-php8.4-modern`
  - `rskariadi/rsdk-php:apache-php8.1-modern`
