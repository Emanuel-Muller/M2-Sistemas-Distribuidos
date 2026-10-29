#!/bin/sh
# E4: consistência com cache, TTL e janela de inconsistência.
#
# Fase "positivo" (registro app.sd.lab, TTL da zona), em cada repetição:
#   1. espera o cache do resolvedor estar recém-preenchido (sem rndc flush);
#   2. inicia a sondagem (resolvedor + ns1/ns2/ns3) dentro do cliente;
#   3. <atraso_antes_s> depois, troca o valor de app no primário (serial +1),
#      marca t0 dentro do ns1 e faz rndc reload;
#   4. a sondagem segue até o resolvedor devolver o valor novo.
#   Mede: quando cada autoritativo passa a ter o valor novo, e a janela
#   (t0 -> primeiro valor novo no resolvedor), comparada ao TTL que o
#   resolvedor mostrava antes da alteração.
# Fase "negativo": o mesmo com um nome inexistente (novo.sd.lab, depois
# novo2, novo3...): o resolvedor guarda NXDOMAIN; o nome é criado no
# primário; mede-se por quanto tempo o resolvedor ainda devolve NXDOMAIN.
#
# O cache do resolvedor NUNCA é limpo: se há entrada antiga, o script espera
# o TTL dela vencer. Os autoritativos são consultados sempre com @IP e +norecurse.
#
# uso: scripts/medir-consistencia.sh [repeticoes=5] [atraso_antes_s=5] [fase=ambas|positivo|negativo]
# saída: experimentos/E4/positivo-<carimbo>.csv, negativo-<carimbo>.csv e uma
#        linha do tempo bruta por repetição (linha-<fase>-<N>-<carimbo>.csv)
. "$(dirname "$0")/lib.sh"

reps=${1:-5}; tc=${2:-5}; fase=${3:-ambas}; tc_neg=3
case "$fase" in ambas|positivo|negativo) ;; *) echo "fase inválida: $fase"; exit 1 ;; esac
[ "$(variante)" = base ] || { echo "ERRO: o E4 usa a variante base (COMPOSE_FILE vazio). Atual: $(variante)"; exit 1; }
modo_dinamico && { echo "ERRO: zona em modo dinâmico. Rode scripts/reset.sh na variante base."; exit 1; }

# TTLs da zona-base: $TTL (registros) e último campo do SOA (cache negativo).
TTL_POS=$(awk '/^\$TTL/ {print $2; exit}' "$ZONA_BASE")
TTL_NEG=$(awk '/cache negativo/ {print $1; exit}' "$ZONA_BASE")

mkdir -p experimentos/E4
sel=$(carimbo)

# Consulta o resolvedor (@IP explícito, com recursão). Imprime "status valor ttl".
consulta_res() {
    no cliente dig @172.31.0.53 "$1" A +time=2 +tries=1 +noall +comments +answer +authority 2>/dev/null | awk '
        /status:/ { st = $6; sub(",", "", st) }
        $4 == "A" && v == "" { v = $5; ttl = $2 }
        $4 == "SOA" && sttl == "" { sttl = $2 }
        END { if (st == "") st = "TIMEOUT"; if (v == "") { v = "-"; ttl = (sttl == "" ? "-" : sttl) }
              print st, v, ttl }'
}

# Espera o cache do resolvedor para <nome> estar recém-preenchido (TTL >= 50),
# SEM rndc flush: se há entrada antiga, espera o TTL dela vencer e consulta de novo.
preparar_cache() {
    nome=$1; tentativa=0
    while [ "$tentativa" -lt 3 ]; do
        set -- $(consulta_res "$nome")
        ttl=$3
        case "$ttl" in ''|*[!0-9]*) ttl=0 ;; esac
        if [ "$ttl" -ge 50 ]; then echo "  cache de $nome pronto (TTL $ttl s)"; return 0; fi
        echo "  cache de $nome com TTL $ttl s; aguardando vencer..."
        sleep $((ttl + 2)); tentativa=$((tentativa + 1))
    done
    return 1
}

# Lê uma linha do tempo. Imprime, separados por espaço (tempos em ms após t0):
#   ns1 ns2 ns3 resolvedor ttl_antes linhas_divergentes status_inicial ttl_inicial
# "linhas divergentes": leituras com os 3 autoritativos já no valor novo e o resolvedor ainda no antigo.
# Cada tempo é o instante da resposta daquele servidor (colunas t_*_ms), inclusive
# numa amostra iniciada antes de t0 cuja resposta chegou depois. Linhas do tempo
# antigas, sem essas colunas, usam o início da amostra (t_ms).
analisa() { # arquivo t0 valor_novo
    awk -F, -v t0="$2" -v novo="$3" '
        NR == 1 { next }
        ini == "" { ini = $4; sti = $2 }
        $1 < t0 { antes = $4; if (NF < 14) next }
        {
            tr = (NF >= 14) ? $11 : $1; t1 = (NF >= 14) ? $12 : $1
            t2 = (NF >= 14) ? $13 : $1; t3 = (NF >= 14) ? $14 : $1
            if (n1 == "" && $6 == novo)  n1 = t1 - t0
            if (n2 == "" && $8 == novo)  n2 = t2 - t0
            if (n3 == "" && $10 == novo) n3 = t3 - t0
            if (j == "" && $3 == novo)   j = tr - t0
            if ($3 != novo && $6 == novo && $8 == novo && $10 == novo) div++
        }
        END {
            if (n1 == "") n1 = "NA"; if (n2 == "") n2 = "NA"; if (n3 == "") n3 = "NA"
            if (j == "") j = "NA";   if (antes == "") antes = "NA"
            printf "%s %s %s %s %s %d %s %s\n", n1, n2, n3, j, antes, div, sti, ini
        }' "$1"
}

# Uma repetição: <fase> <nome sem domínio> <valor novo> <atraso antes, s> <prazo, ms> <rótulo da repetição>
repeticao() {
    fase_r=$1; nome=$2; valor=$3; atraso=$4; lim_ms=$5; rot=$6
    linha="experimentos/E4/linha-$fase_r-$rot-$sel.csv"
    no cliente sh -s -- "$nome.sd.lab" "$valor" "$lim_ms" < scripts/conteiner/janela.sh | tr -d '\r' > "$linha" &
    pid=$!
    sleep "$atraso"
    serial=$(scripts/zona.sh set "$nome" "$valor" --sem-reload | tail -1)
    t0=$(no ns1 sh -s < scripts/conteiner/recarregar.sh | tr -d '\r')
    wait "$pid"
    set -- $(analisa "$linha" "$t0" "$valor")
    n1=$1; n2=$2; n3=$3; j=$4; antes=$5; div=$6; sti=$7; ini=$8
    erro=NA
    # só calcula se janela e TTL são numéricos (NA e "-" contêm não-dígitos)
    case "$j$antes" in *[!0-9]*) ;; *) erro=$((j - antes * 1000)) ;; esac
    echo "$rot,$nome,$serial,$valor,$t0,$n1,$n2,$n3,$j,$antes,$div,$erro" >> "$csv"
    echo "  rep. $rot: 1ª leitura $sti (TTL $ini s) | ns1=${n1} ns2=${n2} ns3=${n3} ms | resolvedor=${j} ms (TTL antes=${antes} s, leituras divergentes=${div}, erro vs TTL=${erro} ms)"
}

resumo() { # coluna(s) do $csv
    for c in "$@"; do scripts/estatisticas.sh "$csv" "$c"; done
    atraso=$(awk -F, 'NR > 1 { for (i = 6; i <= 8; i++) if ($i != "NA" && $i + 0 > m) m = $i + 0 } END { print m + 0 }' "$csv")
    echo "Maior atraso de replicação observado: ${atraso} ms"
}

espera_convergencia 60 >/dev/null || echo "AVISO: autoritativos não estavam convergentes no início."
sleep 6   # evita herdar o notify-delay (5 s) de NOTIFYs anteriores
echo "Variante: $(variante) | TTL registros: ${TTL_POS}s | TTL negativo (SOA minimum): ${TTL_NEG}s"

nome_novo() { if [ "$1" -eq 1 ]; then echo novo; else echo "novo$1"; fi; }

if [ "$fase" = negativo ] || [ "$fase" = ambas ]; then
    # os nomes não podem existir: se existirem, a medição seria positiva
    r=1
    while [ "$r" -le "$reps" ]; do
        n=$(nome_novo "$r")
        if [ -n "$(no cliente dig @172.31.0.11 "$n.sd.lab" A +short +norecurse +time=2 +tries=1)" ]; then
            echo "ERRO: $n.sd.lab já existe no primário. Rode scripts/reset.sh e repita."; exit 1
        fi
        r=$((r + 1))
    done
fi

if [ "$fase" = positivo ] || [ "$fase" = ambas ]; then
    csv="experimentos/E4/positivo-$sel.csv"
    echo "repeticao,nome,serial,valor,t0_ms,ns1_ms,ns2_ms,ns3_ms,janela_ms,ttl_antes_s,linhas_divergentes,erro_vs_ttl_ms" > "$csv"
    echo "== Fase positiva: app.sd.lab, alteração ${tc}s após o início da sondagem -> $csv"
    r=1
    while [ "$r" -le "$reps" ]; do
        valor="10.4.$r.$(( $(date +%s) % 250 + 1 ))"
        preparar_cache app.sd.lab || { echo "ERRO: cache de app.sd.lab não ficou recém-preenchido."; exit 1; }
        repeticao positivo app "$valor" "$tc" $(( (tc + TTL_POS + 15) * 1000 )) "$r"
        r=$((r + 1))
    done
    echo
    resumo janela_ms erro_vs_ttl_ms ns2_ms ns3_ms
    echo "Janela máxima teórica (TTL ${TTL_POS} s + maior atraso): $(( TTL_POS * 1000 + atraso )) ms"
    echo
fi

if [ "$fase" = negativo ] || [ "$fase" = ambas ]; then
    csv="experimentos/E4/negativo-$sel.csv"
    echo "repeticao,nome,serial,valor,t0_ms,ns1_ms,ns2_ms,ns3_ms,janela_ms,ttl_antes_s,linhas_divergentes,erro_vs_ttl_ms" > "$csv"
    echo "== Fase negativa: novo.sd.lab (e novo2..), criação ${tc_neg}s após a 1ª consulta -> $csv"
    r=1
    while [ "$r" -le "$reps" ]; do
        valor="10.5.$r.$(( $(date +%s) % 250 + 1 ))"
        repeticao negativo "$(nome_novo "$r")" "$valor" "$tc_neg" $(( (tc_neg + TTL_NEG + 15) * 1000 )) "$r"
        r=$((r + 1))
    done
    echo
    resumo janela_ms erro_vs_ttl_ms ns2_ms ns3_ms
    echo "Janela máxima teórica (TTL negativo ${TTL_NEG} s + maior atraso): $(( TTL_NEG * 1000 + atraso )) ms"
fi

echo
echo "Zona alterada (app e nomes novo*). Para voltar ao estado-base: scripts/reset.sh"
