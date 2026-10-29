#!/bin/sh
# E6: partição de rede. Isola o ns3 da rede interna (sincronização), mantendo-o
# acessível aos clientes, altera a zona no ns1 e registra os dois lados da
# partição até o ns3 atingir o expire do SOA.
#
# Passos:
#   1. confere convergência, limpa o cache do resolvedor, salva zonestatus do ns3;
#   2. desconecta ns3 de sdlab_interna (P0) e prova isolamento e acessibilidade;
#   3. altera app.sd.lab no ns1 via zona.sh (P1);
#   4. linha do tempo de ns1, ns2, ns3 e resolvedor a cada intervalo até o ns3
#      responder SERVFAIL (P2) ou atingir o limite;
#   5. salva logs; por padrão reconecta o ns3 com o mesmo IP e espera convergir
#      (o tempo de recuperação formal é medido no E7, com medir-recuperacao.sh).
#
# Saída: experimentos/E6/execucao-<carimbo>/
#   resumo.txt          tudo que aparece na tela, com P0, P1 e P2
#   linha-do-tempo.csv  t desde P0 + status/valor/serial de cada servidor e do resolvedor
#   isolamento.txt      redes do ns3 e teste ns3 -> ns1 depois da desconexão
#   zonestatus-ns3-antes.txt
#   logs.txt            logs de todos os contêineres durante a execução
#
# uso: scripts/e6-particao.sh [intervalo_s=5] [limite_s=420] [--manter-isolado]
. "$(dirname "$0")/lib.sh"

int=${1:-5}; lim=${2:-420}; manter=0
for a in "$@"; do [ "$a" = "--manter-isolado" ] && manter=1; done
REDE=sdlab_interna

if modo_dinamico; then
    echo "ERRO: E6 usa a variante base (zona estática). Rode: unset COMPOSE_FILE; scripts/reset.sh"
    exit 1
fi

dir="experimentos/E6/execucao-$(carimbo)"
mkdir -p "$dir"
resumo="$dir/resumo.txt"
csv="$dir/linha-do-tempo.csv"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$resumo"; }
convergir() { r=$(espera_convergencia "$1"); rc=$?; log "$r"; return "$rc"; }
conectado() { docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' ns3 | grep -q "$REDE"; }

# Uma amostra de ns1, ns2, ns3 e resolvedor (reaproveita scripts/conteiner/observar.sh).
amostra() { no cliente sh -s -- app.sd.lab A 0 0 < scripts/conteiner/observar.sh | tr -d '\r' | tail -1; }
registrar() { # fase
    linha=$(amostra)
    t=$(( $(date +%s) - P0 ))
    echo "$t,$1,$linha" >> "$csv"
    # colunas de observar.sh: hora,ns1_st,ns1_v,ns1_s,ns2_st,ns2_v,ns2_s,ns3_st,ns3_v,ns3_s,res_st,res_v,res_ttl
    echo "$linha" | awk -F, -v t="$t" -v f="$1" '{ printf "    t=%4ss %-10s ns1=%s/%s ns2=%s/%s ns3=%s %s/%s resolvedor=%s %s ttl=%s\n", t, f, $3, $4, $6, $7, $8, $9, $10, $11, $12, $13 }' | tee -a "$resumo"
}

log "E6 iniciado. Saída: $dir"
log "commit: $(git rev-parse --short HEAD 2>/dev/null || echo '?')  variante: $(variante)"
inicio=$(agora_utc)

conectado || docker network connect --ip 172.30.0.13 "$REDE" ns3
convergir 90 || { log "ERRO: laboratório não convergiu. Rode scripts/reset.sh"; exit 1; }
no resolvedor rndc flush > /dev/null 2>&1 && log "cache do resolvedor limpo"
no ns3 rndc zonestatus sd.lab > "$dir/zonestatus-ns3-antes.txt" 2>&1
S0=$(serial_de 172.31.0.11)
log "serial inicial em todos: $S0"

echo "t_s,fase,$(no cliente sh -s -- app.sd.lab A 0 0 < scripts/conteiner/observar.sh | tr -d '\r' | head -1)" > "$csv"
P0=$(date +%s)
registrar antes

# ---------------------------------------------------------------- partição
docker network disconnect "$REDE" ns3
P0=$(date +%s)
log "P0: ns3 desconectado de $REDE"
{
    echo "== redes do ns3 depois da desconexão"
    docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' ns3
    echo "== ns3 -> ns1 (172.30.0.11), esperado: sem resposta"
    no ns3 dig @172.30.0.11 sd.lab SOA +time=1 +tries=1 2>&1
    echo "== cliente -> ns3 (172.31.0.13), esperado: resposta com aa"
    no cliente dig @172.31.0.13 app.sd.lab A +norecurse +time=2 +tries=1 2>&1
} > "$dir/isolamento.txt"
if no ns3 dig @172.30.0.11 sd.lab SOA +short +time=1 +tries=1 2>/dev/null | grep -q 'ns1\.sd\.lab'; then
    log "ERRO: ns3 ainda alcança o primário. Partição não efetiva."
    docker network connect --ip 172.30.0.13 "$REDE" ns3
    exit 1
fi
log "isolamento confirmado (ns3 não alcança 172.30.0.11); detalhes em isolamento.txt"
registrar isolado

# ---------------------------------------------------------------- escrita no lado majoritário
valor="10.6.$(( $(date +%s) % 250 + 1 )).$(( $(date +%s) % 200 + 1 ))"
alvo=$(scripts/zona.sh set app "$valor" | tail -1)
P1=$(( $(date +%s) - P0 ))
log "P1 (t=${P1}s): ns1 alterado: app.sd.lab=$valor serial=$alvo"

# ---------------------------------------------------------------- linha do tempo até o expire
T_NS2=""; P2=""
while [ $(( $(date +%s) - P0 )) -le "$lim" ]; do
    registrar particao
    s2=$(tail -1 "$csv" | cut -d, -f9); st3=$(tail -1 "$csv" | cut -d, -f10)
    t=$(tail -1 "$csv" | cut -d, -f1)
    [ -z "$T_NS2" ] && [ "$s2" = "$alvo" ] && T_NS2=$t
    if [ "$st3" = "SERVFAIL" ]; then P2=$t; break; fi
    sleep "$int"
done
registrar apos-expire
sleep "$int"; registrar apos-expire

log "ns2 serviu o serial novo ($alvo) na amostra de t=${T_NS2:-nunca}s (resolução ${int}s; tempo preciso de propagação é o do E3)"
if [ -n "$P2" ]; then
    log "P2: ns3 passou a responder SERVFAIL em t=${P2}s desde a desconexão (resolução ${int}s)"
else
    log "ns3 NÃO chegou a SERVFAIL em ${lim}s (ver linha-do-tempo.csv e logs)"
fi

sleep 1
docker compose logs --no-color --timestamps --since "$inicio" > "$dir/logs.txt" 2>&1
log "NOTIFY do ns1 para o ns3 (falhas esperadas):"
grep -iE 'notify' "$dir/logs.txt" | grep '172.30.0.13' | tail -5 | tee -a "$resumo"
log "ns3 tentando falar com o primário / expire:"
grep -E '^ns3' "$dir/logs.txt" | grep -iE 'sd.lab.*(refresh|retry|expire|timed out|failure)' | tail -10 | tee -a "$resumo"

# ---------------------------------------------------------------- fim
# Código de saída: 0 = experimento concluído e ns3 reconectado e convergido
#                  (ou mantido isolado com --manter-isolado);
#                  2 = experimento concluído, mas o ns3 NÃO convergiu depois da
#                      reconexão (laboratório fora do estado-base: aguarde ou
#                      rode scripts/reset.sh antes do próximo experimento).
rc=0
if [ "$manter" -eq 1 ]; then
    log "ns3 mantido DESCONECTADO (--manter-isolado). Para religar:"
    log "  docker network connect --ip 172.30.0.13 $REDE ns3"
else
    docker network connect --ip 172.30.0.13 "$REDE" ns3
    t=$(date +%s)
    log "ns3 reconectado com o mesmo IP; esperando convergir (medição formal é no E7)"
    if convergir 120; then
        log "convergência observada $(( $(date +%s) - t ))s depois da reconexão"
    else
        log "ns3 NÃO convergiu em 120s depois da reconexão (recuperação pendente; ver recuperacao no E6/E7)"
        rc=2
    fi
fi
log "E6 terminado (código $rc). Arquivos em $dir"
exit "$rc"
