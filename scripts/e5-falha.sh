#!/bin/sh
# E5: falha e quórum. Derruba o primário e depois a maioria dos autoritativos
# e registra, em cada cenário, se a leitura e a escrita continuam funcionando.
#
# Cenários:
#   C1  ns1, ns2, ns3 ativos (base)            leitura nos 3 + escrita via zona.sh
#   C2  ns1 parado                             leitura em ns2/ns3/resolvedor + tentativa de escrita
#   C3  ns1 e ns2 parados                      leitura em ns3/resolvedor + tentativa de escrita
#   C4  ns3 sozinho até o expire               linha do tempo até o ns3 responder SERVFAIL
#   C5  só ns2 parado        (extra)           leitura + escrita; ns3 recebe a escrita?
#   C6  só ns1 ativo         (extra)           leitura + escrita sem nenhuma réplica
# Entre os cenários o laboratório é restaurado e espera convergir.
#
# A tentativa de escrita com o ns1 parado usa só "rndc reload" no ns1. NÃO usa
# zona.sh, porque ele alteraria o arquivo da zona e a mudança apareceria quando
# o ns1 voltasse, contaminando o experimento.
#
# Saída: experimentos/E5/execucao-<carimbo>/
#   resumo.txt          tudo que aparece na tela
#   quadro.csv          quadro "nós ativos x leitura x escrita" (dados observados)
#   linha-do-tempo.csv  C4: estado de ns3 e do resolvedor a cada intervalo
#   dig-*.txt           saída completa de cada consulta
#   escrita-*.txt       saída completa de cada tentativa de escrita
#   zonestatus-*.txt    rndc zonestatus dos secundários antes das quedas
#   logs.txt            logs de todos os contêineres durante a execução
#
# uso: scripts/e5-falha.sh [intervalo_s=5] [limite_expire_s=420] [extras=1]
#   extras=0 pula C5 e C6.
. "$(dirname "$0")/lib.sh"

int=${1:-5}; lim=${2:-420}; extras=${3:-1}

if modo_dinamico; then
    echo "ERRO: E5 usa a variante base (zona estática). Rode: unset COMPOSE_FILE; scripts/reset.sh"
    exit 1
fi

dir="experimentos/E5/execucao-$(carimbo)"
mkdir -p "$dir"
resumo="$dir/resumo.txt"
quadro="$dir/quadro.csv"
echo "cenario,nos_ativos,leitura_ns1,leitura_ns2,leitura_ns3,leitura_resolvedor,escrita,observacao" > "$quadro"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$resumo"; }

# espera_convergencia com registro no resumo, preservando o código de saída.
convergir() { r=$(espera_convergencia "$1"); rc=$?; log "$r"; return "$rc"; }

# Consulta direta (sem recursão) a um autoritativo. Salva a saída completa.
# saída: "STATUS/aa=sim|nao/valor"
ler() { # ip rotulo
    arq="$dir/dig-$2.txt"
    no cliente dig @"$1" app.sd.lab A +norecurse +time=2 +tries=1 > "$arq" 2>&1
    st=$(awk '/status:/ {s = $6; sub(",", "", s); print s; exit}' "$arq")
    [ -z "$st" ] && st=TIMEOUT
    if grep -q 'flags:.* aa' "$arq"; then aa=sim; else aa=nao; fi
    v=$(awk '$4 == "A" {print $5; exit}' "$arq")
    echo "$st/aa=$aa/${v:--}"
}

# Consulta pelo resolvedor (com recursão). saída: "STATUS/valor/tempo_ms"
ler_resolvedor() { # rotulo
    arq="$dir/dig-$1-resolvedor.txt"
    no cliente dig @172.31.0.53 app.sd.lab A +time=2 +tries=1 > "$arq" 2>&1
    st=$(awk '/status:/ {s = $6; sub(",", "", s); print s; exit}' "$arq")
    [ -z "$st" ] && st=TIMEOUT
    v=$(awk '$4 == "A" {print $5; exit}' "$arq")
    qt=$(awk '/Query time/ {print $4; exit}' "$arq")
    echo "$st/${v:--}/${qt:-?}ms"
}

# Tentativa de escrita com o ns1 parado: só pede ao ns1 que recarregue a zona.
escrita_sem_primario() { # rotulo
    arq="$dir/escrita-$1.txt"
    docker compose exec -T ns1 rndc reload sd.lab > "$arq" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then echo "OK"; else echo "FALHOU(codigo $rc)"; fi
}

# Escrita real com o ns1 ativo. saída: "OK(serial N)" ou "FALHOU"
escrita_com_primario() { # nome ip rotulo
    arq="$dir/escrita-$3.txt"
    scripts/zona.sh set "$1" "$2" > "$arq" 2>&1
    rc=$?
    s=$(tail -1 "$arq")
    if [ "$rc" -eq 0 ]; then echo "OK(serial $s)"; else echo "FALHOU(codigo $rc)"; fi
}

# Religa contêineres parados e espera convergir.
restaurar() {
    docker compose start ns1 ns2 ns3 > /dev/null 2>&1
    t=$(date +%s)
    if convergir 120; then
        log "restauração levou $(( $(date +%s) - t ))s"
    else
        log "restauração NÃO convergiu em 120s"
    fi
}

log "E5 iniciado. Saída: $dir"
log "commit: $(git rev-parse --short HEAD 2>/dev/null || echo '?')  variante: $(variante)"
inicio=$(agora_utc)

# ---------------------------------------------------------------- C1
log "C1 (base): conferindo convergência"
convergir 90 || { log "ERRO: laboratório não convergiu. Rode scripts/reset.sh"; exit 1; }
no resolvedor rndc flush > /dev/null 2>&1 && log "cache do resolvedor limpo"
l1=$(ler 172.31.0.11 c1-ns1); l2=$(ler 172.31.0.12 c1-ns2); l3=$(ler 172.31.0.13 c1-ns3); lr=$(ler_resolvedor c1)
w=$(escrita_com_primario e5-c1 10.5.1.1 c1)
log "C1 leitura ns1=$l1 ns2=$l2 ns3=$l3 resolvedor=$lr | escrita=$w"
echo "C1,ns1+ns2+ns3,$l1,$l2,$l3,$lr,$w,base" >> "$quadro"
convergir 60

for s in ns2 ns3; do no "$s" rndc zonestatus sd.lab > "$dir/zonestatus-$s-antes.txt" 2>&1; done
log "último refresh dos secundários salvo em zonestatus-*.txt (campos 'next refresh' e 'expires')"

# ---------------------------------------------------------------- C2
log "C2: parando ns1"
docker compose stop ns1 > /dev/null 2>&1
T0=$(date +%s)
l1=$(ler 172.31.0.11 c2-ns1); l2=$(ler 172.31.0.12 c2-ns2); l3=$(ler 172.31.0.13 c2-ns3); lr=$(ler_resolvedor c2)
w=$(escrita_sem_primario c2)
log "C2 (t=$(( $(date +%s) - T0 ))s) leitura ns1=$l1 ns2=$l2 ns3=$l3 resolvedor=$lr | escrita=$w"
log "    mensagem da escrita: $(head -1 "$dir/escrita-c2.txt")"
echo "C2,ns2+ns3,$l1,$l2,$l3,$lr,$w,t=$(( $(date +%s) - T0 ))s desde a parada do ns1" >> "$quadro"

# ---------------------------------------------------------------- C3
log "C3: parando também ns2"
docker compose stop ns2 > /dev/null 2>&1
l1=$(ler 172.31.0.11 c3-ns1); l2=$(ler 172.31.0.12 c3-ns2); l3=$(ler 172.31.0.13 c3-ns3); lr=$(ler_resolvedor c3)
w=$(escrita_sem_primario c3)
log "C3 (t=$(( $(date +%s) - T0 ))s) leitura ns1=$l1 ns2=$l2 ns3=$l3 resolvedor=$lr | escrita=$w"
echo "C3,ns3,$l1,$l2,$l3,$lr,$w,t=$(( $(date +%s) - T0 ))s desde a parada do ns1" >> "$quadro"

# ---------------------------------------------------------------- C4
log "C4: observando ns3 a cada ${int}s até SERVFAIL (limite ${lim}s desde a parada do ns1)"
echo "t_s,$(no cliente sh -s -- app.sd.lab A 0 0 < scripts/conteiner/observar.sh | tr -d '\r' | head -1)" > "$dir/linha-do-tempo.csv"
T2=""
while [ $(( $(date +%s) - T0 )) -le "$lim" ]; do
    linha=$(no cliente sh -s -- app.sd.lab A 0 0 < scripts/conteiner/observar.sh | tr -d '\r' | tail -1)
    t=$(( $(date +%s) - T0 ))
    echo "$t,$linha" >> "$dir/linha-do-tempo.csv"
    st3=$(echo "$linha" | cut -d, -f8)
    echo "    t=${t}s ns3=$st3"
    if [ "$st3" = "SERVFAIL" ]; then T2=$t; break; fi
    sleep "$int"
done
if [ -n "$T2" ]; then
    l3=$(ler 172.31.0.13 c4-ns3); lr=$(ler_resolvedor c4)
    w=$(escrita_sem_primario c4)
    log "C4 ns3 passou a responder SERVFAIL em t=${T2}s (resolução ${int}s) | ns3=$l3 resolvedor=$lr"
    echo "C4,ns3 (após expire),-,-,$l3,$lr,$w,SERVFAIL em t=${T2}s desde a parada do ns1" >> "$quadro"
else
    log "C4 ns3 NÃO chegou a SERVFAIL em ${lim}s (ver linha-do-tempo.csv e logs)"
    echo "C4,ns3,-,-,sem SERVFAIL,-,-,não expirou em ${lim}s" >> "$quadro"
fi

log "restaurando ns1 e ns2"
restaurar

# ---------------------------------------------------------------- C5 e C6
if [ "$extras" = "1" ]; then
    log "C5 (extra): parando só ns2"
    docker compose stop ns2 > /dev/null 2>&1
    l1=$(ler 172.31.0.11 c5-ns1); l3=$(ler 172.31.0.13 c5-ns3); lr=$(ler_resolvedor c5)
    w=$(escrita_com_primario e5-c5 10.5.5.5 c5)
    sleep 3
    s3=$(serial_de 172.31.0.13); s1=$(serial_de 172.31.0.11)
    log "C5 leitura ns1=$l1 ns3=$l3 resolvedor=$lr | escrita=$w | após 3s: serial ns1=$s1 ns3=$s3"
    echo "C5,ns1+ns3,$l1,-,$l3,$lr,$w,após 3s serial ns1=$s1 ns3=$s3" >> "$quadro"

    log "C6 (extra): parando também ns3 (só ns1 ativo)"
    docker compose stop ns3 > /dev/null 2>&1
    l1=$(ler 172.31.0.11 c6-ns1); lr=$(ler_resolvedor c6)
    w=$(escrita_com_primario e5-c6 10.5.6.6 c6)
    log "C6 leitura ns1=$l1 resolvedor=$lr | escrita=$w"
    echo "C6,ns1,$l1,-,-,$lr,$w,sem nenhuma réplica ativa" >> "$quadro"

    log "restaurando ns2 e ns3"
    restaurar
fi

sleep 1
docker compose logs --no-color --timestamps --since "$inicio" > "$dir/logs.txt" 2>&1
log "E5 terminado."
echo
echo "Quadro (dados observados):"
column -s, -t < "$quadro" 2>/dev/null || cat "$quadro"
echo
echo "Arquivos em $dir"
