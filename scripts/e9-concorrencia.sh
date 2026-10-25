#!/bin/sh
# E9: atualizações concorrentes a partir de dois clientes.
# cliente (chave cliente1) e cliente2 (chave cliente2) começam no mesmo segundo
# e enviam N mensagens UPDATE cada. Modo:
#   mesmo     -> os dois substituem ordem.sd.lab TXT (conflito de escrita)
#   distintos -> cliente1 escreve c1.sd.lab, cliente2 escreve c2.sd.lab
# Coleta: respostas dos clientes, serial antes/depois, ordem de aplicação nos
# logs do ns1, journal, transferências e convergência dos secundários.
#
# uso: scripts/e9-concorrencia.sh [N=20] [mesmo|distintos]
. "$(dirname "$0")/lib.sh"

n=${1:-20}; modo=${2:-mesmo}
case "$modo" in
    mesmo)     nome1=ordem.sd.lab; nome2=ordem.sd.lab ;;
    distintos) nome1=c1.sd.lab;    nome2=c2.sd.lab ;;
    *) echo "modo deve ser 'mesmo' ou 'distintos'"; exit 1 ;;
esac
modo_dinamico || { echo "ERRO: ative a variante e9 (ver docker-compose.e9.yml)."; exit 1; }

dir="experimentos/E9/execucao-$(carimbo)-$modo"
mkdir -p "$dir"
inicio_log=$(agora_utc)
s0=$(serial_de 172.31.0.11)
echo "Saída: $dir | serial inicial: $s0"

alvo=$(( $(no cliente date +%s | tr -d '\r') + 3 ))    # início combinado (relógio dos contêineres)
no cliente  sh -s -- c1 /chaves/cliente1.key "$n" "$alvo" "$nome1" < scripts/conteiner/e9-cliente.sh > "$dir/cliente1.csv" 2>&1 &
p1=$!
no cliente2 sh -s -- c2 /chaves/cliente2.key "$n" "$alvo" "$nome2" < scripts/conteiner/e9-cliente.sh > "$dir/cliente2.csv" 2>&1 &
p2=$!
echo "Clientes disparados; início combinado em $alvo (epoch)."
wait "$p1" "$p2"
t_fim=$(date +%s)
s1=$(serial_de 172.31.0.11)

# envios dos dois clientes em ordem de envio (relógio comum)
{ echo "cliente,seq,valor,envio_ms,resposta_ms,latencia_ms,status"
  cat "$dir/cliente1.csv" "$dir/cliente2.csv" | tr -d '\r' | sort -t, -k4,4n; } > "$dir/envios.csv"
aceitos=$(awk -F, 'NR > 1 && $7 == "NOERROR"' "$dir/envios.csv" | wc -l | tr -d ' ')

# convergência dos secundários (até 60 s)
conv=NA; i=0
while [ "$i" -lt 600 ]; do
    if [ "$(serial_de 172.31.0.12)" = "$s1" ] && [ "$(serial_de 172.31.0.13)" = "$s1" ]; then conv=$(( $(date +%s) - t_fim )); break; fi
    sleep 0.1; i=$((i + 1))
done

docker compose logs --no-color --timestamps --since "$inicio_log" ns1 ns2 ns3 > "$dir/logs.txt" 2>&1
grep "updating zone" "$dir/logs.txt" | grep "adding an RR" > "$dir/ordem-aplicacao.txt"
grep -E "IXFR|AXFR" "$dir/logs.txt" > "$dir/transferencias.txt"
no ns1 named-journalprint /var/lib/bind/db.sd.lab.jnl > "$dir/journal.txt" 2>&1
for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
    linha="$ip serial=$(serial_de $ip)"
    for nm in $(echo "$nome1 $nome2" | tr ' ' '\n' | sort -u); do
        linha="$linha $nm=$(no cliente dig @$ip "$nm" TXT +short +norecurse | tr -d '\r')"
    done
    echo "$linha"
done > "$dir/estado-final.txt"

{
    echo "modo: $modo | mensagens por cliente: $n"
    echo "serial: $s0 -> $s1 (delta $((s1 - s0)))"
    echo "mensagens aceitas (NOERROR): $aceitos de $((2 * n))"
    echo "linhas 'adding an RR' no log do ns1: $(wc -l < "$dir/ordem-aplicacao.txt" | tr -d ' ')"
    echo "transferências registradas: IXFR=$(grep -c 'IXFR started' "$dir/transferencias.txt") AXFR-style=$(grep -c 'AXFR-style' "$dir/transferencias.txt")"
    echo "secundários convergiram ${conv}s após o fim dos envios"
    echo "estado final:"; cat "$dir/estado-final.txt"
} | tee "$dir/resumo.txt"
echo
scripts/estatisticas.sh "$dir/envios.csv" latencia_ms | tee -a "$dir/resumo.txt"
