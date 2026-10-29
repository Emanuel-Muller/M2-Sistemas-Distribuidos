#!/bin/sh
# E7: mede o tempo de recuperação do ns3 depois de uma partição.
# Em cada repetição:
#   1. garante ns3 conectado e sincronizado;
#   2. desconecta ns3 da rede interna (partição) e confere o isolamento;
#   3. altera a zona no ns1 (cria a defasagem que o ns3 terá de recuperar);
#   4. espera <espera_s> segundos isolado;
#   5. reconecta ns3 com o mesmo IP; um vigia DENTRO do ns3 marca quando a
#      interface volta e quando o ns3 passa a servir o serial novo;
#   6. registra serial e valor de app.sd.lab em ns1, ns2 e ns3 (estado final).
# Logs de cada repetição ficam em experimentos/E7/<execucao>/.
# Código de saída: 0 = todas as repetições com estado final idêntico nos três;
#                  1 = pré-condição não atendida (laboratório não convergiu ou
#                      partição não efetiva); 2 = alguma repetição terminou sem
#                      estado idêntico ou sem recuperação no prazo.
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
final="$dir/estado-final.csv"
echo "repeticao,ns1_serial,ns1_app,ns2_serial,ns2_app,ns3_serial,ns3_app,identico" > "$final"
echo "Saída: $dir"
rc=0

conectado() { docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' ns3 | grep -q "$REDE"; }

r=1
while [ "$r" -le "$reps" ]; do
    conectado || docker network connect --ip 172.30.0.13 "$REDE" ns3
    if ! espera_convergencia 90 >/dev/null; then
        echo "ERRO: ns1, ns2 e ns3 não convergiram antes da repetição $r; medição interrompida."
        echo "      (com o primário marcado como inalcançável, o ns3 só volta após reinício: docker compose restart ns3)"
        exit 1
    fi

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
    [ "$dt" = NA ] && rc=2

    # estado final: serial e valor nos três autoritativos
    espera_convergencia 30 >/dev/null
    linha="$r"; ref=""; ident=sim
    for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
        s=$(serial_de "$ip")
        v=$(no cliente dig @"$ip" app.sd.lab A +short +norecurse +time=2 +tries=1 | tr -d '\r')
        linha="$linha,${s:-NA},${v:-NA}"
        [ -z "$ref" ] && ref="$s/$v"
        { [ -z "$s" ] || [ -z "$v" ] || [ "$s/$v" != "$ref" ] || [ "$s" != "$alvo" ]; } && ident=nao
    done
    echo "$linha,$ident" >> "$final"
    echo "repetição $r: estado final $(echo "$linha" | cut -d, -f2-) | idêntico nos três: $ident"
    [ "$ident" = sim ] || rc=2
    r=$((r + 1))
done

echo
scripts/estatisticas.sh "$csv" tempo_ms
echo "repetições com estado final idêntico nos três: $(awk -F, 'NR > 1 && $8 == "sim"' "$final" | wc -l | tr -d ' ') de $reps (ver estado-final.csv)"
exit "$rc"
