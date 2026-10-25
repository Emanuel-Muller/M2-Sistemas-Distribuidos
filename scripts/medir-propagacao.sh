#!/bin/sh
# E3: mede o tempo de propagação primário -> secundários.
# Em cada repetição: grava um valor novo de app.sd.lab (serial +1) na zona do
# ns1, marca o instante t0 DENTRO do ns1 e faz "rndc reload"; o contêiner
# cliente consulta ns2 e ns3 a cada ~100 ms e marca quando cada um passa a
# responder o valor novo. Todos os instantes vêm do mesmo relógio (o kernel
# compartilhado pelos contêineres), então as diferenças são comparáveis.
#
# uso: scripts/medir-propagacao.sh <rotulo> [repeticoes=5] [timeout_s=90]
#      rótulos sugeridos: com-notify, sem-notify
# saída: experimentos/E3/<rotulo>-<carimbo>.csv + estatísticas na tela
. "$(dirname "$0")/lib.sh"

rot=${1:?uso: medir-propagacao.sh <rotulo> [repeticoes] [timeout_s]}
reps=${2:-5}; lim_ms=$(( ${3:-90} * 1000 ))
mkdir -p experimentos/E3
csv="experimentos/E3/$rot-$(carimbo).csv"
echo "repeticao,serial,valor,t0_ms,ns2_ms,ns3_ms,atraso_ns2_ms,atraso_ns3_ms" > "$csv"
echo "Variante: $(variante) | saída: $csv"

espera_convergencia 60 >/dev/null || echo "AVISO: autoritativos não estavam convergentes no início."
sleep 6   # evita herdar o notify-delay (5 s) de NOTIFYs anteriores (ex.: logo após o reset)

r=1
while [ "$r" -le "$reps" ]; do
    valor="10.3.$r.$(( $(date +%s) % 250 + 1 ))"
    serial=$(scripts/zona.sh set app "$valor" --sem-reload | tail -1)

    tmp=$(mktemp)
    no cliente sh -s -- "$valor" "$lim_ms" < scripts/conteiner/sondar.sh > "$tmp" &
    pid=$!
    sleep 1                                   # sondagem já rodando antes do reload
    t0=$(no ns1 sh -s < scripts/conteiner/recarregar.sh | tr -d '\r')
    wait "$pid"
    set -- $(tr -d '\r' < "$tmp"); rm -f "$tmp"
    f2=${1:-NA}; f3=${2:-NA}
    d2=NA; d3=NA
    [ "$f2" != NA ] && d2=$((f2 - t0))
    [ "$f3" != NA ] && d3=$((f3 - t0))

    servido=$(serial_de 172.31.0.11)
    [ "$servido" = "$serial" ] || echo "AVISO: ns1 serve $servido, esperado $serial (repetição $r)"
    echo "$r,$serial,$valor,$t0,$f2,$f3,$d2,$d3" >> "$csv"
    echo "repetição $r: serial $serial  ns2=${d2} ms  ns3=${d3} ms"
    r=$((r + 1))
    sleep 6                                   # > notify-delay (5 s) do BIND
done

echo
scripts/estatisticas.sh "$csv" atraso_ns2_ms
scripts/estatisticas.sh "$csv" atraso_ns3_ms
