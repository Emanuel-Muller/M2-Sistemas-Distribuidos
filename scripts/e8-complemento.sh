#!/bin/sh
# E8: coordenação e ordem pelo serial (execução com script e evidências completas).
#   1. reset da variante base e registro do coordenador (papéis, SOA, flag aa);
#   2. E8.1: serial crescente (app = 10.0.0.2) e propagação;
#   3. escrita por nsupdate no secundário e no primário (zona estática);
#   4. E8.2: serial menor no primário (2026101301, app = 10.0.0.3) e
#      observação de ns1, ns2 e ns3 a cada INT s durante DUR s;
#   5. restauração com serial maior (2026101403, app = 10.0.0.1).
# Saída: experimentos/E8/complemento/ (uma execução anterior é preservada em
#        experimentos/E8/complemento-anterior-<carimbo>/)
#
# uso: scripts/e8-complemento.sh [DUR=90] [INT=10]
. "$(dirname "$0")/lib.sh"

dur=${1:-90}; int=${2:-10}
SERIAL_MENOR=2026101301; SERIAL_RESTAURA=2026101403
[ -z "${COMPOSE_FILE:-}" ] || { echo "ERRO: use a variante base (rode 'unset COMPOSE_FILE')."; exit 1; }

dir=experimentos/E8/complemento
preparar_pasta "$dir" || { echo "ERRO: não foi possível preparar $dir"; exit 1; }
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$dir/execucao.txt"; }

estado() {
    for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
        echo "$ip serial=$(serial_de $ip) app=$(no cliente dig @$ip app.sd.lab A +short +norecurse | tr -d '\r')"
    done
}
consulta() {
    ip=$1; nome=$2; tipo=$3
    no cliente dig @"$ip" "$nome" "$tipo" +norecurse | tr -d '\r' \
        | grep -E "^;; ->>HEADER|^;; flags|IN[[:space:]]+$tipo"
}
nsupdate_teste() {
    ip=$1; v=$2
    saida=$(printf 'server %s\nzone sd.lab\nupdate delete app.sd.lab A\nupdate add app.sd.lab 60 A %s\nsend\n' "$ip" "$v" \
        | no cliente nsupdate 2>&1)
    st=$?
    echo "$saida" | tr -d '\r'
    echo "código de saída do nsupdate: $st (0 = aceito)"
}

{
    echo "Experimento E8 (complemento) — contexto"
    echo "data/hora local: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "data/hora UTC:   $(date -u '+%Y-%m-%d %H:%M:%S')"
    echo "máquina: $(uname -sm)"
    echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo desconhecido)"
    echo "variante: $(variante)"
    echo "observação: $dur s, intervalo $int s"
} > "$dir/contexto.txt"
cat "$dir/contexto.txt"

log "Reset da variante base"
scripts/reset.sh > "$dir/reset.txt" 2>&1 || { log "ERRO no reset (ver reset.txt)"; exit 1; }
inicio_log=$(agora_utc)

log "Coordenador: papéis configurados e SOA nos três autoritativos"
{
    for n in ns1 ns2 ns3; do
        echo "== $n: named.conf (zona sd.lab)"
        no "$n" grep -E "type (primary|secondary)|primaries" /etc/bind/named.conf | tr -d '\r'
    done
    for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
        echo "== dig @$ip sd.lab SOA +norecurse"
        consulta "$ip" sd.lab SOA
    done
} > "$dir/coordenacao.txt"
estado > "$dir/estado-inicial.txt"
cat "$dir/estado-inicial.txt"

log "E8.1: serial crescente (app = 10.0.0.2)"
scripts/zona.sh set app 10.0.0.2 > "$dir/e8-1-zona.txt" 2>&1
espera_convergencia 30 >> "$dir/e8-1-zona.txt"
estado > "$dir/e8-1-estado.txt"
cat "$dir/e8-1-estado.txt"

log "Escrita por nsupdate (sem chave) no secundário e no primário"
{
    echo "== nsupdate ao ns2 (172.31.0.12), secundário"
    nsupdate_teste 172.31.0.12 10.0.0.99
    echo "== nsupdate ao ns1 (172.31.0.11), primário com zona estática"
    nsupdate_teste 172.31.0.11 10.0.0.99
    echo "== estado depois das tentativas"
    estado
} > "$dir/escrita-nsupdate.txt"
cat "$dir/escrita-nsupdate.txt"

log "E8.2: serial menor ($SERIAL_MENOR, app = 10.0.0.3)"
scripts/zona.sh set app 10.0.0.3 --sem-reload > "$dir/e8-2-zona.txt" 2>&1
t0_log=$(agora_utc)
t0=$(date +%s)
scripts/zona.sh serial "$SERIAL_MENOR" >> "$dir/e8-2-zona.txt" 2>&1
log "Observação por $dur s"
echo "t_s,ns1_serial,ns1_app,ns2_serial,ns2_app,ns3_serial,ns3_app" > "$dir/linha-do-tempo.csv"
while :; do
    t=$(( $(date +%s) - t0 ))
    linha="$t"
    for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
        linha="$linha,$(serial_de $ip),$(no cliente dig @$ip app.sd.lab A +short +norecurse | tr -d '\r')"
    done
    echo "$linha" | tee -a "$dir/linha-do-tempo.csv"
    [ "$t" -ge "$dur" ] && break
    sleep "$int"
done
docker compose logs --no-color --timestamps --since "$t0_log" ns1 ns2 ns3 2>&1 \
    | awk -v t="$t0_log" 'substr($3,1,19) >= substr(t,1,19)' > "$dir/logs-e8-2.txt"
grep -iE "serial|notify|transfer|up to date" "$dir/logs-e8-2.txt" | grep -v "refused notify from non-primary" > "$dir/logs-e8-2-relevantes.txt"

log "Restauração: serial $SERIAL_RESTAURA, app = 10.0.0.1"
scripts/zona.sh set app 10.0.0.1 --sem-reload > "$dir/restauracao.txt" 2>&1
tr0=$(date +%s)
scripts/zona.sh serial "$SERIAL_RESTAURA" >> "$dir/restauracao.txt" 2>&1
espera_convergencia 30 >> "$dir/restauracao.txt"
echo "tempo até convergir (resolução de 1 s): $(( $(date +%s) - tr0 )) s" >> "$dir/restauracao.txt"
{
    estado
    echo "resolvedor: $(no cliente dig @172.31.0.53 app.sd.lab A +noall +answer | tr -d '\r')"
} > "$dir/estado-final.txt"
cat "$dir/estado-final.txt"
docker compose logs --no-color --timestamps --since "$inicio_log" ns1 ns2 ns3 > "$dir/logs.txt" 2>&1

# Resumo
amostras=$(awk 'NR > 1' "$dir/linha-do-tempo.csv" | wc -l | tr -d ' ')
mantidas=$(awk -F, 'NR > 1 && $4 == "2026101402" && $5 == "10.0.0.2" && $6 == "2026101402" && $7 == "10.0.0.2"' "$dir/linha-do-tempo.csv" | wc -l | tr -d ' ')
ns1_menor=$(awk -F, -v s="$SERIAL_MENOR" 'NR > 1 && $2 == s && $3 == "10.0.0.3"' "$dir/linha-do-tempo.csv" | wc -l | tr -d ' ')
transf=$(grep -cE "ns[23] .*(transferred serial|Transfer completed)" "$dir/logs-e8-2.txt")
{
    echo "E8 (complemento) — resumo"
    echo "estado inicial:"; sed 's/^/  /' "$dir/estado-inicial.txt"
    echo "E8.1 (serial crescente):"; sed 's/^/  /' "$dir/e8-1-estado.txt"
    echo "nsupdate ao ns2: $(grep -m1 -iE 'update failed|REFUSED|NOTAUTH|NOTZONE' "$dir/escrita-nsupdate.txt" || echo 'ver escrita-nsupdate.txt')"
    echo "E8.2 (serial $SERIAL_MENOR): $amostras amostras em ${dur} s"
    echo "  ns1 servindo $SERIAL_MENOR / 10.0.0.3: $ns1_menor de $amostras"
    echo "  ns2 e ns3 mantendo 2026101402 / 10.0.0.2: $mantidas de $amostras"
    echo "  transferências concluídas em ns2/ns3 durante a observação: $transf"
    echo "  ns1 'has gone backwards': $(grep -c 'has gone backwards' "$dir/logs-e8-2.txt")"
    echo "  ns2/ns3 'received from primary ... < ours': $(grep -c '< ours' "$dir/logs-e8-2.txt")"
    echo "  ns2/ns3 'notify ...: zone is up to date': $(grep -c 'zone is up to date' "$dir/logs-e8-2.txt")"
    echo "restauração ($SERIAL_RESTAURA):"; sed 's/^/  /' "$dir/estado-final.txt"
    grep "tempo até convergir" "$dir/restauracao.txt" | sed 's/^/  /'
} | tee "$dir/resumo.txt"
