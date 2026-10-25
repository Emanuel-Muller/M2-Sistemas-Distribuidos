#!/bin/sh
# Roda DENTRO do ns3 (via medir-recuperacao.sh).
# Marca o instante em que a interface da rede interna volta (172.30.0.13)
# e o instante em que o ns3 passa a servir o serial esperado.
# uso: vigiar-ns3.sh <serial_esperado> <timeout_ms>
# saída: "<ms_rede_voltou> <ms_sincronizado>" (NA se não ocorreu no prazo)
# Tempo em milissegundos pelo relógio do kernel (o mesmo para todos os
# contêineres da máquina). Usa date +%s%N; se o BusyBox não suportar %N,
# cai para /proc/uptime (resolução de 10 ms).
agora_ms() {
    t=$(date +%s%N 2>/dev/null)
    case "$t" in
        ""|*[!0-9]*) t="" ;;
    esac
    if [ "${#t}" -ge 16 ]; then
        echo $((t / 1000000))
    else
        awk '{ printf "%.0f\n", $1 * 1000 }' /proc/uptime
    fi
}

alvo=$1; lim=$2
ini=$(agora_ms); tr=""
while :; do
    if [ -z "$tr" ] && ip -4 addr show | grep -q '172\.30\.0\.13/'; then tr=$(agora_ms); fi
    if [ -n "$tr" ]; then
        s=$(dig @127.0.0.1 sd.lab SOA +short +norecurse +time=1 +tries=1 | awk '$4 ~ /^[0-9]+$/ {print $3; exit}')
        if [ "$s" = "$alvo" ]; then echo "$tr $(agora_ms)"; exit 0; fi
    fi
    if [ $(($(agora_ms) - ini)) -gt "$lim" ]; then echo "${tr:-NA} NA"; exit 1; fi
    sleep 0.1
done
