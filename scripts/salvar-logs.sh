#!/bin/sh
# Salva os logs de todos os contêineres (com data/hora) numa pasta de evidências.
# uso: scripts/salvar-logs.sh <pasta> [rotulo]
#   ex.: scripts/salvar-logs.sh experimentos/E1 subida
. "$(dirname "$0")/lib.sh"

pasta=${1:?uso: salvar-logs.sh <pasta> [rotulo]}; rot=${2:-logs}
mkdir -p "$pasta"
arq="$pasta/$(carimbo)-$rot.txt"
docker compose logs --no-color --timestamps > "$arq" 2>&1
echo "$arq"
