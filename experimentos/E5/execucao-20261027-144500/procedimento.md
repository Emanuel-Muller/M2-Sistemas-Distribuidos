# Procedimento executado: E5 (Falha e quórum)

- Responsável: Enzo Neumann
- Análise previsão × resultado: Taryck Gean
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

---

# Análise: previsão × resultado

- Fontes: `resumo.txt`, `quadro.csv`, `linha-do-tempo.csv`, `zonestatus-*-antes.txt`, `dig-*.txt`, `logs.txt` e `c5-complementar/`.
- Horários: o `resumo.txt` usa hora local (UTC−3); `linha-do-tempo.csv`, `logs.txt`, `zonestatus` e `dig-*.txt` usam UTC. O ns1 parou às 17:45:05,912 UTC (`exiting` no log), que é o T0 do C2 (14:45:05–06 local).
- Na `linha-do-tempo.csv`, `hora` é o início de cada amostra e `t_s` é contado no fim dela. As consultas ao ns1 e ao ns2 parados (registro e SOA) gastam 1 s de timeout cada (`+time=1` no `observar.sh`); por isso as amostras saíram a cada ~9 s, e não a cada 5 s.

## Itens previstos

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| C1 (base) | Três `NOERROR` com `aa`, mesmo valor; escrita OK | Três `NOERROR`/`aa`/`10.0.0.1`; escrita OK (serial 2026101402) | **Confirmado** |
| C2 (ns1 parado) | ns2 e ns3 `NOERROR` com `aa`; ns1 timeout; resolvedor responde; escrita falha | ns1 `TIMEOUT`; ns2 e ns3 `NOERROR`/`aa`; resolvedor `NOERROR`; escrita `service "ns1" is not running` | **Confirmado** |
| C3 (só ns3) | ns3 `NOERROR` com `aa`; resolvedor responde; escrita impossível | ns3 `NOERROR`/`aa`; resolvedor `NOERROR`; escrita falhou | **Confirmado** |
| C4: instante do `SERVFAIL` | Entre ~270 e ~300 s após a parada do ns1 | Log do ns3: `zone sd.lab/IN: expired` às 17:50:04,674, **298,8 s após T0**. É exatamente 300 s depois da última transferência (17:45:04,672), como o `zonestatus` previa (`expires: 17:50:04`). Primeira amostra com `SERVFAIL`: t = 305 s | **Confirmado** (no limite superior, porque a escrita do C1 renovou a cópia do ns3 1 s antes da parada) |
| C4: resolvedor | Deixa de obter resposta válida | Na mesma amostra (t = 305 s) ainda entregou `10.0.0.1` do cache (TTL 14, 0 ms) | **Não observado** (o C4 termina no primeiro `SERVFAIL`; detalhe abaixo) |
| C5 (só ns2 parado) | Escrita OK; ns3 com o serial novo em < 1–2 s, por NOTIFY | Execução principal: escrita OK, mas o ns3 ainda estava expirado. Execução complementar: ns3 com o serial novo **188 ms** depois da escrita; o log mostra `notify from 172.30.0.11#53758: serial 2026101402` e a transferência no mesmo milissegundo | **Confirmado** (execução complementar) |
| C6 (só ns1) | Leitura e escrita funcionam, sem réplica | ns1 `NOERROR`/`aa`; escrita OK (serial 2026101404) | **Confirmado** |
| Consulta ao ns1 parado | Timeout de ~1–2 s | `TIMEOUT` em todas as amostras (`communications error ... timed out`) | **Confirmado** |
| Resolvedor em C2/C3 | Respostas corretas, talvez com `Query time` maior | C2 e C3: respostas do cache (0 ms). Na primeira vez que o cache venceu sem ns1 e ns2 (t = 64 s), a consulta deu `TIMEOUT` | **Divergente** (detalhe abaixo) |
| Restauração depois do C4 | ns2 e ns3 voltam em até ~10 s | ns2: transferiu 0,2 s depois de o ns1 voltar. ns3: só voltou depois de ser reiniciado, 185 s depois | ns2 **Confirmado**; ns3 **Divergente** (detalhe abaixo) |

Critérios de invalidação: nenhum foi atingido. ns2 e ns3 responderam com `aa` logo depois da parada do ns1; nenhuma escrita deu OK com o ns1 parado; o `SERVFAIL` veio entre 270 e 330 s; no C5 complementar o ns3 recebeu a alteração em 188 ms, e não em ~30 s.

## Quórum: quem cai importa mais do que quantos caem

| Cenário | Nós ativos | Maioria (2 de 3)? | Sistema com quórum de maioria (N = 3, R = W = 2) | DNS: leitura | DNS: escrita |
|---|---|---|---|---|---|
| C1 | ns1, ns2, ns3 | sim | lê e escreve | lê | escreve |
| C2 | ns2, ns3 | sim | lê e escreve | lê (`aa`) | **não escreve** |
| C3 | ns3 | não | não lê, não escreve | **lê (`aa`)**, até o expire | não escreve |
| C4 | ns3, após o expire | não | não lê, não escreve | `SERVFAIL` (resolvedor ainda com cache) | não escreve |
| C5 | ns1, ns3 | sim | lê e escreve | lê | escreve |
| C6 | ns1 | não | não lê, não escreve | **lê** | **escreve** |

- **C2 e C6 são o contraste central.** Com a maioria viva (C2), a escrita falhou. Com um único nó vivo (C6), a escrita funcionou, porque esse nó é o primário. A disponibilidade da escrita depende de **qual** nó está vivo, e não de **quantos**. Isso demonstra a ausência de quórum.
- **N, R e W como analogia, com limites.** N = 3 cópias. R = 1: qualquer autoritativo responde sozinho (C3). W = 1, mas sempre no mesmo nó: o primário confirma a escrita localmente e replica depois (C5 complementar: 188 ms até o ns3; o ns2, parado, só recebeu ao voltar). Como R + W = 2 ≤ N, a leitura não tem garantia de ver a última escrita; no E6 isso aparece como leitura com `aa` de um valor antigo. A analogia é limitada: não há votação nem leitura de várias réplicas, e "R = 1" quer dizer apenas que cada servidor responde por conta própria.
- **Tolerância assimétrica.** A leitura tolerou 2 quedas, mas só por tempo limitado (expire de 300 s). A escrita tolerou quedas de secundários (C5, C6) e nenhuma queda do primário (C2–C4).
- **Detecção de falha por timeout, sem heartbeat.** O ns3 só registrou a falta do primário no primeiro refresh depois da parada: `refresh: retry limit for primary 172.30.0.11#53 exceeded` às 17:46:03,697, 58 s depois de T0. Até o expire, continuou respondendo com autoridade, sem nenhum sinal para o cliente de que o primário estava fora.

## Resolvedor: um timeout na primeira renovação do cache

`linha-do-tempo.csv` (colunas do resolvedor):

- até t = 53 s, o resolvedor respondeu do cache, com o TTL caindo de 40 para 3;
- em t = 64 s, primeira consulta depois de o cache vencer, a resposta não veio dentro de 1 s e a amostra registrou `TIMEOUT`;
- em t = 73 s, o resolvedor respondeu `NOERROR` com TTL 52: a resposta entrou no cache por volta de t = 64–65 s, logo depois de a consulta do cliente desistir;
- nas renovações seguintes (TTL 60 em t = 129, 194 e 259 s), a resposta veio dentro do prazo, sem novo timeout.

Como o log de consultas estava desligado, a sequência de forwarders é deduzida dos tempos. Explicação provável: na primeira busca, o resolvedor tentou o ns1 e o ns2 (parados) antes de chegar ao ns3 e passou de 1 s; depois disso, passou a preferir o forwarder que respondia (o BIND escolhe pelo tempo de resposta medido), como no E6. Para o cliente do resolvedor, o custo da falha de dois dos três autoritativos foi **um timeout isolado**, na primeira renovação do cache. A previsão esperava só um `Query time` maior.

**Depois do expire.** Em t = 305 s, 6 s depois de o ns3 expirar, o resolvedor ainda entregou `10.0.0.1` do cache (TTL 14). O cache estende a leitura além do expire por até um TTL (60 s), o mesmo limite expire + TTL observado no E6. O que o resolvedor faz quando esse cache vence, sem nenhum autoritativo com a zona, não foi observado.

## Restauração: o primário ficou marcado como inalcançável no ns3

Pelos logs (UTC):

- o ns1 voltou às 17:50:12,306 (`running`), e o ns2, que estava parado, transferiu a zona às 17:50:12,498;
- o ns3, que ficou ativo sem primário até expirar, recebeu o NOTIFY do ns1 às 17:50:12,806 e registrou `refresh in progress, refresh check queued`;
- depois registrou `refresh: skipping zone transfer as primary 172.30.0.11#53 (source 0.0.0.0#0) is unreachable (cached)` às 17:50:14,014; 17:50:14,514; 17:51:01; 17:52:50 e 17:53:11. O NOTIFY das 17:53:11,554 (`no serial`) também não levou à transferência;
- o ns3 só transferiu a zona às 17:53:17,986, depois de ser parado e religado na restauração do C6, 185 s depois de o ns1 voltar.

**O que o código do BIND mostra** (versão 9.18.49, a mesma do laboratório; arquivos `lib/dns/xfrin.c` e `lib/dns/zone.c`):

- uma falha de conexão na transferência (`host unreachable`, `connection refused` ou timeout) coloca o primário numa tabela de primários inalcançáveis, com validade de 600 s (`#define UNREACH_HOLD_TIME 600 /* 10 minutes */`), renovada a cada nova falha;
- a partir da segunda falha, enquanto a entrada vale, o secundário não tenta mais a transferência e registra `unreachable (cached)`;
- a tabela fica na memória do processo, então reiniciar o `named` a apaga;
- quando a zona expira, o `retry` volta a 60 s e passa a dobrar a cada tentativa (`zone_expire`: `zone->retry = DNS_ZONE_DEFAULTRETRY`; em `zone_refresh`: "exponential backoff of the retry time up to a maximum of six hours").

Os logs do E5 batem com isso:

- houve duas falhas de transferência com `host unreachable`, às 17:46:06,767 e às 17:46:40,366;
- a partir de 17:47:10, o ns3 registrou só `retry limit exceeded`, sem `Transfer started`;
- a entrada valeria até ~17:56:40 (17:46:40 + 600 s). Sem o reinício, o ns3 ficaria sem a zona pelo menos até esse horário, mais de 6 min depois de o ns1 voltar;
- depois do expire, os intervalos entre tentativas cresceram (17:51:01 → 17:52:50, 109 s).

A previsão de ~10 s considerava só o `retry` da zona e não esse efeito, que só aparece quando o secundário acumula falhas de conexão com o primário. O mesmo mecanismo explica a recuperação de 12 min 46 s no E6. Com isolamento curto e sem falhas (E7), a recuperação foi de 1,5 a 3,6 s.

## Conclusão do E5

O DNS não usa quórum. A leitura continuou disponível com qualquer autoritativo vivo, inclusive com um só (C3), mas só até o expire: o ns3 passou a `SERVFAIL` 300 s depois da última transferência, como previsto. A escrita dependeu de um nó específico: falhou com a maioria viva sem o primário (C2) e funcionou com o primário sozinho (C6). A propagação com o ns2 parado foi feita por NOTIFY em 188 ms (C5 complementar). Duas divergências em relação à previsão: o resolvedor teve um timeout na primeira renovação do cache depois da queda, em vez de apenas mais latência; e o ns3 não se recuperou em ~10 s depois da volta do primário, porque o BIND o manteve marcado como inalcançável. Ele só voltou ao ser reiniciado.

## Limitações

- Uma única execução, mais uma execução complementar do C5.
- No C4, a amostragem foi a cada ~9 s; o instante do expire vem do log, não da amostragem.
- Log de consultas desligado: a ordem dos forwarders tentados pelo resolvedor é deduzida, não observada.
- Não foi observado o resolvedor depois de o cache vencer após o expire.
- O mecanismo de primários inalcançáveis foi lido no código-fonte do BIND 9.18.49 e é compatível com os horários dos logs, mas não foi testado isoladamente.
