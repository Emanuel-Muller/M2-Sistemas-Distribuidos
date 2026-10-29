#!/bin/sh
# Restaura o laboratório ao estado-base:
#   1. salva os logs atuais em logs/ (os logs somem com "down");
#   2. remove os contêineres (os secundários perdem a cópia da zona);
#   3. recria runtime/ns1 a partir da zona-base (serial inicial, sem journal);
#   4. sobe tudo de novo e espera os três autoritativos convergirem.
#
# uso: scripts/reset.sh                 restaura e sobe
#      scripts/reset.sh --so-preparar   só recria runtime/ns1 (não mexe nos contêineres;
#                                        recusa se o ns1 estiver em execução)
#
# A variante usada é a de COMPOSE_FILE (vazia = base dos E1-E8).
. "$(dirname "$0")/lib.sh"

SO_PREPARAR=0
[ "${1:-}" = "--so-preparar" ] && SO_PREPARAR=1

# Com o ns1 no ar, recriar runtime/ns1 trocaria a zona (e o journal) debaixo
# do named em execução. Nesse caso, use o reset completo.
if [ "$SO_PREPARAR" -eq 1 ] && [ -n "$(docker compose ps -q --status running ns1 2>/dev/null)" ]; then
    echo "ERRO: o ns1 está em execução. Use scripts/reset.sh (sem --so-preparar) ou pare o ns1 antes."
    exit 1
fi

if [ "$SO_PREPARAR" -eq 0 ]; then
    echo "Variante: $(variante)"
    case "${COMPOSE_FILE:-}" in
        *e9*)
            if [ ! -f secrets/cliente1.key ] || [ ! -f secrets/cliente2.key ]; then
                echo "ERRO: variante e9 sem chaves. Rode antes: scripts/gerar-chaves-tsig.sh"
                exit 1
            fi ;;
    esac
    if [ -n "$(docker compose ps -aq 2>/dev/null)" ]; then
        mkdir -p logs
        docker compose logs --no-color --timestamps > "logs/$(carimbo)-antes-do-reset.txt" 2>&1
        echo "Logs anteriores salvos em logs/."
    fi
    docker compose down --remove-orphans
fi

# Cópia de trabalho da zona do ns1 (fora do Git). Permissão aberta para que o
# usuário "named" do contêiner consiga gravar o journal (E9).
rm -rf runtime/ns1
mkdir -p runtime/ns1
cp "$ZONA_BASE" "$ZONA_TRABALHO"
chmod 0777 runtime/ns1
chmod 0644 "$ZONA_TRABALHO"
echo "Zona de trabalho recriada a partir de $ZONA_BASE (serial $SERIAL_BASE)."

[ "$SO_PREPARAR" -eq 1 ] && exit 0

docker compose up -d
espera_convergencia 120
