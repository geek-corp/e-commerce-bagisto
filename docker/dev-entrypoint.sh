#!/bin/bash
set -e

echo "=== Étnicos Tienda - Dev Setup ==="

# Install system dependencies
apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    curl git unzip libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libwebp-dev libzip-dev libicu-dev libonig-dev libxml2-dev \
    default-mysql-client > /dev/null 2>&1

# Install PHP extensions (including calendar)
docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp > /dev/null 2>&1
docker-php-ext-install -j$(nproc) pdo_mysql gd zip intl bcmath opcache pcntl mbstring xml calendar > /dev/null 2>&1
pecl install redis > /dev/null 2>&1 && docker-php-ext-enable redis > /dev/null 2>&1

echo "PHP extensions installed."

# Install Composer
if [ ! -f /usr/bin/composer ]; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer > /dev/null 2>&1
fi

# Install Node.js
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y nodejs > /dev/null 2>&1
fi

echo "Composer & Node installed."

# Install PHP dependencies
cd /var/www/html
echo "Running composer install (this takes a few minutes)..."
composer install --no-interaction --ignore-platform-req=ext-calendar 2>&1 | tail -10

if [ ! -f vendor/autoload.php ]; then
    echo "ERROR: composer install failed. Retrying..."
    composer install --no-interaction --ignore-platform-reqs 2>&1 | tail -10
fi

if [ ! -f vendor/autoload.php ]; then
    echo "FATAL: vendor/autoload.php not found. Cannot continue."
    exit 1
fi

echo "Composer dependencies installed."

# Generate app key if missing
if [ -z "$(grep '^APP_KEY=base64' .env)" ]; then
    php artisan key:generate --force
fi

# Run Bagisto install (migrations + seeders)
echo "Running Bagisto installation..."
php artisan migrate --force --no-interaction 2>&1 | tail -5

# Check if already seeded
if ! php artisan tinker --execute="echo \Webkul\User\Models\Admin::count();" 2>/dev/null | grep -q "[1-9]"; then
    php artisan db:seed --force --no-interaction 2>&1 | tail -5
    echo "Database seeded."
else
    echo "Database already seeded, skipping."
fi

# Storage link
php artisan storage:link 2>/dev/null || true

# Build frontend assets
echo "Building Admin assets..."
cd /var/www/html/packages/Webkul/Admin && npm install --silent 2>&1 | tail -3 && npm run build 2>&1 | tail -3

echo "Building Shop assets..."
cd /var/www/html/packages/Webkul/Shop && npm install --silent 2>&1 | tail -3 && npm run build 2>&1 | tail -3

cd /var/www/html

echo ""
echo "========================================"
echo "  Étnicos Tienda - Ready!"
echo "  Shop:  http://localhost:8000"
echo "  Admin: http://localhost:8000/admin"
echo "  Mail:  http://localhost:8025"
echo "========================================"
echo ""

# Start the Laravel dev server
php artisan serve --host=0.0.0.0 --port=8000
