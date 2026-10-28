# Previsão: E4 (Consistência: cache, TTL e janela de inconsistência)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: Taryck Gean (responsável principal do E4; apoio: a definir)
- Data/hora do registro: 27/10/2026 15:28
- Commit/tag do laboratório: 3812b43

## O que esperamos observar

Variante base (com NOTIFY). Parte-se de uma zona no estado inicial e de um resolvedor com cache vazio. Os atrasos de replicação usados abaixo vêm do E3 (com NOTIFY): ns2 converge em poucos ms e ns3 em ~0,5 s depois do `rndc reload`.

1. **Cache e TTL.** A primeira consulta de `app.sd.lab` pelo resolvedor é uma falha de cache. Ele pergunta a um dos autoritativos e devolve a resposta com TTL 60, sem a flag `aa` e com `ra`. Consultas seguintes mostram o TTL diminuindo cerca de 1 s por segundo, até chegar perto de 0.
2. **Valor antigo no cache.** Alteramos `app` no primário (serial +1, `rndc reload`). Os três autoritativos passam a responder o valor novo, e o resolvedor continua devolvendo o valor antigo até o TTL do cache expirar. Depois disso, a próxima consulta busca o valor novo, com TTL de volta a ~60.
3. **Cache negativo.** A consulta de `novo.sd.lab` pelo resolvedor devolve NXDOMAIN. Criamos o nome no primário. Os autoritativos já respondem o registro, mas o resolvedor continua devolvendo NXDOMAIN até o TTL negativo expirar. Depois disso, resolve normalmente.
4. **Janela de inconsistência.** A janela máxima teórica para um cliente do resolvedor é TTL + atraso de replicação. Comparamos esse limite com o tempo medido entre a alteração no primário e o primeiro valor novo no resolvedor.

## Por quê

**Cache e TTL (RFC 1034/1035).** O resolvedor guarda a resposta pelo TTL do registro (`$TTL 60`). Um autoritativo responde com o TTL integral. Já uma resposta vinda do cache mostra o TTL restante, que cai com o tempo. Dentro do TTL o resolvedor nem consulta os autoritativos, então ele não vê a alteração: é consistência eventual com janela limitada pelo TTL (S1).

**Cache negativo (RFC 2308).** A resposta NXDOMAIN também é guardada. O tempo é o menor entre o TTL do registro SOA (60 s, pelo `$TTL`) e o campo `minimum` do SOA (20 s), ou seja, **20 s**. Criar o nome no primário não invalida o cache do resolvedor.

**Atraso de replicação.** O resolvedor encaminha para os três autoritativos (`forward only`). Quando ele consulta de novo, pode cair num secundário que ainda não atualizou. Com NOTIFY o pior caso observado no E3 foi o ns3, em ~0,5 s (medido até 0,63 s com a sondagem). Esse atraso só entra na janela se o resolvedor repopular o cache dentro desses ~0,6 s após a alteração.

**Conceito da disciplina.** É o trade-off de consistência eventual por escalabilidade e disponibilidade: o cache reduz carga e latência, e o preço é a leitura desatualizada por até um TTL.

## Números esperados (se houver medição)

| Etapa | O que medimos | Valor esperado |
|---|---|---|
| 1. Cache e TTL | TTL na 1ª resposta do resolvedor | 60 |
| 1. Cache e TTL | TTL após N segundos | 60 − N, com erro de ±1 s |
| 2. Replicação após a alteração | ns1 | valor novo logo após o reload (poucos ms) |
| 2. Replicação após a alteração | ns2 | poucos ms (E3: ≤ ~0,1 s medido) |
| 2. Replicação após a alteração | ns3 | ~0,5 s (E3: 0,57 a 0,63 s medido) |
| 2. Valor antigo no resolvedor | duração depois da alteração | TTL restante no instante da alteração: 60 − t_c, onde t_c é o tempo desde o preenchimento do cache. Ex.: alteração 10 s depois, antigo por ~50 s |
| 2. Depois do vencimento | 1º valor novo no resolvedor | TTL 60 (ou 59) |
| 3. Cache negativo | TTL do SOA na resposta NXDOMAIN | 20 (decrescendo) |
| 3. Cache negativo | duração do NXDOMAIN depois de criar o nome | restante do TTL negativo: ≤ 20 s |
| 3. Cache negativo | autoritativos depois de criar o nome | NOERROR em poucos ms (ns1, ns2) e ~0,5 s (ns3) |
| 4. Janela máxima, registro existente | TTL + atraso de replicação | 60 + ~0,6 ≈ **60,6 s** |
| 4. Janela máxima, cache negativo | TTL negativo + atraso de replicação | 20 + ~0,6 ≈ **20,6 s** |
| 4. Janela medida | alteração → 1º valor novo no resolvedor | **abaixo do máximo**: ≈ 60 − t_c |

- **Por que o medido fica abaixo do máximo.** O máximo só ocorre se a alteração acontecer no instante em que o cache foi preenchido, e o resolvedor ainda tiver consultado um secundário desatualizado. Com a alteração t_c s depois do preenchimento, o esperado é ≈ 60 − t_c.
- **Resolução da medição.** Limitada pelo intervalo de sondagem: o valor medido pode passar do real em até um intervalo.
- **Prefetch.** Se o BIND 9.18 do resolvedor usar prefetch por padrão (não verificado), uma consulta a ~2 s do fim do TTL pode devolver o valor antigo uma última vez e disparar a atualização em segundo plano. A fronteira de troca então pode aparecer até ~2 s antes do esperado.
- **Variante sem NOTIFY.** Não faz parte desta série. Se fosse usada, o atraso de replicação do E3 (16 a 26 s) levaria a janela máxima a ~60 + 30 s, perto de 90 s.

## O que invalidaria a previsão

- O resolvedor devolve o valor novo antes de o TTL expirar, com a alteração depois do preenchimento: o cache não está sendo usado (cache limpo no meio, ou `forward` sem cache) ou o TTL real não é 60.
- O TTL da 1ª resposta é diferente de 60, ou não diminui com o tempo.
- O NXDOMAIN persiste por bem mais que ~20 s (ex.: ~60 s): o TTL negativo seria o do registro SOA, não o `minimum`.
- Janela medida acima de ~61 s (registro existente) ou de ~21 s (negativo), com a alteração feita logo após o preenchimento: haveria um atraso adicional não previsto (por exemplo, um secundário bem mais lento do que no E3).
