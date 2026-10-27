# Procedimento executado: E5 (Falha e quórum)

- Responsável: Enzo Neumann
- Data/hora: 2026-10-27 14:45–14:53 (-0300)
- Máquina (ver docs/ambiente/<pessoa>.md): docs/ambiente/enzo-windows.md
- Commit/tag (git rev-parse --short HEAD): 0e1dfd9 (previsão no commit 662e825)
- Variante (COMPOSE_FILE): base

## Condição inicial

`scripts/reset.sh` executado às 14:44; `verificar.sh` APROVADO às 14:42 (docs/ambiente/validacao-inicial-enzo-windows.txt). Serial inicial 2026101401 em ns1, ns2 e ns3.

## Passos e comandos

1. `unset COMPOSE_FILE; sh scripts/reset.sh`
2. `sh scripts/e5-falha.sh` (padrões: intervalo 5 s, limite 420 s, extras=1)
   - C1: leitura nos 3 autoritativos e no resolvedor; escrita `zona.sh set e5-c1 10.5.1.1`.
   - C2: `docker compose stop ns1` (14:45:06, T0); leitura; tentativa de escrita com `rndc reload` no ns1.
   - C3: `docker compose stop ns2`; leitura; tentativa de escrita.
   - C4: amostra a cada ~9 s (5 s + tempo das consultas) até o ns3 responder SERVFAIL.
   - Restauração: `docker compose start ns1 ns2 ns3`.
   - C5 (extra): `docker compose stop ns2`; escrita `zona.sh set e5-c5 10.5.5.5`; serial do ns3 após 3 s.
   - C6 (extra): `docker compose stop ns3`; escrita `zona.sh set e5-c6 10.5.6.6`.
   - Restauração final.

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| quadro.csv | Quadro "nós ativos x leitura x escrita" (C1–C6) |
| resumo.txt | Saída completa da execução, com horários |
| linha-do-tempo.csv | C4: status, valor e serial de ns1, ns2, ns3 e resolvedor desde a parada do ns1 (t_s) |
| zonestatus-ns2-antes.txt, zonestatus-ns3-antes.txt | Último carregamento e instante previsto de expire dos secundários |
| dig-*.txt | Saída completa de cada consulta |
| escrita-*.txt | Saída de cada tentativa de escrita (C2–C4: `service "ns1" is not running`) |
| logs.txt | Logs de todos os contêineres durante a execução |

## Observações durante a execução

- **C1–C3 conforme o previsto.** Sem o ns1, ns2 e ns3 responderam `NOERROR` com `aa`; com ns1 e ns2 parados, o ns3 sozinho respondeu `NOERROR` com `aa`. A escrita falhou em C2, C3 e C4.
- **Expire do ns3.** O `zonestatus-ns3-antes.txt` previa `expires: 17:50:04 GMT` (último carregamento 17:45:04 + 300 s). O log do ns3 registra `zone sd.lab/IN: expired` às 17:50:04.674. A primeira amostra com SERVFAIL foi t = 305 s (resolução da amostragem ~9 s). Antes disso: `refresh: retry limit for primary 172.30.0.11#53 exceeded`.
- **Resolvedor depois do expire.** Na amostra de t = 305 s o resolvedor ainda devolveu `NOERROR 10.0.0.1`, com TTL 14 e `Query time: 0 msec`: resposta do cache (o TTL caiu 33 → 23 → 14 nas últimas amostras). O script encerra o C4 no primeiro SERVFAIL, então não foi observado o que o resolvedor faz depois que o cache vence.
- **Restauração depois do expire não convergiu em 120 s.** O ns2 (que estava parado) recebeu a zona às 17:50:12 por AXFR. O ns3 (que ficou ativo sem primário) registrou `refresh: skipping zone transfer as primary 172.30.0.11#53 (source 0.0.0.0#0) is unreachable (cached)` às 17:50:14, 17:51:01, 17:52:50 e 17:53:11, mesmo com o ns1 de volta. O NOTIFY do ns1 também não destravou (`refresh in progress, refresh check queued`). Resultado: `AVISO: sem convergência em 120s`, restauração de 177 s.
- **C5 contaminado.** Como o ns3 ainda estava expirado, em C5 ele respondeu `SERVFAIL` e não recebeu o serial 2026101403. Não serve como teste de propagação por NOTIFY com o ns2 parado. O C5 foi refeito separadamente (ver "Execução complementar: C5").
- **C6 conforme o previsto.** Leitura e escrita (serial 2026101404) só com o ns1.
- **Restauração final.** O ns3 foi parado em C6 e religado; ao reiniciar, o cache de "primário inalcançável" foi perdido e ele fez AXFR em 17:53:17 (serial 2026101404). Convergência em 3 s.
- NOTIFY recebido pela interface da rede de clientes (172.31.0.11/.12) é recusado pelo ns3 (`refused notify from non-primary`); só o NOTIFY vindo de 172.30.0.11 é aceito. Isso é esperado pela configuração `primaries`.

## Execução complementar: C5

Feita às 15:31 (-0300), depois do E7, porque o C5 da execução principal ficou contaminado pelo ns3 expirado. Mesmo commit (0e1dfd9), variante base. Arquivos em `c5-complementar/`.

1. `sh scripts/reset.sh`; convergência em 2026101401 nos três.
2. `docker compose stop ns2`; leitura direta: ns1 `NOERROR`, ns2 timeout, ns3 `NOERROR`.
3. `scripts/zona.sh set e5-c5 10.5.5.5` (rc = 0, serial 2026101402).
4. Serial do ns3 consultado a cada ~0,2 s depois do fim do `zona.sh`, por até 10 s.
5. `docker compose start ns2`; convergência em 2026101402 nos três.

| Arquivo | O que mostra |
|---|---|
| c5-complementar/resumo.txt | Saída com horários e o tempo até o ns3 servir o serial novo |
| c5-complementar/dig-*.txt | Leituras antes e depois da escrita |
| c5-complementar/escrita.txt | Saída do `zona.sh` |
| c5-complementar/logs.txt | Logs dos contêineres |

Resultado: com o ns2 parado, a escrita funcionou e o ns3 passou a servir o serial 2026101402 **188 ms** depois do fim do `zona.sh` (resolução ~0,2 s). `e5-c5.sd.lab = 10.5.5.5` no ns3 com flag `aa`. O log do ns3 mostra `notify from 172.30.0.11#53758: serial 2026101402` seguido da transferência às 18:31:19.602 UTC: a propagação foi disparada pelo NOTIFY, como previsto. O ns2 recebeu a alteração só depois de religado.

## Restauração

Feita pelo próprio script (`docker compose start ns1 ns2 ns3`). Estado final: serial 2026101404 em ns1, ns2 e ns3. Para voltar ao estado-base: `sh scripts/reset.sh`.
