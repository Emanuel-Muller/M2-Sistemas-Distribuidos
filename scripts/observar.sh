#!/bin/sh
# Linha do tempo: consulta ns1, ns2, ns3 (direto) e o resolvedor a cada
# intervalo e grava um CSV. Útil em E4 (cache/TTL), E5, E6 (partição/expire) e E8.
# uso: scripts/observar.sh <nome> <intervalo_s> <duracao_s> <saida.csv> [tipo=A]
#   ex.: scripts/observar.sh app.sd.lab 5 360 experimentos/E6/linha-do-tempo.csv
. "$(dirname "$0")/lib.sh"

nome=${1:?uso: observar.sh <nome> <intervalo_s> <duracao_s> <saida.csv> [tipo]}
int=${2:?}; dur=${3:?}; saida=${4:?}; tipo=${5:-A}
mkdir -p "$(dirname "$saida")"
echo "Observando $nome ($tipo) a cada ${int}s por ${dur}s -> $saida  (Ctrl+C interrompe)"
no cliente sh -s -- "$nome" "$tipo" "$int" "$dur" < scripts/conteiner/observar.sh | tr -d '\r' | tee "$saida"
