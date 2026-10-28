# Previsão: E9 (Ênfase B: atualização dinâmica e ordem das escritas)

- Responsável: Emanuel Müller Bueno
- Data/hora do registro: 27/10/2026 22:07
- Commit/tag do laboratório: c66fd2b

Ponto de partida assumido: variante `e9` (`scripts/gerar-chaves-tsig.sh`, `export COMPOSE_FILE=docker-compose.yml:docker-compose.e9.yml`, `scripts/reset.sh`, `scripts/verificar.sh` APROVADO). Nessa variante só o ns1 muda: ele carrega as chaves `cliente1` e `cliente2` (HMAC-SHA256) e a zona `sd.lab` tem `update-policy { grant cliente1 zonesub ANY; grant cliente2 zonesub ANY; }` e `max-ixfr-ratio unlimited`. ns2, ns3 e resolvedor continuam como na base. Os valores absolutos de serial dependem de testes de prontidão anteriores, por isso as previsões de serial são em **diferença** (delta) em relação ao serial inicial de cada etapa.

## O que esperamos observar

**Etapa 1: autorização (TSIG e `update-policy`), com `scripts/e9-atualizar.sh`**

1. `cliente` com a chave `cliente1`, enviando ao ns1 (172.31.0.11): o `nsupdate` termina com código 0 (aceito), o serial do ns1 sobe **+1** e o valor novo aparece com `dig @172.31.0.11 ordem.sd.lab TXT`. Aparece o arquivo `runtime/ns1/db.sd.lab.jnl` (journal). ns2 e ns3 passam a servir o mesmo valor e o mesmo serial em cerca de 1 s, e a transferência registrada no log deles é **incremental (IXFR)**, não completa.
2. Sem chave: a atualização é recusada (**REFUSED**), código de saída diferente de 0, serial e valor do ns1 inalterados.
3. Chave inválida (nome `cliente1`, segredo diferente): a assinatura não confere e o ns1 responde **NOTAUTH** (erro TSIG, provavelmente BADSIG). Serial e valor inalterados.
4. Chave válida, mas enviada ao secundário ns2 (172.31.0.12): recusada (REFUSED ou NOTAUTH, pois o ns2 não conhece a chave nem permite escrita). Nada muda no ns1.

**Etapa 2: concorrência em nomes distintos** (`scripts/e9-concorrencia.sh 20 distintos`: `cliente` escreve `c1.sd.lab` e `cliente2` escreve `c2.sd.lab`, 20 mensagens UPDATE cada, início sincronizado)

1. Todas as 40 mensagens são aceitas (`NOERROR`, 40 de 40).
2. O serial do ns1 sobe **40** (um incremento por mensagem UPDATE, e não por registro alterado): o delta do `resumo.txt` é 40.
3. O journal (`named-journalprint`) registra as transações com seriais **consecutivos, sem repetição e sem lacuna**. Cada transação é atômica e traz a troca do SOA (serial antigo → novo) junto com a troca do TXT. Ou seja, o primário serializa tudo, mesmo com dois clientes disparando ao mesmo tempo.
4. No log do ns1 aparecem 40 linhas `adding an RR` (ordem de aplicação). A ordem de **cada** cliente é preservada (c1-001 antes de c1-002, etc.), porque cada `nsupdate` só envia a próxima mensagem depois de receber a resposta da anterior. As mensagens dos dois clientes aparecem **intercaladas** de forma não determinística. Pode haver pequenas inversões entre clientes em relação ao `envio_ms`, pois o que vale é a ordem de chegada ao primário, não o relógio do cliente.
5. Estado final idêntico nos três servidores: `c1.sd.lab = "c1-020"` e `c2.sd.lab = "c2-020"`, mesmo serial em ns1, ns2 e ns3.
6. Nos secundários, o número de transferências é **muito menor que 40** (tipicamente 1 a 3 por secundário), todas IXFR, e cada uma carrega vários passos de serial de uma vez. O NOTIFY é agrupado pelo `notify-delay` (5 s). Nenhuma transferência do tipo AXFR deve aparecer na janela do experimento.

**Etapa 3: concorrência no mesmo nome** (`scripts/e9-concorrencia.sh 20 mesmo`: os dois clientes substituem `ordem.sd.lab`)

1. Também **40 de 40 aceitas** (`NOERROR`). Nenhum cliente recebe erro de conflito, porque o DNS não detecta escritas concorrentes.
2. Delta de serial **40**, journal com seriais consecutivos, como na etapa 2.
3. O valor final é **o da última mensagem aplicada** (*last applied wins*). Como a última mensagem aplicada é sempre a última de algum cliente, o valor final será `c1-020` ou `c2-020` (qual deles varia entre repetições). É idêntico em ns1, ns2 e ns3. Todos os outros valores, inclusive os do outro cliente, foram sobrescritos e **perdidos sem aviso** (lost update). Cada cliente só saberia pelo `dig`.
4. O número de linhas `adding an RR` é 40, e o journal contém todas as 40 versões intermediárias, embora a zona só mostre a última.

**Etapa 4: medição de latência e propagação** (`scripts/e9-medir.sh 5`)

Em cada uma das 5 repetições, o `nsupdate` é confirmado em dezenas de milissegundos, e ns2 e ns3 refletem o valor novo em menos de 1 s depois do envio, com desvio padrão pequeno. Nenhuma repetição estoura o timeout de 60 s (`NA`).

## Por quê

- **Atualização dinâmica (RFC 2136).** O cliente envia uma mensagem UPDATE ao primário, que a aplica **de forma atômica** (tudo ou nada), incrementa o serial e grava a mudança no journal (`.jnl`) antes de responder. Mudanças pequenas por mensagem justificam o delta de 40 em 40 mensagens.
- **TSIG e `update-policy`.** A chave compartilhada (HMAC-SHA256) autentica o cliente e a política decide o que ele pode alterar. Sem assinatura válida a escrita é recusada. Só o primário recebe escrita: o secundário não tem `allow-update` nem a chave. Isso reforça o primário como coordenador estático do E8.
- **Serialização pelo primário.** O BIND processa as atualizações de uma zona **uma de cada vez** (fila por zona). Assim, mesmo com clientes simultâneos, o resultado é uma ordem total, e o serial e o journal são o registro dessa ordem. Isso conecta com ordem total e sequenciador único em sistemas distribuídos (Q9). Quem define a ordem é o servidor, na chegada, e não o relógio dos clientes (que só serve de medição).
- **Replicação por NOTIFY + IXFR.** Os secundários pedem só as diferenças do journal entre o serial deles e o do primário. A adaptação A8 (`max-ixfr-ratio unlimited`) evita que o BIND troque IXFR por AXFR numa zona minúscula. O `notify-delay` de 5 s agrupa várias atualizações em poucas transferências.
- **Mesmo nome, sem conflito detectado.** O primário serializa, mas não sabe de causalidade entre clientes: aplica na ordem de chegada. É consistência eventual com escritor único e *last writer wins*, sem controle de concorrência otimista (sem versão por registro) nem merge. Daí o *lost update* silencioso. Relaciona com o E8 etapa 3: com um só coordenador a ordem é trivial, mas continua perdendo escritas concorrentes sobre o mesmo dado.

## Números esperados (se houver medição)

| Item | Expectativa | Origem |
|---|---|---|
| Mensagens aceitas na concorrência | 40 de 40 (N = 20 por cliente), nos dois modos | `update-policy` permite ambos os clientes e as chaves são válidas |
| Delta de serial na concorrência | 40 (um por mensagem UPDATE) | RFC 2136: incremento do serial a cada atualização aplicada |
| Latência de confirmação de um UPDATE (`confirmacao_ms`, e `latencia_ms` por mensagem) | dezenas de ms (ordem de 10–100 ms) | processo `nsupdate` + TSIG + gravação no journal, tudo na rede local do Docker |
| Propagação ns1 → ns2/ns3 (`ns2_ms`, `ns3_ms`) | < 1 s, na casa de 100–500 ms | NOTIFY imediato (README: < 1 s); sondagem a cada 100 ms; esperas de 6 s entre repetições para não herdar o `notify-delay` |
| Convergência dos secundários após o fim da rajada de 40 mensagens | 0 a ≈ 6 s | `notify-delay` de 5 s agrupando as últimas mudanças |
| Transferências por secundário na rajada | 1 a 3, todas IXFR | NOTIFY agrupado; `max-ixfr-ratio unlimited` |
| Duração dos envios (20 mensagens por cliente em paralelo) | poucos segundos | 20 × dezenas de ms por cliente |

Para as medições do `e9-medir.sh` serão feitas 5 repetições, com média e desvio padrão (R7). Para as latências da rajada, as 40 amostras por execução entram nas estatísticas.
