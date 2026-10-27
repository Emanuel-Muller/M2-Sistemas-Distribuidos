# Previsão: E2 (Caminho de uma operação)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: João Balhego
- Data/hora do registro: 27/10/2026 19:06
- Commit/tag do laboratório: 8c48e53

## O que esperamos observar

Variante base, logo depois do E1 (zona no estado inicial, `app.sd.lab` = 10.0.0.1, resolvedor recém-criado e com cache vazio). Roteiro (seção 5.3, E2): comparar a consulta pelo resolvedor com a consulta direta a um autoritativo, ligar o log de consultas para ver por quais servidores a consulta passa e mostrar o caminho de uma escrita.

1. **Consulta pelo resolvedor** (`dig @172.31.0.53 app.sd.lab`). Status NOERROR, flags `qr rd ra` e **sem `aa`**, resposta `app.sd.lab. 60 IN A 10.0.0.1`. É uma falha de cache, então o TTL vem 60.
2. **Consulta repetida pelo resolvedor** (acrescentada para evidenciar o cache), alguns segundos depois. Mesmas flags e valor, com **TTL menor que 60** (aproximadamente 60 menos os segundos decorridos, com erro de ±1 s).
3. **Consulta direta ao ns1** (`dig @172.31.0.11 app.sd.lab +norecurse`). Status NOERROR, flags `qr aa` (**com `aa`**, sem `rd` por causa do `+norecurse` e **sem `ra`**, porque o ns1 tem `recursion no`), resposta `app.sd.lab. 60 IN A 10.0.0.1` com o TTL integral (60).
4. **Log de consultas** (`rndc querylog on` no resolvedor, ns1, ns2 e ns3; uma consulta pelo resolvedor; `docker logs` de cada; `rndc querylog off`).
   - O `rndc` responde `query logging is now on` e, ao final, `query logging is now off`.
   - O log do **resolvedor** tem uma linha de consulta (`query: app.sd.lab IN A`) vinda do `cliente` (172.31.0.100).
   - O log de **um** dos autoritativos tem a consulta de `app.sd.lab` vinda do **resolvedor** (172.31.0.53), que encaminha a consulta (`forward only`). **Não prevejo qual dos três** ns1, ns2 ou ns3 é escolhido. Hipótese não verificada: o BIND escolhe entre os forwarders pelo tempo de resposta medido, que é desconhecido para servidores nunca consultados.
   - Os outros dois autoritativos **não** registram essa consulta.
   - Na consulta repetida (item 2), o log do resolvedor registra a consulta do cliente e **nenhum** autoritativo registra uma nova consulta do resolvedor, porque a resposta saiu do cache.
5. **Quem guarda estado e quem tem autoridade.**
   - **Resolvedor:** guarda cache (resposta pelo TTL). Nunca responde com `aa`.
   - **ns1, ns2 e ns3:** não têm cache. Respondem a partir da zona: o ns1 a partir do arquivo de trabalho, e os secundários a partir da cópia recebida por transferência. Todos respondem com `aa`.
   - **ns1** é a origem da autoridade (primário). **ns2** e **ns3** são autoritativos replicados.
   - **cliente:** não guarda estado.
6. **Caminho de uma escrita (sem nova execução).** No DNS clássico a escrita só acontece no primário (edição da zona e incremento do serial) e chega aos secundários por NOTIFY e transferência (IXFR ou AXFR). **Isto não é uma previsão independente:** a evidência será os logs do E3 (`experimentos/E3/`), que já estão commitados, e eles serão apenas citados.

## Por quê

**Flags.** `aa` marca resposta de servidor com autoridade sobre a zona; `ra` indica que o servidor oferece recursão. O resolvedor responde com dados do cache ou obtidos de outros servidores e por isso não é autoridade. O ns1 é autoridade e não oferece recursão. O dig liga `rd` por padrão, e `+norecurse` o desliga.

**Cache e TTL.** O resolvedor guarda a resposta pelo TTL do registro (`$TTL 60`). Um autoritativo responde com o TTL integral, sem decrementá-lo. Em respostas vindas do cache, o TTL diminui com o tempo.

**Caminho da consulta.** O resolvedor tem a zona `sd.lab` como `type forward; forward only;` para os três autoritativos (172.31.0.11, .12 e .13, rede de clientes). Ele só tem interface na rede de clientes, então a consulta encaminhada sai de 172.31.0.53.

**Escrita.** O primário é o coordenador estático da zona. Os secundários não aceitam escrita e só replicam o que o primário publica (conceito de primário-backup).

## Números esperados (se houver medição)

- **TTL:** 60 na primeira resposta do resolvedor e na resposta direta do ns1; na consulta repetida, 60 − N (N = segundos entre as duas consultas), com erro de ±1 s.
- **Contagem de consultas nos logs:** na consulta única pelo resolvedor, 1 linha no resolvedor e 1 linha em exatamente um autoritativo (pela consulta encaminhada). Na consulta direta ao ns1, 1 linha só no ns1, vinda de 172.31.0.100.
- Não prevejo tempos de resposta.

## O que invalidaria a previsão

- A resposta do resolvedor ter a flag `aa`, ou não ter `ra`.
- A resposta direta do ns1 não ter `aa`, ou ter `ra`.
- A 1ª consulta pelo resolvedor vir com TTL diferente de 60 (cache já preenchido por outra consulta anterior).
- A consulta repetida vir com TTL 60 de novo, ou gerar nova consulta nos autoritativos (o cache não estaria sendo usado).
- Nenhum autoritativo registrar a consulta encaminhada, ou mais de um registrar (haveria retentativa ou outro caminho).
- O log de consultas não aparecer em `docker logs` depois do `rndc querylog on`.
