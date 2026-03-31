#!/bin/sh
set -e

echo "=== Étnicos Tienda - Starting application ==="

# Populate public volume if empty (first run)
if [ ! -f /var/www/html/public/index.php ]; then
    echo "Populating public volume from image..."
    cp -a /var/www/html/public-build/* /var/www/html/public/ 2>/dev/null || true
    cp -a /var/www/html/public-build/.* /var/www/html/public/ 2>/dev/null || true
fi

# Create storage link (public/storage -> storage/app/public)
rm -f /var/www/html/public/storage
ln -sf /var/www/html/storage/app/public /var/www/html/public/storage
echo "Storage link created."

# Wait for MySQL
echo "Waiting for MySQL..."
while ! php artisan db:monitor --databases=mysql 2>/dev/null; do
    sleep 2
done
echo "MySQL is ready."

# Run migrations
echo "Running migrations..."
php artisan migrate --force --no-interaction

# Cache optimization
echo "Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

echo "=== Application ready ==="

exec "$@"
