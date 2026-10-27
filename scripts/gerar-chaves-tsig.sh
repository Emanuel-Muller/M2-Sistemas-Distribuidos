#!/bin/sh
# E9: gera as chaves TSIG em secrets/ (pasta fora do Git).
#   cliente1.key e cliente2.key: chaves válidas, uma por cliente
#   invalida.key: mesmo nome "cliente1", segredo diferente (teste negativo)
# Cada integrante gera as próprias chaves na sua máquina.
# uso: scripts/gerar-chaves-tsig.sh
. "$(dirname "$0")/lib.sh"

if [ -f secrets/cliente1.key ] && [ "${1:-}" != "--substituir" ]; then
    echo "Chaves já existem em secrets/. Para gerar novas: scripts/gerar-chaves-tsig.sh --substituir"
    exit 0
fi
docker image inspect sd-bind >/dev/null 2>&1 || { echo "ERRO: imagem sd-bind não existe. Rode: docker compose build"; exit 1; }
mkdir -p secrets
for c in cliente1 cliente2; do
    docker run --rm sd-bind tsig-keygen -a hmac-sha256 "$c" > "secrets/$c.key"
done
docker run --rm sd-bind tsig-keygen -a hmac-sha256 cliente1 > secrets/invalida.key
chmod 0644 secrets/*.key
echo "Chaves geradas em secrets/ (não versionar):"
ls -l secrets/
