#!/bin/sh
# Roda DENTRO do ns1. Imprime o instante (ms) e recarrega a zona.
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

agora_ms
rndc reload sd.lab >/dev/null
