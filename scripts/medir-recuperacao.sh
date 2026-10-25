#!/bin/sh
# E7: mede o tempo de recuperação do ns3 depois de uma partição.
# Em cada repetição:
#   1. garante ns3 conectado e sincronizado;
#   2. desconecta ns3 da rede interna (partição) e confere o isolamento;
#   3. altera a zona no ns1 (cria a defasagem que o ns3 terá de recuperar);
#   4. espera <espera_s> segundos isolado;
#   5. reconecta ns3 com o mesmo IP; um vigia DENTRO do ns3 marca quando a
#      interface volta e quando o ns3 passa a servir o serial novo.
# Logs de cada repetição ficam em experimentos/E7/<execucao>/.
#
# uso: scripts/medir-recuperacao.sh [repeticoes=5] [espera_s=20] [timeout_s=120]
#   espera_s < 300 mede a recuperação ANTES do expire; espera_s > 300, DEPOIS.
. "$(dirname "$0")/lib.sh"

reps=${1:-5}; espera=${2:-20}; lim_ms=$(( ${3:-120} * 1000 ))
REDE=sdlab_interna
dir="experimentos/E7/execucao-$(carimbo)"
mkdir -p "$dir"
csv="$dir/recuperacao.csv"
echo "repeticao,espera_s,serial_alvo,rede_ms,sincronizado_ms,tempo_ms,transferencia" > "$csv"
echo "Saída: $dir"

conectado() { docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' ns3 | grep -q "$REDE"; }

r=1
while [ "$r" -le "$reps" ]; do
    conectado || docker network connect --ip 172.30.0.13 "$REDE" ns3
    espera_convergencia 90 >/dev/null || echo "AVISO: sem convergência antes da repetição $r"

    inicio=$(agora_utc)
    docker network disconnect "$REDE" ns3
    if no ns3 dig @172.30.0.11 sd.lab SOA +short +time=1 +tries=1 2>/dev/null | grep -q 'ns1\.sd\.lab'; then
        echo "ERRO: ns3 ainda alcança o primário depois da desconexão. Partição não efetiva."
        exit 1
    fi

    alvo=$(scripts/zona.sh set app "10.7.$r.$(( $(date +%s) % 250 + 1 ))" | tail -1)
    echo "repetição $r: ns3 isolado, ns1 em $alvo; aguardando ${espera}s..."
    sleep "$espera"

    tmp=$(mktemp)
    no ns3 sh -s -- "$alvo" "$lim_ms" < scripts/conteiner/vigiar-ns3.sh > "$tmp" &
    pid=$!
    sleep 1
    docker network connect --ip 172.30.0.13 "$REDE" ns3
    wait "$pid"
    set -- $(tr -d '\r' < "$tmp"); rm -f "$tmp"
    tr_ms=${1:-NA}; ts_ms=${2:-NA}; dt=NA
    [ "$tr_ms" != NA ] && [ "$ts_ms" != NA ] && dt=$((ts_ms - tr_ms))

    sleep 1
    docker compose logs --no-color --timestamps --since "$inicio" ns1 ns3 > "$dir/repeticao-$r-logs.txt" 2>&1
    tipo=$(grep '172.30.0.13' "$dir/repeticao-$r-logs.txt" | grep -oE 'AXFR-style IXFR started|IXFR started|AXFR started' | tail -1)
    echo "$r,$espera,$alvo,$tr_ms,$ts_ms,$dt,${tipo:-?}" >> "$csv"
    echo "repetição $r: recuperação em ${dt} ms (${tipo:-tipo de transferência não identificado})"
    r=$((r + 1))
done

echo
scripts/estatisticas.sh "$csv" tempo_ms
