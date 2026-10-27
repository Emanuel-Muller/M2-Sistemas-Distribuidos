#!/bin/sh
# Roda DENTRO do contêiner cliente (via scripts/observar.sh).
# A cada intervalo, consulta ns1, ns2, ns3 (direto, sem recursão) e o resolvedor.
# uso: observar.sh <nome> <tipo> <intervalo_s> <duracao_s>
# saída CSV:
#   hora, para ns1/ns2/ns3: status,valor,serial ; resolvedor: status,valor,ttl
nome=$1; tipo=$2; intervalo=$3; duracao=$4

consulta() { # ip opcoes -> "status,valor,ttl"
    dig @"$1" "$nome" "$tipo" $2 +time=1 +tries=1 +noall +comments +answer +authority 2>&1 | awk -v t="$tipo" '
        /status:/ { st = $6; sub(",", "", st) }
        /no servers could be reached|timed out/ { if (st == "") st = "TIMEOUT" }
        $4 == t && v == "" { v = $5; ttl = $2 }
        $4 == "SOA" { sttl = $2 }
        END { if (st == "") st = "TIMEOUT"; if (v == "") { v = "-"; ttl = (sttl == "" ? "-" : sttl) }
              printf "%s,%s,%s", st, v, ttl }'
}
serial() { dig @"$1" sd.lab SOA +short +norecurse +time=1 +tries=1 2>/dev/null | awk '$4 ~ /^[0-9]+$/ {print $3; exit}'; }

echo "hora,ns1_status,ns1_valor,ns1_serial,ns2_status,ns2_valor,ns2_serial,ns3_status,ns3_valor,ns3_serial,res_status,res_valor,res_ttl"
fim=$(( $(date +%s) + duracao ))
while [ "$(date +%s)" -le "$fim" ]; do
    linha=$(date +%H:%M:%S)
    for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
        r=$(consulta "$ip" +norecurse)
        linha="$linha,${r%,*},$(serial "$ip")"
    done
    linha="$linha,$(consulta 172.31.0.53 '')"
    echo "$linha"
    sleep "$intervalo"
done
