# Procedimento executado: E7 (Recuperação)

- Responsável: Enzo Neumann
- Data/hora: 2026-10-27 15:13–15:16 (-0300)
- Máquina (ver docs/ambiente/<pessoa>.md): docs/ambiente/enzo-windows.md
- Commit/tag (git rev-parse --short HEAD): 0e1dfd9 (previsão no commit 662e825)
- Variante (COMPOSE_FILE): base

## Condição inicial

`scripts/reset.sh` executado às 15:13 (depois do E6). Serial 2026101401 em ns1, ns2 e ns3.

## Passos e comandos

1. `unset COMPOSE_FILE; sh scripts/reset.sh`
2. `sh scripts/medir-recuperacao.sh 5 20` (5 repetições, ns3 isolado 20 s em cada, timeout padrão 120 s)

A série complementar `1 330` (isolamento além do expire), opcional na previsão, **não foi executada**. O comportamento depois do expire foi observado no E6 (ver `experimentos/E6/execucao-20261027-145411/recuperacao-natural.txt`).

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| recuperacao.csv | Por repetição: serial alvo, `rede_ms`, `sincronizado_ms`, `tempo_ms` e tipo de transferência |
| repeticao-N-logs.txt | Logs dos contêineres durante a repetição N |

## Resultados

| Repetição | Serial alvo | tempo_ms | Transferência | Transferência no ns3 (UTC) |
|---|---|---|---|---|
| 1 | 2026101402 | 1740 | AXFR-style IXFR | 18:13:49.691 |
| 2 | 2026101403 | 1660 | AXFR-style IXFR | 18:14:16.691 |
| 3 | 2026101404 | 1550 | AXFR-style IXFR | 18:14:43.692 |
| 4 | 2026101405 | 2660 | AXFR-style IXFR | 18:15:11.693 |
| 5 | 2026101406 | 3550 | AXFR-style IXFR | 18:15:40.694 |

Saída do script: `tempo_ms: n=5  media=2232.0  desvio_padrao=859.5  min=1550.0  max=3550.0  (NA=0)`

## Observações durante a execução

- **Recuperação sem intervenção nas 5 repetições** (NA = 0), todas entre 1,55 s e 3,55 s depois da volta da interface.
- **Transferência.** Em todas, o ns1 registrou `IXFR version not in journal, falling back to AXFR` seguido de `AXFR-style IXFR started`: o ns3 pede incremental e recebe a zona completa (9 registros, 224 bytes, 0,001 s).
- **Quem disparou a sincronização.** Os NOTIFY que chegaram ao ns3 vieram pela rede de clientes (172.31.0.11 e 172.31.0.12) e foram recusados (`refused notify from non-primary`). Não há NOTIFY aceito antes das transferências; a sincronização veio do timer do próprio ns3.
- **Repetições não independentes.** As transferências no ns3 ocorreram sempre na mesma fração de segundo (.691–.694) e com intervalos de 27–29 s entre si, ou seja, presas ao ciclo de timer do ns3. Como o script repete em intervalo quase fixo (~27 s), a reconexão cai sempre perto da mesma fase desse ciclo. Isso explica a faixa estreita (1,5–3,6 s) em vez de valores espalhados em 0–10 s.
- **Sem `unreachable (cached)`.** Com 20 s de isolamento, os logs não mostram o primário marcado como inalcançável no ns3 (diferente do E5 e do E6, em que o isolamento passou do expire).

## Restauração

O script deixa o ns3 reconectado e sincronizado (serial 2026101406 nos três). Para voltar ao estado-base: `sh scripts/reset.sh`.
