# Procedimento executado: E7 (Recuperação)

- Responsável: Enzo Neumann
- Análise previsão × resultado: Taryck Gean
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

---

# Análise: previsão × resultado

- Fontes: `recuperacao.csv` e `repeticao-N-logs.txt`.
- Horários: os logs usam UTC. `rede_ms` e `sincronizado_ms` vêm do relógio do próprio ns3 (milissegundos desde o boot do contêiner), por isso só as diferenças entre eles têm sentido.

## Itens previstos

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| 1. Recuperação sem intervenção | Em todas as repetições | 5 de 5 (`NA = 0`) | **Confirmado** |
| 2. Tempo de recuperação | ~0 a ~10 s, espalhado; média ~5 000 ms; desvio ~2 900 ms | 1 550 a 3 550 ms; média 2 232 ms; desvio 859,5 ms | **Faixa confirmada; distribuição divergente** (detalhe abaixo) |
| 3. Tipo de transferência | AXFR-style IXFR | Nas 5: `IXFR version not in journal, falling back to AXFR` e `AXFR-style IXFR started` no ns1; 9 registros, 224 bytes, 0,001 s | **Confirmado** |
| 4. Estado final | Mesmo serial e mesmo valor nos três | Serial 2026101406 em ns1, ns2 e ns3 | **Confirmado** |
| Custo da transferência | Milissegundos | 0,001 s em todas | **Confirmado** |
| Gatilho da sincronização | `retry` (10 s), se o refresh falhou no isolamento; senão, o próximo refresh regular | Nenhuma falha de refresh no ns3 durante os isolamentos (0 linhas com `retry`, `failed` ou `unreachable`); a sincronização veio do refresh regular | A previsão admitia os dois caminhos; ocorreu o do refresh regular |

Critérios de invalidação: nenhum foi atingido. Nenhuma recuperação passou de ~15 s; nenhuma ficou perto de 0 (o gatilho não foi NOTIFY); não houve IXFR verdadeiro na variante base; não houve `NA`.

## Por que 1,5–3,6 s, e não valores espalhados entre 0 e 10 s

**Nenhum refresh falhou.** Com 20 s de isolamento e o refresh do ns3 a cada 24–30 s (abaixo), cada isolamento coube entre dois refreshes. O ns3 não chegou a tentar o primário isolado e, por isso, nunca entrou no caminho do `retry`. A recuperação aconteceu no refresh regular seguinte.

**O refresh do BIND tem jitter em segundos inteiros.** As transferências no ns3 foram às 18:13:49,691; 18:14:16,691; 18:14:43,692; 18:15:11,693 e 18:15:40,694 (UTC). São intervalos de 27,000; 27,001; 28,001 e 29,001 s: números inteiros de segundos, sempre com a mesma fração. O código do BIND 9.18.49 explica esse padrão (`lib/dns/zone.c`, macro `DNS_ZONE_JITTER_ADD`): depois de um refresh bem-sucedido, o próximo é agendado para `refresh − aleatório(0 … refresh/4 − 1)` segundos inteiros, ou seja, entre 24 e 30 s com `refresh` 30. O E3 mostra o mesmo padrão (25, 29, 26 e 30 s).

**O tempo medido é a fase entre dois relógios periódicos.** Pela definição, `tempo_ms` = instante do próximo refresh do ns3 − instante da reconexão. As reconexões vêm do script, a cada ~27 s, e os refreshes do BIND, a cada 24–30 s. A diferença entre os dois intervalos reproduz a série medida:

| Rep. | Intervalo entre reconexões (`rede_ms`) | Intervalo entre transferências (log do ns3) | `tempo_ms` anterior + diferença | `tempo_ms` medido |
|---|---|---|---|---|
| 1 | — | — | — | 1 740 |
| 2 | 27,150 s | 27,000 s | 1 740 − 150 = 1 590 | 1 660 |
| 3 | 27,060 s | 27,001 s | 1 660 − 59 = 1 601 | 1 550 |
| 4 | 26,930 s | 28,001 s | 1 550 + 1 071 = 2 621 | 2 660 |
| 5 | 28,090 s | 29,001 s | 2 660 + 911 = 3 571 | 3 550 |

A diferença entre a conta e o medido fica em no máximo 70 ms, dentro da resolução do vigia (consulta a cada ~0,1 s, mais o tempo do `dig`). As cinco repetições, portanto, não são amostras independentes de "0 a 10 s": a primeira caiu ~1,7 s antes de um refresh, e as seguintes andaram conforme o jitter de cada intervalo. A média e o desvio descrevem esta sequência, não a distribuição do tempo de recuperação.

**A faixa de 0 a 10 s continua valendo, pelos dois caminhos.** Sem refresh falho, a espera depois da reconexão é no máximo um intervalo de refresh menos a duração do isolamento: ≤ 30 − 20 = 10 s. Com refresh falho, o ns3 tenta de novo dentro do `retry`, que tem o mesmo tipo de jitter: `retry − aleatório(0 … retry/4 − 1)`, de 9 a 10 s (`zone_refresh`, no mesmo arquivo). A previsão acertou o limite, mas supôs o caminho errado e uma distribuição uniforme.

## NOTIFY durante o isolamento

- A cada repetição, o ns1 registrou `sending notifies` no reload, e o ns2 transferiu a zona logo em seguida (na repetição 2: reload às 18:13:52,867 e transferência do ns2 às 18:13:53,207).
- O ns3 recebeu apenas os NOTIFY que chegaram pela rede de clientes (`172.31.0.11` e `172.31.0.12`) e os recusou (`refused notify from non-primary`). O NOTIFY pela rede interna não chegou, porque o ns3 estava isolado dela.
- Nenhum NOTIFY foi aceito pelo ns3 antes das transferências. A recuperação dependeu só do timer do próprio secundário.

## Recuperação × duração da ausência do primário (E5, E6 e E7)

| Experimento | Tempo sem contato com o primário | Falhas de transferência antes da volta | Primário marcado como inalcançável | Tempo até o ns3 ter a zona atual |
|---|---|---|---|---|
| E7 | 20 s (isolamento) | 0 | não | 1,55 a 3,55 s |
| E5 | ~306 s (ns1 parado) | 2 (`host unreachable`) | sim | só depois de reiniciar o ns3 (185 s após a volta do ns1) |
| E6 | ~307 s (isolamento) | 2 (`timed out`) | sim | 12 min 46 s |

No BIND 9.18.49, a partir da segunda falha de conexão o primário fica marcado como inalcançável por 600 s, e depois do expire o `retry` dobra a cada tentativa (ver a análise do E5). Por isso, a duração da ausência muda o custo da recuperação de segundos (E7) para minutos (E5, E6). A série complementar `1 330`, que não foi executada, ficaria no mesmo caso do E6.

## Recuperação de estado (Q12)

O ns3 se recuperou recebendo o **estado completo** da zona (AXFR, análogo a copiar um snapshot), porque a variante base não guarda journal e o ns1 não tem como enviar só as diferenças. Com journal (variante E9), o IXFR enviaria só as alterações desde o serial do secundário, análogo a reaplicar um log. A analogia tem limites: é o estado de um único escritor, versionado pelo serial, e não um snapshot distribuído de vários processos e canais (Chandy-Lamport).

## Conclusão do E7

Com 20 s de isolamento, o ns3 se recuperou sozinho nas 5 repetições, entre 1,55 e 3,55 s depois da reconexão, por AXFR-style IXFR de 224 bytes em 0,001 s. A faixa prevista (0 a 10 s) se confirmou, mas a distribuição não: os valores foram determinados pela fase entre a reconexão do script e o refresh do ns3, que tem jitter em segundos inteiros (24 a 30 s). O gatilho foi o refresh regular, e não o `retry` nem o NOTIFY. Comparado ao E5 e ao E6, o E7 mostra que a recuperação é rápida enquanto o secundário não acumula falhas de conexão com o primário.

## Limitações

- 5 repetições, não independentes (intervalo quase fixo do script e jitter do refresh).
- Resolução do vigia de ~0,1 s, mais o tempo do `dig`.
- Só um tempo de isolamento (20 s). O caso além do expire foi observado no E5 e no E6, não nesta série.
- Uma única máquina.
