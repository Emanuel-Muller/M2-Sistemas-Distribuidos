#!/bin/sh
# E9: mede, em repetições, (a) o tempo até o cliente receber a confirmação do
# UPDATE e (b) o tempo até ns2 e ns3 refletirem o valor novo.
# uso: scripts/e9-medir.sh [repeticoes=5] [timeout_s=60]
. "$(dirname "$0")/lib.sh"

reps=${1:-5}; lim_ms=$(( ${2:-60} * 1000 ))
modo_dinamico || { echo "ERRO: ative a variante e9 (ver docker-compose.e9.yml)."; exit 1; }
mkdir -p experimentos/E9
csv="experimentos/E9/medicoes-$(carimbo).csv"
echo "repeticao,valor,status,confirmacao_ms,ns2_ms,ns3_ms" > "$csv"
sleep 6   # evita herdar o notify-delay (5 s) de atualizações anteriores
r=1
while [ "$r" -le "$reps" ]; do
    v="medida-$r-$(date +%s)"
    set -- $(no cliente sh -s -- "$v" "$lim_ms" < scripts/conteiner/e9-medir.sh | tr -d '\r')
    t0=$1; t1=$2; f2=$3; f3=$4; st=$5
    d2=NA; d3=NA
    [ "$f2" != NA ] && d2=$((f2 - t0)); [ "$f3" != NA ] && d3=$((f3 - t0))
    echo "$r,$v,$st,$((t1 - t0)),$d2,$d3" >> "$csv"
    echo "repetição $r: confirmação $((t1 - t0)) ms | ns2 $d2 ms | ns3 $d3 ms"
    r=$((r + 1)); sleep 6
done
echo
for c in confirmacao_ms ns2_ms ns3_ms; do scripts/estatisticas.sh "$csv" "$c"; done
