#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color

# Control de concurrencia
MAX_CONCURRENT=10
current_jobs=0

# Función para normalizar URLs evitando dobles barras //
normalize_url() {
    local url=$1
    echo "$url" | sed 's|//|/|g' | sed 's|:/|://|g'
}

# Función para explorar directorios y subdirectorios
explore_directory() {
    local base_url=$(normalize_url "$1")
    local urls=($(curl -s "$base_url" | grep -oP 'href="\K[^"]+'))

    for url in "${urls[@]}"; do
        # Normalizar la ruta para evitar barras adicionales
        full_url=$(normalize_url "${base_url%/}/$url")
        if [[ $url == */ ]]; then
            ((current_jobs++))
            if ((current_jobs >= MAX_CONCURRENT)); then
                wait -n
                ((current_jobs--))
            fi
            explore_directory "$full_url" &
        else
            check_cache_status "$full_url"
        fi
    done
    wait
}

# Función para verificar el estado del caché de una URL
check_cache_status() {
    local URL=$(normalize_url "$1")

    # Hacer la solicitud con curl y obtener los encabezados
    response=$(curl -s -I "$URL")

    # Verificar si curl tuvo éxito
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al hacer la solicitud con curl para $URL.${NC}"
        return
    fi

    # Mostrar los encabezados completos (opcional, para depuración)
    # echo -e "${YELLOW}Encabezados para $URL:${NC}"
    # echo "$response"

    # Analizar los encabezados para determinar el estado del caché
    if echo "$response" | grep -q "cf-cache-status: HIT"; then
        echo -e "${GREEN}La URL $URL está cacheada por Cloudflare.${NC}"
    elif echo "$response" | grep -q "cf-cache-status: MISS"; then
        echo -e "${RED}La URL $URL no está cacheada por Cloudflare (MISS).${NC}"
    elif echo "$response" | grep -q "cf-cache-status: EXPIRED"; then
        echo -e "${YELLOW}La caché de la URL $URL ha expirado.${NC}"
    elif echo "$response" | grep -q "cf-cache-status: DYNAMIC"; then
        echo -e "${YELLOW}La URL $URL es dinámica.${NC}"
    elif echo "$response" | grep -q "cf-cache-status: REVALIDATED"; then
        echo -e "${YELLOW}La URL $URL tiene revalidación de caché.${NC}"
    else
        echo -e "${RED}No se pudo determinar el estado del caché para la URL $URL.${NC}"
    fi
}

# Verificar si se pasó una URL como argumento
if [ -z "$1" ]; then
    echo -e "${RED}Uso: $0 <URL>${NC}"
    exit 1
fi

BASE_URL=$(normalize_url "$1")

# Comenzar la exploración del directorio
explore_directory "$BASE_URL"
