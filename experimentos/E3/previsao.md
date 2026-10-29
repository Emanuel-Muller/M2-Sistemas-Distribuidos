# Previsão: E3 (Replicação primário → secundários)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: Taryck Gean (responsável principal do E3; apoio: a definir)
- Data/hora do registro: 27/10/2026 13:37 (commit `4c77c19`, "E3: previsão antes da execução"; campo preenchido em 28/10/2026 a partir do `git log`)
- Commit/tag do laboratório: `4c77c19` (o commit que registra esta previsão; campo preenchido em 28/10/2026; o texto da previsão não foi alterado)

## O que esperamos observar

Duas séries de 5 repetições (`scripts/medir-propagacao.sh com-notify` e `sem-notify`). Em cada repetição o `app.sd.lab` recebe um valor novo, o serial sobe em 1 e o ns1 recarrega a zona. Medimos o tempo até ns2 e ns3 passarem a responder o valor novo.

1. **Série 1, com NOTIFY (base):** ns2 e ns3 convergem em pouco tempo depois do `rndc reload`, na ordem de 1 s ou menos.
2. **Série 2, sem NOTIFY (`notify no;`):** o primário não avisa ninguém. Os secundários só percebem a mudança na próxima consulta de SOA, regida pelo `refresh` do SOA (30 s). O atraso fica espalhado entre ~0 e ~30 s, e é bem maior que o da série 1.
3. Em ambas as séries o serial sobe a cada repetição. Sem isso os secundários ignoram a mudança, e a medição daria timeout (NA).

## Por quê

**Com NOTIFY (RFC 1996).** Ao recarregar a zona, o primário vê o serial novo e envia uma mensagem NOTIFY aos servidores listados em `also-notify` (172.30.0.12 e .13). Cada secundário reage na hora: consulta o SOA do primário, vê que o serial subiu e pede a transferência. A zona é minúscula, então o IXFR (RFC 1995) ou AXFR leva poucos milissegundos pela rede interna. O custo total é o reload, o NOTIFY, a consulta de SOA e a transferência. A sondagem de 100 ms soma até ~0,1 s de resolução. O timer de refresh não participa, e o roteiro relata que o kit levou menos de 1 s.

**Sem NOTIFY.** O secundário passa a depender do polling do SOA. Ele consulta o SOA do primário a cada `refresh` (30 s). `min-refresh-time 10` não muda nada, porque 30 s já está acima do mínimo. O reload do primário acontece num instante qualquer do ciclo de 30 s do secundário, então o atraso até a próxima consulta é aproximadamente uniforme em (0, 30] s. Cada secundário tem seu próprio ciclo, então ns2 e ns3 convergem em momentos diferentes e independentes.

**Conceito da disciplina.** É consistência eventual com janela limitada. O NOTIFY troca polling por push e reduz a janela. O refresh é o limite superior de segurança quando o push falha ou é desligado (relaciona-se à S1).

## Números esperados (se houver medição)

| Série | Atraso esperado por secundário | Média esperada | Desvio esperado |
|---|---|---|---|
| Com NOTIFY | 0,2 s a 1,5 s | ~0,5 a 1 s | pequeno (< 0,5 s) |
| Sem NOTIFY | 0 a ~30 s (aprox. uniforme) | ~15 s | ~9 s (30/√12) |

- **Razão entre as séries:** ordem de 10× a 30× mais lenta sem NOTIFY.
- **Teto sem NOTIFY:** em torno de 30 s (valor do `refresh`), com folga de alguns segundos para jitter do BIND e para a transferência em si. Valores muito acima de ~35 s contradiriam a previsão.
- **Possível outlier com NOTIFY:** o BIND adia NOTIFYs de mudanças muito próximas (`notify-delay`, 5 s). O script espera 6 s entre repetições para evitar isso. Se aparecer um atraso perto de 5 s, a causa provável é essa regra.
- **Cuidado com as repetições sem NOTIFY:** os resultados podem não ser independentes. O timer de refresh de cada secundário é periódico e as repetições ocorrem em intervalos de ~6 s mais o atraso medido. Por isso os atrasos podem formar um padrão em dente de serra em vez de uma amostra aleatória, o que deixa o desvio de 5 amostras pouco representativo. Vamos registrar isso na análise.
- **Variação entre ns2 e ns3:** esperamos diferenças pequenas na série 1 e diferenças grandes, de vários segundos, na série 2.

## O que invalidaria a previsão

- Série 1 com média acima de ~3 s: investigar NOTIFY bloqueado (por exemplo, as linhas `refused notify` nos logs) ou o `notify-delay`.
- Série 2 com atrasos próximos de 1 s: o NOTIFY continua ativo e a variante não foi aplicada (conferir `COMPOSE_FILE` e o `named.conf` do ns1).
- Série 2 acima de ~35 s: o refresh efetivo é maior que o do SOA, e a causa precisa ser investigada nos logs.
