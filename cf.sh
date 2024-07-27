#!/bin/bash

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para verificar el estado de caché de una URL y si es dinámica
check_cache_status() {
    local url=$1
    local headers=$(curl -sI $url)
    local cache_status=$(echo "$headers" | grep 'cf-cache-status')
    local cf_ray=$(echo "$headers" | grep 'cf-ray')

    if [[ $cache_status == *"HIT"* ]]; then
        echo -e "${GREEN}Cache HIT: $url - ${cf_ray}${NC}"
    elif [[ $cache_status == *"DYNAMIC"* || $cache_status == *"BYPASS"* ]]; then
        echo -e "${YELLOW}Dynamic Content: $url - ${cf_ray}${NC}"
    else
        echo -e "${RED}Cache MISS: $url - ${cf_ray}${NC}"
    fi
}

export -f check_cache_status
export RED GREEN YELLOW NC

# Función para explorar directorios y subdirectorios
explore_directory() {
    local base_url=$1
    local urls=($(curl -s $base_url | grep -oP 'href="\K[^"]+'))

    for url in "${urls[@]}"; do
        # Normalizar la ruta para evitar barras adicionales
        if [[ $url == */ ]]; then
            explore_directory "${base_url%/}/$url" &
        else
            full_url="${base_url%/}/$url"
            echo $full_url
        fi
    done
    wait
}

# URL base
base_url=https://debian.com.ar/debian/project/

#if [[ -z $base_url ]]; then
#    echo "Uso: $0 <URL>"
#    exit 1
#fi

# Comenzar la exploración desde la URL base y procesar en paralelo
explore_directory $base_url | xargs -n 4 -P 10 bash -c 'check_cache_status "$@"' _
