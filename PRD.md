# PRD — Étnicos Tienda Accesorios E-commerce

Tienda e-commerce 100% funcional para **Étnicos Tienda Accesorios**, construida sobre Bagisto 2.4.x, lista para desplegar en VPS con Docker. Integración con Wompi (Colombia) como pasarela de pagos.

- Facebook: https://www.facebook.com/etnicostiendaaccesorios/
- Instagram: https://www.instagram.com/etnicostienda_accesorios/

## Tareas

### A. Docker Production Setup

- [ ] Crear `Dockerfile` optimizado para producción (PHP 8.3-FPM + Nginx + Node 20 para build de assets)
- [ ] Crear `docker-compose.prod.yml` con servicios: app, mysql 8.0, redis, elasticsearch 7.17, nginx
- [ ] Crear `docker/nginx/default.conf` configurado para Laravel (try_files, PHP-FPM upstream, gzip, cache de assets)
- [ ] Crear `docker/php/php.ini` optimizado (upload_max_filesize=64M, memory_limit=512M, opcache)
- [ ] Crear `docker/php/www.conf` para PHP-FPM (pool config)
- [ ] Crear `docker/entrypoint.sh` que ejecute: migrations, seeders condicionales, cache optimize, storage link, queue worker
- [ ] Crear `.env.production.example` con todas las variables necesarias incluyendo Wompi
- [ ] Crear `deploy.sh` — script de despliegue para VPS (git pull, build, restart containers)

### B. Paquete Wompi Payment Gateway

- [ ] Crear `packages/Webkul/Wompi/composer.json` con namespace y dependencias
- [ ] Crear `packages/Webkul/Wompi/src/Config/payment-methods.php` registrando la clase Wompi
- [ ] Crear `packages/Webkul/Wompi/src/Payment/Wompi.php` extendiendo `Webkul\Payment\Payment\Payment` con:
  - Soporte sandbox/producción
  - Generación de URL de pago via API Wompi
  - Verificación de integridad con integrity_key (SHA256)
  - Métodos: getRedirectUrl(), getPublicKey(), getApiUrl(), generateSignature()
- [ ] Crear `packages/Webkul/Wompi/src/Http/Controllers/WompiController.php` con:
  - redirect() — redirige al widget de Wompi
  - success() — callback de pago exitoso, crea orden e invoice
  - failure() — callback de pago fallido
  - webhook() — endpoint para eventos de Wompi (verificar events_key)
- [ ] Crear `packages/Webkul/Wompi/src/Routes/web.php` con rutas para redirect, success, failure, webhook
- [ ] Crear `packages/Webkul/Wompi/src/Providers/WompiServiceProvider.php` (config, routes, translations, views)
- [ ] Crear `packages/Webkul/Wompi/src/Providers/ModuleServiceProvider.php`
- [ ] Crear traducciones en `Resources/lang/en/app.php` y `Resources/lang/es/app.php`
- [ ] Crear `packages/Webkul/Wompi/src/Resources/views/checkout/wompi-redirect.blade.php` (form redirect)
- [ ] Crear `packages/Webkul/Wompi/src/Resources/manifest.php`
- [ ] Registrar `WompiServiceProvider` en `bootstrap/providers.php`
- [ ] Registrar `ModuleServiceProvider` en `config/concord.php`
- [ ] Agregar configuración de Wompi en `packages/Webkul/Admin/src/Config/system.php` bajo sales.payment_methods
- [ ] Agregar namespace Wompi al autoload de `composer.json` raíz
- [ ] Agregar variables WOMPI_* al `.env`

### C. Personalización Tienda Étnicos

- [ ] Copiar `logoetnicos.png` a `public/themes/shop/default/build/assets/` y configurar como logo principal
- [ ] Copiar `logoetnicoswithe.png` como logo para footer/dark backgrounds
- [ ] Crear seeder `EtnicosStoreSeeder.php` con datos de la tienda:
  - Nombre: Étnicos Tienda Accesorios
  - Moneda: COP (Peso Colombiano)
  - Locale por defecto: es (Español)
  - Timezone: America/Bogota
  - País: CO (Colombia)
  - Email de contacto
  - Redes sociales (Facebook, Instagram)

### D. Configuración para Producción

- [ ] Verificar que `docker-compose.prod.yml` incluya healthchecks para todos los servicios
- [ ] Configurar volúmenes persistentes para MySQL, Redis, Elasticsearch y storage de Laravel
- [ ] Configurar restart policies (unless-stopped) en todos los servicios
- [ ] Agregar soporte SSL/HTTPS en la configuración de Nginx (con Let's Encrypt/certbot)
