# Previsão: E6 (Partição de rede)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: Enzo Neumann (responsável principal do E6; apoio: a definir)
- Data/hora do registro: 2026-10-27 14:35 (-0300)
- Commit/tag do laboratório: c66fd2b (branch infra/laboratorio-base)

## O que esperamos observar

Execução com `scripts/e6-particao.sh` (variante base). O ns3 é desconectado **só** da rede `sdlab_interna` (P0); em seguida o `app.sd.lab` é alterado no ns1 (P1). A linha do tempo registra a cada 5 s o status, o valor e o serial de ns1, ns2 e ns3, e o que o resolvedor devolve.

1. **Isolamento:** depois de P0, o ns3 não alcança 172.30.0.11 (consulta de SOA sem resposta), mas o cliente continua consultando o ns3 em 172.31.0.13 e recebe `NOERROR` com `aa`.
2. **Lado ns1 + ns2 (majoritário):** o ns1 serve o serial S+1 e o valor novo logo depois de P1; o ns2 passa a servir S+1 e o valor novo na primeira amostra depois de P1.
3. **Lado ns3 (isolado):** o ns3 continua servindo o serial S e o **valor antigo**, com autoridade (`aa`), durante vários minutos. Há **divergência** entre autoritativos: dois servidores oficiais da mesma zona dão respostas diferentes para o mesmo nome.
4. **Expire:** o ns3 passa a responder `SERVFAIL` aproximadamente 300 s depois do seu último refresh bem-sucedido.
5. **Resolvedor:** durante a partição, pode devolver o valor antigo (cache de até 60 s, ou resposta vinda do forwarder ns3) ou o novo (vindo do ns1/ns2). Depois do expire, se receber `SERVFAIL` do ns3, deve recorrer a outro forwarder e continuar respondendo. Este item é o mais incerto da previsão.
6. **Logs:** o ns1 registra falha de NOTIFY para 172.30.0.13; o ns3 registra tentativas de refresh sem resposta do primário e, no fim, a expiração da zona.

## Por quê

**Partição só na sincronização.** As transferências de zona usam a rede interna (`primaries { 172.30.0.11; }`), e as consultas dos clientes usam a rede de clientes. Cortar só a interna isola o ns3 do primário sem tirá-lo do alcance dos usuários. Esse é o cenário que o roteiro pede (p.15).

**Divergência.** O ns2 recebe o NOTIFY e transfere a zona nova em menos de ~1 s (mesmo mecanismo previsto no E3). O ns3 não recebe o NOTIFY e suas consultas de SOA a cada `refresh`/`retry` falham, então ele continua com a versão S. Não há quórum que impeça o lado minoritário de responder: cada secundário decide sozinho, pelos seus timers.

**Expire como limite de desatualização.** O `expire` (300 s) é o tempo máximo que um secundário serve dados sem conseguir confirmar com o primário. Ao atingi-lo, o ns3 prefere não responder (`SERVFAIL`) a responder algo possivelmente muito antigo. Isso **não** torna o sistema consistente: só limita a idade máxima do dado que um autoritativo isolado entrega.

**CAP e PACELC.** Durante a partição, o lado isolado escolhe **disponibilidade** (responde dado velho) em vez de consistência. Como o DNS não oferece leitura linearizável nem sem partição (cache, replicação assíncrona), a classificação esperada é **PA/EL**: sob partição, disponibilidade; sem partição, latência em vez de consistência. O expire acrescenta uma desatualização máxima por servidor. Conceitos: Q11, S1.

## Números esperados (se houver medição)

| Medida | Esperado | Origem da expectativa |
|---|---|---|
| ns2 com valor novo depois de P1 | primeira amostra (≤ 5 s; propagação real < 1 s) | NOTIFY (E3, roteiro p.13) |
| ns3 com valor antigo | de P0 até o expire | sem caminho até o primário |
| P2 (SERVFAIL no ns3) desde P0 | ~270 s a ~300 s | expire 300 s contado do último refresh, que ocorreu até ~30 s antes de P0 |
| Resolvedor com valor antigo | no máximo enquanto houver cache (TTL 60 s) ou enquanto escolher o ns3 | TTL do SOA ($TTL 60) |
| Convergência depois de reconectar | até ~10 s | `retry` do SOA (medição formal no E7) |

## O que invalidaria a previsão

- O ns3 recebendo o serial novo durante a partição: o isolamento não foi efetivo (o script aborta se o ns3 ainda alcançar o primário).
- O ns2 demorando cerca de 30 s para o valor novo: o NOTIFY não funcionou (comparar com o E3).
- O ns3 respondendo `SERVFAIL` logo depois de P0: indicaria que ele não tinha a zona carregada.
- O ns3 sem `SERVFAIL` até ~330 s: o expire efetivo não é 300 s; conferir o `zonestatus-ns3-antes.txt` e os logs.
- O resolvedor sem conseguir responder depois do expire, mesmo com ns1 e ns2 ativos: o resolvedor não recorre a outro forwarder ao receber SERVFAIL. Seria um resultado interessante e deve ser registrado, não descartado.
