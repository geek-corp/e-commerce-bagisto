#!/bin/sh
set -e

echo "=== Étnicos Tienda - Starting application ==="

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

# Storage link
php artisan storage:link 2>/dev/null || true

echo "=== Application ready ==="

exec "$@"
