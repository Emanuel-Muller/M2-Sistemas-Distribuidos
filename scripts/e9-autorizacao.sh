#!/bin/sh
# E9, etapa 1: autorização da atualização dinâmica (TSIG + update-policy).
#   1. reset da variante e9 (serial inicial, journal vazio);
#   2. quatro tentativas de UPDATE com scripts/e9-atualizar.sh:
#        chave cliente1 -> ns1 | sem chave -> ns1 | chave inválida -> ns1 |
#        chave cliente1 -> ns2 (secundário);
#   3. propagação da escrita aceita, journal e logs;
#   4. restauração da variante base (unset COMPOSE_FILE + reset), salvo com --sem-restaurar.
# Saída: experimentos/E9/autorizacao/ (uma execução anterior é preservada em
#        experimentos/E9/autorizacao-anterior-<carimbo>/)
#
# uso: scripts/e9-autorizacao.sh [--sem-restaurar]
. "$(dirname "$0")/lib.sh"

restaurar=1; [ "${1:-}" = "--sem-restaurar" ] && restaurar=0
case "${COMPOSE_FILE:-}" in *e9*) ;; *) echo "ERRO: ative a variante e9 (export COMPOSE_FILE=docker-compose.yml:docker-compose.e9.yml)."; exit 1 ;; esac
for k in cliente1 cliente2 invalida; do
    [ -f "secrets/$k.key" ] || { echo "ERRO: falta secrets/$k.key. Rode scripts/gerar-chaves-tsig.sh"; exit 1; }
done

dir=experimentos/E9/autorizacao
preparar_pasta "$dir" || { echo "ERRO: não foi possível preparar $dir"; exit 1; }
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$dir/execucao.txt"; }

{
    echo "Experimento E9, etapa 1 (autorização) — contexto"
    echo "data/hora local: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "data/hora UTC:   $(date -u '+%Y-%m-%d %H:%M:%S')"
    echo "máquina: $(uname -sm)"
    echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo desconhecido)"
    echo "variante: $(variante)"
} > "$dir/contexto.txt"
cat "$dir/contexto.txt"

log "Reset da variante e9"
scripts/reset.sh > "$dir/reset.txt" 2>&1 || { log "ERRO no reset (ver reset.txt)"; exit 1; }
inicio_log=$(agora_utc)

teste() {
    arq=$1; rotulo=$2; shift 2
    log "$rotulo"
    { echo "== $rotulo"; scripts/e9-atualizar.sh "$@" 2>&1 | tr -d '\r'; } > "$dir/$arq"
    cat "$dir/$arq"
}
teste 1-valida.txt     "Chave cliente1, enviada ao ns1"                 cliente cliente1 172.31.0.11 ordem.sd.lab teste-valida
teste 2-sem-chave.txt  "Sem chave, enviada ao ns1"                      cliente nenhuma  172.31.0.11 ordem.sd.lab teste-sem-chave
teste 3-invalida.txt   "Chave inválida (nome cliente1), enviada ao ns1" cliente invalida 172.31.0.11 ordem.sd.lab teste-invalida
teste 4-secundario.txt "Chave cliente1, enviada ao ns2 (secundário)"    cliente cliente1 172.31.0.12 ordem.sd.lab teste-secundario

log "Propagação da escrita aceita"
espera_convergencia 30 > "$dir/propagacao.txt"
for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
    echo "$ip serial=$(serial_de $ip) ordem.sd.lab=$(no cliente dig @$ip ordem.sd.lab TXT +short +norecurse | tr -d '\r')"
done >> "$dir/propagacao.txt"
cat "$dir/propagacao.txt"

no ns1 named-journalprint /var/lib/bind/db.sd.lab.jnl > "$dir/journal.txt" 2>&1
docker compose logs --no-color --timestamps --since "$inicio_log" ns1 ns2 ns3 2>&1 \
    | awk -v t="$inicio_log" 'substr($3,1,19) >= substr(t,1,19)' > "$dir/logs.txt"
grep -iE "updating zone|update|denied|refused|tsig|signature|badsig|bad key|IXFR|AXFR" "$dir/logs.txt" \
    | grep -v "refused notify from non-primary" > "$dir/logs-relevantes.txt"

resultado() {
    f="$dir/$1"
    cod=$(sed -n 's/^código de saída do nsupdate: \([0-9]*\).*/\1/p' "$f")
    ser=$(sed -n 's/^serial do ns1: //p' "$f")
    msg=$(grep -m1 -i "update failed" "$f")
    [ -n "$msg" ] || msg=$(grep -m1 -iE "NOTAUTH|REFUSED|BADSIG|TSIG" "$f")
    [ -n "$msg" ] || { [ "$cod" = 0 ] && msg="aceita"; }
    echo "$2 | código $cod | serial do ns1 $ser | $msg"
}
{
    echo "E9, etapa 1 (autorização) — resumo"
    resultado 1-valida.txt     "chave cliente1 -> ns1"
    resultado 2-sem-chave.txt  "sem chave -> ns1"
    resultado 3-invalida.txt   "chave inválida -> ns1"
    resultado 4-secundario.txt "chave cliente1 -> ns2"
    echo "transações no journal: $(grep -c '^add sd.lab.*SOA' "$dir/journal.txt")"
    echo "propagação:"; sed 's/^/  /' "$dir/propagacao.txt"
} | tee "$dir/resumo.txt"

# Confere se os quatro resultados são os esperados. As recusas dos testes 2 a 4
# são o resultado correto; o que falha a execução é um resultado diferente do previsto.
# - aceita: código 0 e serial do ns1 +1
# - recusada: código diferente de 0 e serial do ns1 inalterado
rc=0
campos() { # arquivo -> "codigo antes depois"
    f="$dir/$1"
    cod=$(sed -n 's/^código de saída do nsupdate: \([0-9]*\).*/\1/p' "$f")
    ser=$(sed -n 's/^serial do ns1: //p' "$f")
    antes=${ser%% -> *}; depois=${ser##* -> }
    echo "$cod $antes $depois"
}
numero() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; }
espera_aceita() { # arquivo rotulo
    set -- "$1" "$2" $(campos "$1")
    if numero "$3" && numero "$4" && numero "$5" && [ "$3" = 0 ] && [ "$5" -eq $(( $4 + 1 )) ]; then
        echo "OK     $2: aceita, serial $4 -> $5"
    else
        echo "FALHOU $2: era esperada aceitação com serial +1 (código '$3', serial '$4' -> '$5')"; rc=1
    fi
}
espera_recusa() { # arquivo rotulo
    set -- "$1" "$2" $(campos "$1")
    if numero "$3" && numero "$4" && numero "$5" && [ "$3" != 0 ] && [ "$4" = "$5" ]; then
        echo "OK     $2: recusada (código $3), serial inalterado em $4"
    else
        echo "FALHOU $2: era esperada recusa com serial inalterado (código '$3', serial '$4' -> '$5')"; rc=1
    fi
}
# As verificações vão para um arquivo (e não para um pipe) para que "rc" valha no shell principal.
{
    echo "Verificação dos resultados esperados"
    espera_aceita 1-valida.txt     "chave cliente1 -> ns1"
    espera_recusa 2-sem-chave.txt  "sem chave -> ns1"
    espera_recusa 3-invalida.txt   "chave inválida -> ns1"
    espera_recusa 4-secundario.txt "chave cliente1 -> ns2"
    if grep -q '^AVISO' "$dir/propagacao.txt" || [ "$(grep -c 'ordem.sd.lab="teste-valida"' "$dir/propagacao.txt")" -ne 3 ]; then
        echo "FALHOU propagação: ns1, ns2 e ns3 não servem todos teste-valida"; rc=1
    else
        echo "OK     propagação: ns1, ns2 e ns3 servem teste-valida"
    fi
    [ "$rc" -eq 0 ] && echo "RESULTADO: autorização conforme o esperado" || echo "RESULTADO: autorização DIFERENTE do esperado"
} > "$dir/.verificacao"
tee -a "$dir/resumo.txt" < "$dir/.verificacao" | tee -a "$dir/execucao.txt"
rm -f "$dir/.verificacao"
rc_verif=$rc

if [ "$restaurar" -eq 1 ]; then
    log "Restauração da variante base (unset COMPOSE_FILE + reset)"
    env -u COMPOSE_FILE scripts/reset.sh > "$dir/restauracao.txt" 2>&1 || { log "ERRO na restauração (ver restauracao.txt)"; rc_verif=1; }
    tail -1 "$dir/restauracao.txt" | tee -a "$dir/execucao.txt"
    echo "Neste terminal, rode também: unset COMPOSE_FILE"
fi
exit "$rc_verif"
