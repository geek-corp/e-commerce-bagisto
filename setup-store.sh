#!/usr/bin/env bash
# setup-store.sh — Configura la tienda después del despliegue
# Usage: ./setup-store.sh
#
# Requisitos:
#   - Docker Compose corriendo (docker compose up)
#   - Archivos en carpeta setup/:
#     setup/logo.png          — Logo principal
#     setup/hero1.png          — Hero banner 1 (ideal: 1920x700)
#     setup/hero2.png          — Hero banner 2 (opcional)
#     setup/hero3.png          — Hero banner 3 (opcional)

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Configuración de Tienda - Bagisto  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# --- Nombre de la tienda ---
read -p "Nombre de la tienda: " STORE_NAME
read -p "Descripción corta: " STORE_DESC
read -p "Email de contacto: " STORE_EMAIL
read -p "Facebook URL (o enter para omitir): " STORE_FB
read -p "Instagram URL (o enter para omitir): " STORE_IG
read -p "Moneda (COP/USD/EUR) [COP]: " STORE_CURRENCY
STORE_CURRENCY=${STORE_CURRENCY:-COP}

echo ""
echo -e "${CYAN}Configurando tienda: ${STORE_NAME}${NC}"

# --- Verificar que Docker está corriendo ---
if ! docker compose exec app echo "OK" > /dev/null 2>&1; then
    echo "ERROR: Docker no está corriendo. Ejecuta 'docker compose up' primero."
    exit 1
fi

# --- Copiar logo ---
if [ -f setup/logo.png ]; then
    echo "Copiando logo..."
    docker compose exec app bash -c "mkdir -p /var/www/html/storage/app/public/channel/1"
    docker compose cp setup/logo.png app:/var/www/html/storage/app/public/channel/1/logo.png
    docker compose exec app bash -c "chmod 644 /var/www/html/storage/app/public/channel/1/logo.png"
    docker compose exec app php artisan tinker --execute="
        \Illuminate\Support\Facades\DB::table('channels')->where('id', 1)->update(['logo' => 'channel/1/logo.png']);
    " > /dev/null 2>&1
    echo "  Logo configurado."
else
    echo "  AVISO: No se encontró setup/logo.png — omitiendo logo."
fi

# --- Copiar heroes y redimensionar ---
echo "Procesando hero banners..."
docker compose exec app bash -c "mkdir -p /var/www/html/storage/app/public/theme/1"

HERO_IMAGES='['
HERO_COUNT=0
for i in 1 2 3 4 5; do
    HERO_FILE="setup/hero${i}.png"
    if [ -f "$HERO_FILE" ]; then
        docker compose cp "$HERO_FILE" app:/tmp/hero${i}.png
        docker compose exec app bash -c "
            convert /tmp/hero${i}.png -resize 1920x700^ -gravity center -extent 1920x700 -quality 90 /var/www/html/storage/app/public/theme/1/hero-${i}.png
            chmod 644 /var/www/html/storage/app/public/theme/1/hero-${i}.png
            rm /tmp/hero${i}.png
        "
        if [ $HERO_COUNT -gt 0 ]; then HERO_IMAGES="${HERO_IMAGES},"; fi
        HERO_IMAGES="${HERO_IMAGES}{\"image\":\"storage/theme/1/hero-${i}.png\",\"title\":\"${STORE_NAME}\",\"link\":\"/\",\"button_text\":\"Ver Colección\"}"
        HERO_COUNT=$((HERO_COUNT + 1))
        echo "  Hero ${i} procesado (1920x700)."
    fi
done
HERO_IMAGES="${HERO_IMAGES}]"

if [ $HERO_COUNT -gt 0 ]; then
    docker compose exec app php artisan tinker --execute="
        \Illuminate\Support\Facades\DB::table('theme_customization_translations')
            ->where('theme_customization_id', 1)
            ->where('locale', 'es')
            ->update(['options' => json_encode(['images' => json_decode('${HERO_IMAGES}', true)])]);
    " > /dev/null 2>&1
    echo "  ${HERO_COUNT} hero(es) configurados en el carrusel."
fi

# --- Configurar canal ---
echo "Configurando datos de la tienda..."

# Escapar comillas para PHP
STORE_NAME_ESC=$(echo "$STORE_NAME" | sed "s/'/\\\\'/g")
STORE_DESC_ESC=$(echo "$STORE_DESC" | sed "s/'/\\\\'/g")

docker compose exec app php artisan tinker --execute="
    use Illuminate\Support\Facades\DB;

    \$channel = \Webkul\Core\Models\Channel::first();
    \$channel->update(['timezone' => 'America/Bogota']);

    \$trans = \$channel->translations()->where('locale', 'es')->first();
    if (\$trans) {
        \$trans->update([
            'name' => '${STORE_NAME_ESC}',
            'description' => '${STORE_DESC_ESC}',
            'home_seo' => json_encode([
                'meta_title' => '${STORE_NAME_ESC}',
                'meta_description' => '${STORE_DESC_ESC}',
                'meta_keywords' => strtolower('${STORE_NAME_ESC}'),
            ]),
        ]);
    }
" > /dev/null 2>&1

# --- Actualizar .env ---
echo "Actualizando .env..."
sed -i.bak "s/^APP_NAME=.*/APP_NAME=\"${STORE_NAME}\"/" .env
sed -i.bak "s/^MAIL_FROM_ADDRESS=.*/MAIL_FROM_ADDRESS=${STORE_EMAIL}/" .env
sed -i.bak "s/^MAIL_FROM_NAME=.*/MAIL_FROM_NAME=\"${STORE_NAME}\"/" .env
sed -i.bak "s/^APP_CURRENCY=.*/APP_CURRENCY=${STORE_CURRENCY}/" .env
rm -f .env.bak

# --- Limpiar caches ---
echo "Limpiando caches..."
docker compose exec app php artisan optimize:clear > /dev/null 2>&1
docker compose exec app php artisan responsecache:clear > /dev/null 2>&1

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║        Tienda configurada!           ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  Tienda: ${BOLD}${STORE_NAME}${NC}"
echo -e "  URL:    ${CYAN}http://localhost${NC}"
echo -e "  Admin:  ${CYAN}http://localhost/admin${NC}"
echo ""
echo "  Credenciales admin por defecto:"
echo "    Email:    admin@example.com"
echo "    Password: admin123"
echo ""
