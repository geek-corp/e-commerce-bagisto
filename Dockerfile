# Étnicos Tienda Accesorios - Production Dockerfile
# Bagisto 2.4.x on PHP 8.3-FPM

FROM php:8.3-fpm AS base

ARG WWWGROUP=1000
ARG WWWUSER=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    gd \
    zip \
    intl \
    bcmath \
    opcache \
    pcntl \
    mbstring \
    xml \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY docker/php/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN groupadd --force -g $WWWGROUP sail \
    && useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u $WWWUSER sail

WORKDIR /var/www/html

# ------- Build stage: install deps + compile assets -------
FROM base AS build

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-interaction

COPY package.json package-lock.json* ./
COPY packages/Webkul/Admin/package.json packages/Webkul/Admin/
COPY packages/Webkul/Shop/package.json packages/Webkul/Shop/

COPY . .

RUN composer dump-autoload --optimize --no-dev

# Build Admin assets
RUN cd packages/Webkul/Admin && npm install && npm run build

# Build Shop assets
RUN cd packages/Webkul/Shop && npm run build

# ------- Production stage -------
FROM base AS production

COPY --from=build /var/www/html /var/www/html

RUN mkdir -p storage/framework/{cache,sessions,views} \
    storage/logs \
    bootstrap/cache \
    && chown -R sail:sail storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER sail

EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
