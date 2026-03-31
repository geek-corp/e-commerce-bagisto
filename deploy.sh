#!/usr/bin/env bash
# deploy.sh — Despliegue en VPS con Docker
# Usage: ./deploy.sh [primera-vez|actualizar]

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.prod.yml"

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Deploy E-commerce Bagisto        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker no está instalado.${NC}"
    echo "Instala Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

MODE="${1:-actualizar}"

case "$MODE" in
    primera-vez|init|setup)
        echo -e "${CYAN}Modo: Primera instalación${NC}"
        echo ""

        # Check .env
        if [ ! -f .env ]; then
            if [ -f .env.production.example ]; then
                cp .env.production.example .env
                echo -e "${RED}IMPORTANTE: Edita .env con tus credenciales antes de continuar${NC}"
                echo "  nano .env"
                exit 1
            else
                echo -e "${RED}No existe .env ni .env.production.example${NC}"
                exit 1
            fi
        fi

        echo "1/5 — Construyendo imagen Docker..."
        docker compose -f $COMPOSE_FILE build --no-cache

        echo "2/5 — Levantando servicios..."
        docker compose -f $COMPOSE_FILE up -d

        echo "3/5 — Esperando a que MySQL esté listo..."
        sleep 15
        until docker compose -f $COMPOSE_FILE exec mysql mysqladmin ping -p"$(grep DB_PASSWORD .env | cut -d= -f2)" --silent 2>/dev/null; do
            sleep 5
            echo "  Esperando MySQL..."
        done

        echo "4/5 — Generando APP_KEY..."
        docker compose -f $COMPOSE_FILE exec app php artisan key:generate --force

        echo "5/5 — Ejecutando migraciones y seeders..."
        docker compose -f $COMPOSE_FILE exec app php artisan migrate --force --no-interaction
        docker compose -f $COMPOSE_FILE exec app php artisan db:seed --force --no-interaction
        docker compose -f $COMPOSE_FILE exec app php artisan storage:link

        # Optimize
        docker compose -f $COMPOSE_FILE exec app php artisan optimize

        echo ""
        echo -e "${GREEN}${BOLD}Instalación completa!${NC}"
        echo ""
        echo "Siguiente paso: ejecuta ./setup-store.sh para configurar nombre, logo y heroes."
        echo ""
        ;;

    actualizar|update)
        echo -e "${CYAN}Modo: Actualización${NC}"
        echo ""

        echo "1/4 — Descargando cambios..."
        git pull origin 2.4

        echo "2/4 — Reconstruyendo imagen..."
        docker compose -f $COMPOSE_FILE build

        echo "3/4 — Reiniciando servicios..."
        docker compose -f $COMPOSE_FILE up -d

        echo "4/4 — Migraciones y optimización..."
        sleep 10
        docker compose -f $COMPOSE_FILE exec app php artisan migrate --force --no-interaction
        docker compose -f $COMPOSE_FILE exec app php artisan optimize

        echo ""
        echo -e "${GREEN}${BOLD}Actualización completa!${NC}"
        ;;

    restart)
        echo "Reiniciando servicios..."
        docker compose -f $COMPOSE_FILE restart
        echo -e "${GREEN}Servicios reiniciados.${NC}"
        ;;

    logs)
        docker compose -f $COMPOSE_FILE logs -f --tail=50
        ;;

    status)
        docker compose -f $COMPOSE_FILE ps
        ;;

    down)
        echo "Deteniendo servicios..."
        docker compose -f $COMPOSE_FILE down
        echo -e "${GREEN}Servicios detenidos.${NC}"
        ;;

    *)
        echo "Uso: ./deploy.sh [comando]"
        echo ""
        echo "Comandos:"
        echo "  primera-vez   Primera instalación en VPS"
        echo "  actualizar    Actualizar código y reiniciar (default)"
        echo "  restart       Reiniciar servicios"
        echo "  logs          Ver logs en tiempo real"
        echo "  status        Ver estado de servicios"
        echo "  down          Detener todo"
        ;;
esac
