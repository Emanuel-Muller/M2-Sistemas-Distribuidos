#!/bin/sh
# Roda DENTRO de cliente/cliente2 (via e9-concorrencia.sh).
# Espera o instante combinado e envia N atualizações, uma mensagem UPDATE por
# vez (cada nsupdate = 1 mensagem). Cada mensagem SUBSTITUI o valor:
#   update delete <nome> TXT  +  update add <nome> 60 TXT "<rotulo>-<seq>"
# uso: e9-cliente.sh <rotulo> <arquivo_chave> <N> <inicio_epoch_s> <nome>
# saída CSV: cliente,seq,valor,envio_ms,resposta_ms,latencia_ms,status
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

rot=$1; chave=$2; n=$3; inicio=$4; nome=$5
while [ "$(date +%s)" -lt "$inicio" ]; do sleep 0.01; done
i=1
while [ "$i" -le "$n" ]; do
    v=$(printf '%s-%03d' "$rot" "$i")
    t0=$(agora_ms)
    printf 'server 172.31.0.11\nzone sd.lab\nupdate delete %s TXT\nupdate add %s 60 TXT "%s"\nsend\n' "$nome" "$nome" "$v" \
        | nsupdate -k "$chave" > /tmp/nsupdate.out 2>&1
    st=$?
    t1=$(agora_ms)
    [ "$st" -eq 0 ] && res=NOERROR || res=$(grep -o 'update failed: [A-Z()]*' /tmp/nsupdate.out | head -1 | cut -d' ' -f3)
    echo "$rot,$i,$v,$t0,$t1,$((t1 - t0)),${res:-ERRO}"
    i=$((i + 1))
done
