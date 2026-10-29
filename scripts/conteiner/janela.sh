#!/bin/sh
# Roda DENTRO do contêiner cliente (via scripts/medir-consistencia.sh).
# Linha do tempo do E4: a cada ~100 ms consulta o resolvedor (com recursão) e
# ns1, ns2 e ns3 (direto, +norecurse), sempre com @IP explícito, e imprime uma
# linha CSV com o instante em ms. Termina quando o resolvedor devolve o valor
# novo ou quando o prazo estoura. Não usa rndc flush nem altera nada.
# uso: janela.sh <nome> <valor_novo> <timeout_ms> [tipo=A]
# saída CSV: t_ms,res_status,res_valor,res_ttl,ns1_status,ns1_valor,
#            ns2_status,ns2_valor,ns3_status,ns3_valor,
#            t_res_ms,t_ns1_ms,t_ns2_ms,t_ns3_ms
#   t_ms: início da amostra (as quatro consultas são feitas em sequência)
#   t_<servidor>_ms: instante em que a resposta daquele servidor chegou
#   res_ttl: TTL do registro (resposta positiva) ou do SOA (resposta NXDOMAIN)

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

nome=$1; alvo=$2; lim=$3; tipo=${4:-A}

consulta() { # ip opcoes -> "status valor ttl"
    dig @"$1" "$nome" "$tipo" $2 +time=1 +tries=1 +noall +comments +answer +authority 2>&1 | awk -v t="$tipo" '
        /status:/ { st = $6; sub(",", "", st) }
        /no servers could be reached|timed out/ { if (st == "") st = "TIMEOUT" }
        $4 == t && v == "" { v = $5; ttl = $2 }
        $4 == "SOA" && sttl == "" { sttl = $2 }
        END { if (st == "") st = "TIMEOUT"; if (v == "") { v = "-"; ttl = (sttl == "" ? "-" : sttl) }
              print st, v, ttl }'
}

echo "t_ms,res_status,res_valor,res_ttl,ns1_status,ns1_valor,ns2_status,ns2_valor,ns3_status,ns3_valor,t_res_ms,t_ns1_ms,t_ns2_ms,t_ns3_ms"
ini=$(agora_ms)
while :; do
    t=$(agora_ms)
    set -- $(consulta 172.31.0.53 "");      rs=$1; rv=$2; rt=$3; tr0=$(agora_ms)
    set -- $(consulta 172.31.0.11 +norecurse); a1="$1,$2"; t1=$(agora_ms)
    set -- $(consulta 172.31.0.12 +norecurse); a2="$1,$2"; t2=$(agora_ms)
    set -- $(consulta 172.31.0.13 +norecurse); a3="$1,$2"; t3=$(agora_ms)
    echo "$t,$rs,$rv,$rt,$a1,$a2,$a3,$tr0,$t1,$t2,$t3"
    [ "$rv" = "$alvo" ] && break
    [ $((t - ini)) -gt "$lim" ] && break
    sleep 0.1
done
