#!/bin/sh
# Roda DENTRO do contêiner cliente (via medir-propagacao.sh).
# Consulta ns2 e ns3 a cada ~100 ms até ambos responderem o valor esperado.
# uso: sondar.sh <valor_esperado> <timeout_ms> [nome] [tipo]
# saída: "<ms_ns2> <ms_ns3>" (NA se não chegou no prazo)
# Tempo em milissegundos pelo relógio do kernel (o mesmo para todos os
# contêineres da máquina). Usa date +%s%N; se o BusyBox não suportar %N,
# cai para /proc/uptime (resolução de 10 ms).
agora_ms() {
    t=$(date +%s%N 2>/dev/null)
    case "$t" in
        ""|*[!0-9]*) awk '{ printf "%.0f\n", $1 * 1000 }' /proc/uptime ;;
        *) echo $((t / 1000000)) ;;
    esac
}

alvo=$1; lim=$2; nome=${3:-app.sd.lab}; tipo=${4:-A}
ini=$(agora_ms); f2=""; f3=""
while :; do
    if [ -z "$f2" ] && [ "$(dig @172.31.0.12 "$nome" "$tipo" +short +norecurse +time=1 +tries=1)" = "$alvo" ]; then f2=$(agora_ms); fi
    if [ -z "$f3" ] && [ "$(dig @172.31.0.13 "$nome" "$tipo" +short +norecurse +time=1 +tries=1)" = "$alvo" ]; then f3=$(agora_ms); fi
    [ -n "$f2" ] && [ -n "$f3" ] && break
    [ $(($(agora_ms) - ini)) -gt "$lim" ] && break
    sleep 0.1
done
echo "${f2:-NA} ${f3:-NA}"
