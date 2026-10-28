# Procedimento executado: E6 (Partição de rede)

- Responsável: Enzo Neumann
- Análise previsão × resultado: Taryck Gean
- Data/hora: 2026-10-27 14:54–15:02 (-0300); observação complementar até 15:12
- Máquina (ver docs/ambiente/<pessoa>.md): docs/ambiente/enzo-windows.md
- Commit/tag (git rev-parse --short HEAD): 0e1dfd9 (previsão no commit 662e825)
- Variante (COMPOSE_FILE): base

## Condição inicial

`scripts/reset.sh` executado às 14:54. Serial 2026101401 e `app.sd.lab = 10.0.0.1` em ns1, ns2 e ns3. Cache do resolvedor limpo pelo script.

## Passos e comandos

1. `unset COMPOSE_FILE; sh scripts/reset.sh`
2. `sh scripts/e6-particao.sh` (padrões: intervalo 5 s, limite 420 s, reconexão no fim)
   - P0 (14:54:14): `docker network disconnect sdlab_interna ns3`; isolamento conferido.
   - P1 (t = 4 s): `zona.sh set app 10.6.158.58` no ns1 (serial 2026101402).
   - Linha do tempo a cada ~6 s até o ns3 responder SERVFAIL (P2), mais duas amostras.
   - Reconexão (14:59:21): `docker network connect --ip 172.30.0.13 sdlab_interna ns3`; espera de 120 s.
3. Observação complementar (fora do script): consulta ao SOA do ns3 a cada 10 s, sem nenhuma intervenção, até ele voltar a servir a zona (máximo 15 min).

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| resumo.txt | Saída completa, com P0, P1 e P2 |
| linha-do-tempo.csv | t desde P0, fase, status/valor/serial de ns1, ns2, ns3 e valor/TTL do resolvedor |
| isolamento.txt | Redes do ns3 depois da desconexão (só `sdlab_clientes`), timeout ns3 → ns1, resposta `aa` do ns3 ao cliente |
| zonestatus-ns3-antes.txt | Último carregamento 17:54:10 GMT; `expires` 17:59:10 GMT |
| logs.txt | Logs de todos os contêineres durante a execução |
| recuperacao-natural.txt | Observação complementar: serial do ns3 a cada 10 s depois da reconexão e logs do ns3 |

## Observações durante a execução

- **Isolamento efetivo.** Depois de P0, o ns3 ficou só na `sdlab_clientes` (172.31.0.13); `dig @172.30.0.11` a partir do ns3 deu `timed out`; o cliente continuou recebendo resposta com `aa`.
- **Divergência.** A partir da primeira amostra depois de P1 (t = 5 s), ns1 e ns2 serviram `10.6.158.58`/2026101402, e o ns3 serviu `10.0.0.1`/2026101401 com `NOERROR`, até t = 293 s.
- **Expire.** Primeira amostra com SERVFAIL no ns3: t = 299 s. O log do ns3 registra `zone sd.lab/IN: expired` às 17:59:10.900, igual ao `expires` do zonestatus (último carregamento + 300 s). Antes disso, tentativas de transferência com `failed to connect: timed out` e `refresh: retry limit for primary 172.30.0.11#53 exceeded` a cada ~30 s.
- **Resolvedor (resultado não previsto).** Durante toda a partição (49 amostras, t = 5 s a 293 s), o resolvedor devolveu o valor **antigo** `10.0.0.1`, renovando o cache a cada ~60 s (TTL voltando a 59), embora ns1 e ns2 já servissem o valor novo. O resolvedor tem `forwarders { 172.31.0.11; 172.31.0.12; 172.31.0.13; };`. Só depois do SERVFAIL do ns3 (t = 299 s) ele passou a devolver `10.6.158.58`.
- **NOTIFY.** O filtro do script não encontrou linhas de NOTIFY do ns1 para 172.30.0.13 em `logs.txt` (o grep do resumo veio vazio). Não há evidência no log sobre a falha do NOTIFY para o ns3.
- **Reconexão sem recuperação em 120 s.** Depois da reconexão, o ns3 registrou `refresh: skipping zone transfer as primary 172.30.0.11#53 (source 0.0.0.0#0) is unreachable (cached)`. O script terminou com `AVISO: sem convergência em 120s`.
- **Recuperação natural (observação complementar).** O ns3 voltou a servir a zona às 18:12:07 UTC (transferência de 9 registros em 0,001 s), **12 min 46 s** depois da reconexão. As tentativas de refresh registradas foram em 17:59:24, 18:00:16, 18:01:51, 18:05:49 e 18:12:07: intervalos crescentes (~52 s, ~95 s, ~238 s, ~378 s).

## Restauração

O ns3 recuperou a zona sozinho às 18:12:07 UTC (serial 2026101402 nos três). Em seguida, `sh scripts/reset.sh` antes do E7.

## Observação sobre o `resumo.txt`

A linha "convergência observada 180s depois da reconexão" registra o tempo em que o script aguardou depois de reconectar o ns3, e não o instante da convergência; a linha anterior mostra que, nesse prazo, o ns3 ainda não tinha a zona (`AVISO: sem convergência em 120s`). A recuperação do ns3 foi acompanhada em seguida, sem intervenção, e está registrada em `recuperacao-natural.txt`. A mensagem do script foi ajustada depois desta execução.

---

# Análise: previsão × resultado

- Fontes: `linha-do-tempo.csv`, `logs.txt`, `zonestatus-ns3-antes.txt`, `isolamento.txt` e `recuperacao-natural.txt`.
- Horários: o `resumo.txt` usa hora local (UTC−3); `linha-do-tempo.csv`, `logs.txt` e `zonestatus` usam UTC. P0 = 14:54:14 local = 17:54:14 UTC.

## Itens previstos

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| 1. Isolamento | ns3 não alcança 172.30.0.11; cliente recebe `NOERROR` com `aa` do ns3 | `isolamento.txt`: ns3 só em `sdlab_clientes`; `dig @172.30.0.11` a partir do ns3 deu `timed out`; `dig @172.31.0.13` do cliente deu `NOERROR`, flags `qr aa` | **Confirmado** |
| 2. Lado ns1 + ns2 | ns1 com S+1 logo após P1; ns2 na primeira amostra | Primeira amostra após P1 (t = 5 s): ns1 e ns2 com `10.6.158.58`/2026101402. Nos logs, o ns2 transferiu no mesmo milissegundo do reload do ns1 (17:54:17.248) | **Confirmado** |
| 3. Lado ns3 isolado | ns3 servindo S e o valor antigo com `aa` por vários minutos; divergência entre autoritativos | ns3 com `NOERROR` `10.0.0.1`/2026101401 em todas as amostras de t = 5 s a t = 293 s, enquanto ns1 e ns2 serviam o valor novo | **Confirmado** |
| 4. Expire | `SERVFAIL` ~300 s após o último refresh bem-sucedido; entre ~270 e ~300 s após P0 | Último carregamento do ns3: 17:54:10 (`zonestatus`); `expires` previsto 17:59:10; log do ns3: `zone sd.lab/IN: expired` às 17:59:10.900, **~297 s após P0**. Primeira amostra com `SERVFAIL`: t = 299 s | **Confirmado** (perto do limite superior, porque o último refresh foi 4 s antes de P0) |
| 5. Resolvedor | Incerto: valor antigo (cache ou ns3) ou novo (ns1/ns2); depois do expire, recorrer a outro forwarder | Valor **antigo** durante toda a partição (49 amostras, t = 5 a 293 s). Valor novo a partir de t = 299 s, depois do `SERVFAIL` do ns3 | A previsão admitia as duas possibilidades; ocorreu a menos favorável ao cliente (detalhe abaixo) |
| 6. Logs de NOTIFY | ns1 registra falha de NOTIFY para 172.30.0.13 | Nenhuma linha de falha de NOTIFY no ns1. O ns3 **recebeu** NOTIFY do ns1 pela rede de clientes (`172.31.0.11`, 17:54:17.748) e o **recusou** (`refused notify from non-primary`) | **Divergente** (detalhe abaixo) |
| Convergência após reconectar | até ~10 s | **12 min 46 s** (reconexão 17:59:21, transferência 18:12:07) | **Divergente** (detalhe abaixo) |

Critérios de invalidação: nenhum foi atingido. O ns3 não recebeu o serial novo durante a partição; o ns2 atualizou em milissegundos; o ns3 não deu `SERVFAIL` antes do expire; o `SERVFAIL` veio antes de ~330 s; o resolvedor voltou a responder corretamente depois do expire.

## O resolvedor entregou o valor antigo durante toda a partição

`linha-do-tempo.csv` (coluna do resolvedor):

- de t = 5 s a t = 293 s, o resolvedor devolveu `10.0.0.1` em todas as 49 amostras;
- o TTL voltou a 59 em t = 59, 119, 179 e 239 s. Ou seja, o cache venceu e o resolvedor **buscou a resposta de novo** quatro vezes durante a partição;
- em todas essas buscas a resposta foi o valor antigo. Depois de P1, **só o ns3** tinha `10.0.0.1`; ns1 e ns2 já tinham `10.6.158.58`. Logo, as quatro renovações foram respondidas pelo ns3;
- em t = 299 s o resolvedor passou a devolver `10.6.158.58` (TTL 59), logo depois de o ns3 passar a responder `SERVFAIL`.

**Por que o resolvedor escolheu o ns3 todas as vezes.** Como o log de consultas estava desligado, a escolha é deduzida dos valores devolvidos. Explicação provável: o BIND escolhe entre os forwarders pelo tempo de resposta medido, e o ns3 respondia normalmente, já que o isolamento afetava só a rede interna.

**Coincidência a registrar:** em t = 293 s o TTL do cache era 5, então o cache venceria em ~t = 298 s, praticamente junto do expire do ns3 (~t = 297 s). Com outro alinhamento, o resolvedor poderia ter servido o valor antigo por mais até ~60 s depois do expire, até o cache vencer. A janela de inconsistência para o cliente do resolvedor, sob partição, é limitada por **expire + TTL** (300 + 60 s), e não por TTL + atraso de replicação, que é o limite sem partição (E4).

## NOTIFY durante a partição

- A previsão esperava que o ns1 registrasse a falha do NOTIFY para 172.30.0.13. O NOTIFY é enviado por UDP e o BIND não registrou falha no log do ns1.
- O ns3 **recebeu** NOTIFY do ns1, mas pela rede de clientes (`172.31.0.11`), e o recusou porque o primário configurado é `172.30.0.11` (`primaries`). Também recusou o NOTIFY do ns2 (`172.31.0.12`).
- Consequência: a partição isolou o ns3 do primário **para efeito de sincronização**. As mensagens chegavam por outra interface, mas a configuração só aceita o primário pela rede interna, e a transferência de zona também só usa a rede interna.

## Recuperação depois da reconexão

`recuperacao-natural.txt`:

- reconexão às 17:59:21 UTC; o ns3 só transferiu a zona às 18:12:07 UTC;
- antes disso, o ns3 registrou `refresh: skipping zone transfer as primary 172.30.0.11#53 ... is unreachable (cached)` às 17:59:24, 18:00:16, 18:01:51 e 18:05:49;
- os intervalos entre tentativas cresceram: ~52 s, ~95 s, ~238 s e ~378 s até a transferência.

O log mostra que o ns3 manteve o primário marcado como inalcançável e continuou pulando as transferências mesmo com a rede de volta. Interpretação provável: o BIND guarda em cache os primários que falharam e espaça as novas tentativas após falhas repetidas (a confirmar na documentação do BIND 9.18). A previsão de ~10 s considerava só o `retry` da zona e não esse efeito, que só aparece depois de um isolamento longo.

Contraste com o E7: com isolamento de 20 s (antes do expire), o ns3 se recuperou em 1,5 a 3,6 s, sem a mensagem `unreachable (cached)`. A duração da partição muda o custo da recuperação de segundos para minutos.

## Consistência × disponibilidade ao longo do tempo (CAP e PACELC)

| Fase | ns3 (lado isolado) | ns1 + ns2 | Cliente pelo resolvedor |
|---|---|---|---|
| Partição, antes do expire (t = 5 a ~297 s) | **Disponível e inconsistente**: responde com `aa` um dado desatualizado | Disponíveis e atualizados | Recebeu o valor **antigo** o tempo todo (vindo do ns3) |
| Partição, depois do expire (t ≥ 299 s) | **Indisponível para a zona**: `SERVFAIL` em vez de dado velho | Disponíveis e atualizados | Passou a receber o valor novo |
| Depois da reconexão | Continua em `SERVFAIL` por 12 min 46 s | Disponíveis | Correto (via ns1/ns2) |

- **Sob partição, o DNS escolhe disponibilidade (A).** O lado isolado continua respondendo, com autoridade, um dado que já não é o atual. Não há quórum que o impeça: cada secundário decide sozinho pelos seus temporizadores.
- **O expire não torna o sistema consistente.** Ele só limita a idade máxima do dado que um autoritativo isolado entrega: depois de 300 s sem contato, o ns3 prefere não responder a responder algo velho demais. Para esse nó, a escolha passa de A para "não responder"; isso não é consistência forte, porque durante os ~297 s anteriores clientes já leram dado desatualizado.
- **PACELC:** PA/EL. Sob partição, disponibilidade. Sem partição, latência em vez de consistência: a replicação é assíncrona (E3: o ns3 recebe a alteração ~0,5 s depois do ns2) e o cache do resolvedor serve dado antigo por até um TTL (E4).
- O resolvedor **amplificou** a inconsistência: a maioria dos autoritativos (ns1 e ns2) já tinha o dado novo, mas o cliente viu o antigo por quase 5 minutos.

## Conclusão do E6

O isolamento do ns3 apenas da rede interna produziu divergência entre autoritativos: ns1 e ns2 serviram o valor novo em milissegundos, e o ns3 continuou servindo o antigo, com autoridade, até o expire (~297 s após a partição). O resolvedor entregou o valor antigo durante toda a partição, porque suas renovações de cache foram respondidas pelo ns3. Depois do expire, o ns3 passou a `SERVFAIL` e o resolvedor passou ao valor novo. A recuperação depois da reconexão levou 12 min 46 s, bem mais que os ~10 s previstos. A previsão se confirmou no isolamento, na divergência e no instante do expire. Divergiu no tempo de recuperação e no registro de NOTIFY, e o comportamento do resolvedor, deixado em aberto, foi o menos favorável ao cliente.

## Limitações

- Uma única execução.
- Amostragem a cada ~6 s: o instante do `SERVFAIL` vem do log (17:59:10.900), não da amostragem.
- Log de consultas desligado: a escolha do forwarder pelo resolvedor é deduzida dos valores, não observada.
- A causa do `unreachable (cached)` e do espaçamento crescente das tentativas é interpretada a partir dos logs.
- O alinhamento entre o vencimento do cache do resolvedor e o expire do ns3 foi coincidência desta execução.
