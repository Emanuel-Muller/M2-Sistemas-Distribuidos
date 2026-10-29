# Procedimento executado: E3 (Replicação primário → secundários)

- Responsável: Taryck Gean (responsável principal do E3). Execução feita por João Balhego, com o Claude Code.
- Revisão: Taryck Gean (complementos da análise)
- Data/hora: 27/10/2026, série 1 às 13:43 e série 2 às 13:44 (UTC-3)
- Máquina (ver docs/ambiente/joao-windows.md): WSL2 (Ubuntu 26.04), Docker 29.9.2, Compose v5.6.1, BIND 9.18.49
- Commit/tag (git rev-parse --short HEAD): `4c77c19` (commit da previsão, anterior à execução)
- Variante (COMPOSE_FILE): base (série 1) e sem-notify (série 2)

## Condição inicial

- `scripts/verificar.sh` → RESULTADO: APROVADO, variante base, `COMPOSE_FILE` vazio.
- Serial inicial servido: 2026101401. **Não foi rodado `scripts/reset.sh`**: o laboratório já estava no ar, e o `verificar.sh` aprovou.
- Previsão commitada antes (`4c77c19`, 13:37). Os campos de data/hora e commit do `previsao.md` ficaram como "(preencher...)" no commit. Foram preenchidos em 28/10/2026 a partir do `git log` (13:37, `4c77c19`); o texto da previsão não foi alterado.

## Passos e comandos

1. Série 1 (com NOTIFY):
   `scripts/medir-propagacao.sh com-notify 5 | tee experimentos/E3/saida-com-notify.txt`
   Logs: `docker compose logs --no-color --timestamps --since <início>` → `logs-com-notify.txt`.
2. Série 2 (sem NOTIFY), no mesmo comando de shell:
   `export COMPOSE_FILE=docker-compose.yml:docker-compose.sem-notify.yml`
   `docker compose up -d ns1` (recria só o ns1)
   `docker compose exec -T ns1 grep -n notify /etc/bind/named.conf` (confirmou `notify no;`)
   `scripts/medir-propagacao.sh sem-notify 5 120 | tee experimentos/E3/saida-sem-notify.txt`
   Logs → `logs-sem-notify.txt`.
3. Restauração: `unset COMPOSE_FILE`, `docker compose up -d ns1` (voltou `notify yes;`), `scripts/verificar.sh` → APROVADO.
4. Estatísticas: `scripts/estatisticas.sh <csv> atraso_ns2_ms` e `atraso_ns3_ms` para cada CSV.

Cada repetição: o script grava um valor novo em `app` e sobe o serial (`zona.sh set ... --sem-reload`). Depois marca t0 dentro do ns1, faz `rndc reload sd.lab` e sonda ns2 e ns3 do contêiner `cliente` (`dig +norecurse`, `sleep 0.1`) até ambos responderem o valor novo. Espera 6 s entre repetições.

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| `previsao.md` | Previsão (commit 4c77c19); texto não alterado, só os campos de data/hora e commit foram preenchidos depois |
| `com-notify-20261027-134339.csv` | 5 medições da série com NOTIFY (t0, ns2, ns3, atrasos em ms) |
| `sem-notify-20261027-134440.csv` | 5 medições da série sem NOTIFY |
| `saida-com-notify.txt`, `saida-sem-notify.txt` | Saída do script, com média e desvio |
| `logs-com-notify.txt`, `logs-sem-notify.txt` | Logs do ns1, ns2, ns3 com timestamp |

## Observações durante a execução

- O ns1 foi recriado instantes antes da série 2 para ativar `notify no`. A repetição 1 dessa série (25,5 s e 26,0 s) é a mais alta, e **não sabemos** se a recriação influenciou.
- Os logs mostram `refused notify from non-primary` (20 linhas na série 1, 10 na série 2). É esperado: os secundários se notificam pela rede de clientes (ver README).
- **NOTIFY desligado na série 2.** Em `logs-sem-notify.txt`, nenhuma das 10 linhas `sending notifies` é do ns1: 5 são do ns2 e 5 do ns3, que notificam depois de cada transferência recebida. Em `logs-com-notify.txt`, o ns1 registra `sending notifies` nos 5 reloads.
- Todas as transferências nos logs foram "IXFR version not in journal, falling back to AXFR": a zona é estática e não tem journal, então o IXFR cai para AXFR.
- O serial no fim das duas séries é 2026101411, e o `app.sd.lab` não voltou a 10.0.0.1. Antes de outro experimento, rodar `scripts/reset.sh`.

## Restauração

`unset COMPOSE_FILE`; `docker compose up -d ns1`; `scripts/verificar.sh` (APROVADO). Estado-base completo: `scripts/reset.sh`.

---

# Análise: previsão x resultado

## Dados e conta

Fonte: colunas `atraso_ns2_ms` e `atraso_ns3_ms` dos CSVs. O script usa desvio amostral (n−1). Nada foi arredondado, exceto onde indicado.

| Série | Servidor | Valores (ms) | Média | Desvio | Min–Max |
|---|---|---|---|---|---|
| Com NOTIFY | ns2 | 110, 30, 30, 40, 120 | 66,0 | 45,1 | 30–120 |
| Com NOTIFY | ns3 | 570, 620, 620, 630, 570 | 602,0 | 29,5 | 570–630 |
| Sem NOTIFY | ns2 | 25520, 17270, 16220, 16200, 17170 | 18476,0 | 3970,1 | 16200–25520 |
| Sem NOTIFY | ns3 | 26000, 22700, 18720, 21690, 18680 | 21558,0 | 3057,4 | 18680–26000 |

Conferência manual (ns2 com NOTIFY): soma = 330; média = 330/5 = 66; desvios (44, −36, −36, −26, 54); quadrados somam 8120; 8120/4 = 2030; √2030 ≈ 45,06, mostrado como 45,1.
ns3 com NOTIFY: soma 3010, média 602, quadrados dos desvios 3480, 3480/4 = 870, √870 ≈ 29,50.
Sem NOTIFY, ns2: soma 92380, média 18476, quadrados 63.047.720, /4 = 15.761.930, raiz ≈ 3970,1. ns3: soma 107790, média 21558, quadrados 37.390.080, /4 = 9.347.520, raiz ≈ 3057,4.

Razões (média sem NOTIFY / média com NOTIFY): ns2 = 18476/66,0 ≈ 279,9; ns3 = 21558/602,0 ≈ 35,8.

## Série com NOTIFY

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| Atraso por secundário | 0,2 a 1,5 s | ns2 0,03 a 0,12 s; ns3 0,57 a 0,63 s | **ns3 dentro; ns2 abaixo do limite inferior** |
| Média | ~0,5 a 1 s | ns2 66 ms; ns3 602 ms | **ns3 dentro; ns2 fora** |
| Desvio | < 0,5 s | 45,1 ms e 29,5 ms | Dentro |
| Diferença entre ns2 e ns3 | "pequena" | ~540 ms de diferença média (cerca de 9×) | **Errada** |
| Outlier por `notify-delay` (~5 s) | possível | nenhum | Não ocorreu |

**Onde a previsão errou, e por quê (os logs mostram):**

1. **O primário não notifica os secundários ao mesmo tempo.** Nos logs do ns1, a transferência do ns2 começa 0 a 4 ms após o `reload` (timestamps do BIND com resolução de ~4 ms) e a do ns3 começa 500 ms depois, nas 5 repetições: 504, 500, 500, 504 e 500 ms. Nos logs do ns3, o NOTIFY do ns1 chega ~500 ms depois do reload. A previsão tratou os dois secundários como equivalentes, e isso era falso. Os arquivos de configuração do repositório não definem nenhuma opção de ritmo de NOTIFY (só `notify yes` e `also-notify`). O espaçamento de 500 ms vem do limitador de taxa de NOTIFY do BIND, no valor padrão (`notify-rate` 20). No código do BIND 9.18.49, a taxa 20 vira um "tique" a cada 500 ms, com até 10 mensagens por tique (`setrl`, em `lib/dns/zone.c`); a primeira mensagem de uma rajada sai na hora e as demais esperam o tique seguinte (`isc_ratelimiter_enqueue`, em `lib/isc/ratelimiter.c`). O ns1 enfileira primeiro os endereços do `also-notify`, na ordem `172.30.0.12; 172.30.0.13`, e depois os dos registros NS (`zone_notify`). Por isso o ns2 é avisado na hora e o ns3 ~500 ms depois.
2. **O valor medido do ns2 (30 a 120 ms) é dominado pela sondagem, não pelo DNS.** Os logs mostram a transferência completa em ≤ 4 ms após o reload. Os 30 a 120 ms são o intervalo de sondagem (dois `dig` mais `sleep 0.1`) e o tempo de `rndc`. O ns3 mede ~500 ms do NOTIFY escalonado mais ~70 a 130 ms de sondagem.
3. **O `notify-delay` de 5 s não foi observado.** Os reloads ficaram espaçados de ~7,9 s (47,260; 55,145; 03,089; 11,021; 18,961) e o NOTIFY saiu junto de cada reload. Isso é compatível com a previsão de evitá-lo com a espera de 6 s, mas **não prova** que o atraso existe: não o provocamos.

**O que se confirmou:** com NOTIFY, a convergência é rápida (menos de 1 s nos dois), sem depender do refresh de 30 s, e com desvio pequeno. A transferência é uma AXFR pequena (224 bytes, 9 registros, 0,001 s), como a previsão supôs, mas com AXFR-style IXFR porque a zona não tem journal.

## Série sem NOTIFY

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| Faixa | ~0 a ~30 s (uniforme) | 16,2 a 26,0 s | Teto respeitado; **sem valores perto de 0** |
| Média | ~15 s | ns2 18,5 s; ns3 21,6 s | **Acima (+3,5 s e +6,6 s)** |
| Desvio | ~9 s (30/√12) | 3,97 s e 3,06 s | **Bem menor** |
| Teto de invalidação | > ~35 s | máximo 26,0 s | Não violado |
| Razão com/sem NOTIFY | 10× a 30× | ns2 ≈ 280×; ns3 ≈ 36× | **Acima do previsto** |
| Dente de serra | citado como possível | confirmado (abaixo) | Confirmado |

**Por que o resultado difere da previsão de "uniforme em 0 a 30 s":**

Os logs permitem reconstruir cada atraso. Cada transferência no ns2 acontece na primeira consulta de SOA depois do reload. Os atrasos pelo log (reload no ns1 → transferência) ficam a menos de 0,1 s dos medidos:

| Rep. | ns2 pelo log | ns2 medido | ns3 pelo log | ns3 medido |
|---|---|---|---|---|
| 1 | 25,481 s | 25,520 s | 25,977 s | 26,000 s |
| 2 | 17,172 s | 17,270 s | 22,668 s | 22,700 s |
| 3 | 16,157 s | 16,220 s | 18,653 s | 18,720 s |
| 4 | 16,117 s | 16,200 s | 21,613 s | 21,690 s |
| 5 | 17,113 s | 17,170 s | 18,609 s | 18,680 s |

1. **O timer de refresh recomeça após cada transferência bem-sucedida, e as repetições não são independentes.** As transferências do ns2 ocorrem a 16:45:13,968; 16:45:38,969; 16:46:07,970; 16:46:33,971 e 16:47:03,972, ou seja, a 25, 29, 26 e 30 s umas das outras. O script faz o reload cerca de 8 a 13 s depois da transferência anterior. O atraso vira "intervalo até a próxima consulta menos o tempo já decorrido": rep. 2: 25,0 − 7,8 = 17,2 s; rep. 3: 29,0 − 12,8 = 16,2 s; rep. 4: 26,0 − 9,9 = 16,1 s; rep. 5: 30,0 − 12,9 = 17,1 s. Isso explica a média ~17 s, o desvio pequeno e a ausência de valores perto de 0 s. Era o risco que a previsão apontava ("padrão em dente de serra"), e ele se materializou.
2. **O intervalo entre consultas não foi exatamente 30 s.** Os intervalos entre transferências consecutivas (25, 29, 26, 30 s) são menores ou iguais ao `refresh` de 30 s, em segundos inteiros. É o jitter do timer de refresh do BIND: no código do BIND 9.18.49 (`lib/dns/zone.c`, macro `DNS_ZONE_JITTER_ADD`), o próximo refresh é agendado para `refresh − aleatório(0 … refresh/4 − 1)` segundos inteiros, ou seja, entre 24 e 30 s com `refresh` 30. A previsão assumiu 30 s fixos.
3. **A repetição 1 (25,5 s) é diferente das outras.** Não há transferência anterior da série nos logs, e o ns1 acabara de ser recriado. Não tenho dado para explicar esse valor além de ficar dentro do teto de 30 s.
4. **Diferença entre ns2 e ns3.** Em todas as repetições a transferência do ns3 ocorreu `ns2 + 0,496 s + um número inteiro de segundos` (0,496; 5,496; 2,496; 5,496; 1,496 s). O desvio de ~0,5 s coincide com o escalonamento de NOTIFY da série 1, e os dois itens anteriores o explicam: cada secundário reagenda o refresh a partir da própria última transferência, sempre em segundos inteiros; como na série 1 o ns3 transferiu ~0,5 s depois do ns2, essa fração de segundo se manteve. O resultado é que o ns3 aparece sistematicamente 0,5 a 5,5 s depois do ns2.

**Por que a razão ficou acima do previsto:** a média sem NOTIFY (~18 a 22 s) ficou acima dos 15 s esperados, e o ns2 com NOTIFY (66 ms) ficou muito abaixo do 0,5 a 1 s esperado. A razão de 10× a 30× supunha as duas médias previstas.

## Conclusão do E3

- **Com NOTIFY:** a propagação é de poucos milissegundos no ns2 e ~0,5 s no ns3. O primário avisa os dois secundários em momentos diferentes, e os logs mostram isso. O NOTIFY reduz a janela de inconsistência de dezenas de segundos para menos de 1 s.
- **Sem NOTIFY:** a propagação depende do refresh do SOA (30 s) e ficou entre 16,2 e 26,0 s. O teto de ~30 s se confirmou, mas a distribuição **não é uniforme**, por causa do recomeço do timer após cada transferência e do ritmo do próprio script.
- **Previsão não ajustada.** As diferenças (ns2 muito rápido, ns2 e ns3 diferentes, média e desvio sem NOTIFY, razão) ficam registradas como erros da previsão.

## Limitações

- 5 repetições por série. Os valores sem NOTIFY não são independentes, então o desvio de 5 amostras não representa a distribuição real do atraso.
- A sondagem soma ~25 a 130 ms ao tempo real de convergência (diferença entre o medido e o log).
- Uma única máquina e um único relógio para todos os contêineres.
- O jitter do refresh e o espaçamento de 500 ms entre os NOTIFY foram explicados pelo código-fonte do BIND 9.18.49 e são compatíveis com os horários dos logs, mas não foram testados isoladamente (por exemplo, mudando `notify-rate`).
