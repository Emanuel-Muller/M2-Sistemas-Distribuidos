#!/bin/sh
# Roda DENTRO do cliente (via e9-medir.sh). Uma atualização dinâmica e a
# sondagem de ns2/ns3 até refletirem o valor novo, tudo no mesmo relógio.
# uso: e9-medir.sh <valor> <timeout_ms>
# saída: "<envio_ms> <resposta_ms> <ns2_ms> <ns3_ms> <status>"
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

v=$1; lim=$2; nome=medida.sd.lab
t0=$(agora_ms)
printf 'server 172.31.0.11\nzone sd.lab\nupdate delete %s TXT\nupdate add %s 60 TXT "%s"\nsend\n' "$nome" "$nome" "$v" \
    | nsupdate -k /chaves/cliente1.key > /tmp/nsupdate.out 2>&1
st=$?; t1=$(agora_ms)
f2=""; f3=""; alvo="\"$v\""
while :; do
    if [ -z "$f2" ] && [ "$(dig @172.31.0.12 $nome TXT +short +norecurse +time=1 +tries=1)" = "$alvo" ]; then f2=$(agora_ms); fi
    if [ -z "$f3" ] && [ "$(dig @172.31.0.13 $nome TXT +short +norecurse +time=1 +tries=1)" = "$alvo" ]; then f3=$(agora_ms); fi
    [ -n "$f2" ] && [ -n "$f3" ] && break
    [ $(($(agora_ms) - t0)) -gt "$lim" ] && break
    sleep 0.1
done
echo "$t0 $t1 ${f2:-NA} ${f3:-NA} $st"
