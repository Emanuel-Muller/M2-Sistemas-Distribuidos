#!/bin/sh
# Média e desvio padrão amostral (n-1) de uma coluna de um CSV.
# Valores "NA" (não medidos) são ignorados e contados à parte.
# uso: scripts/estatisticas.sh <arquivo.csv> <nome_da_coluna>
. "$(dirname "$0")/lib.sh"

arq=${1:?uso: estatisticas.sh <arquivo.csv> <coluna>}; col=${2:?informe a coluna}
awk -F, -v c="$col" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == c) k = i
              if (!k) { print "coluna nao encontrada: " c; exit 1 }; next }
    $k == "NA" || $k == "" { na++; next }
    { x = $k + 0; n++; s += x; q += x * x
      if (n == 1 || x < mn) mn = x; if (n == 1 || x > mx) mx = x }
    END {
        if (!k) exit 1
        if (n == 0) { printf "%s: nenhum valor medido (NA=%d)\n", c, na; exit }
        m = s / n; dp = (n > 1) ? sqrt((q - n * m * m) / (n - 1)) : 0
        printf "%s: n=%d  media=%.1f  desvio_padrao=%.1f  min=%.1f  max=%.1f  (NA=%d)\n", c, n, m, dp, mn, mx, na + 0
    }' "$arq"
