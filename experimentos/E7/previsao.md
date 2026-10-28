# Previsão: E7 (Recuperação)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: Enzo Neumann (responsável principal do E7; apoio: a definir)
- Data/hora do registro: 2026-10-27 14:35 (-0300)
- Commit/tag do laboratório: c66fd2b (branch infra/laboratorio-base)

## O que esperamos observar

Duas séries com `scripts/medir-recuperacao.sh` (variante base): a principal, `5 20` (5 repetições com o ns3 isolado por 20 s, antes do expire), e uma complementar opcional, `1 330` (1 repetição com o ns3 isolado por 330 s, depois do expire). Em cada repetição o ns3 é desconectado, o `app.sd.lab` recebe um valor novo no ns1, o ns3 é reconectado com o mesmo IP (172.30.0.13), e um vigia dentro do ns3 mede o tempo entre a volta da interface (`rede_ms`) e o instante em que o ns3 serve o serial novo (`sincronizado_ms`). A coluna `tempo_ms` é a diferença entre os dois.

1. Em todas as repetições, o ns3 alcança o serial do ns1 sem intervenção manual.
2. O tempo de recuperação fica entre ~0 e ~10 s, com valores espalhados nesse intervalo.
3. A transferência registrada no log do ns1 é **AXFR-style IXFR**: o ns3 pede incremental, mas o ns1 responde com a zona inteira.
4. No fim, ns1, ns2 e ns3 têm o mesmo serial e o mesmo valor de `app.sd.lab`.

## Por quê

**Quem dispara a recuperação.** O ns1 só envia NOTIFY quando a zona muda, e o NOTIFY para o ns3 foi enviado enquanto ele estava isolado (e falhou). Depois da reconexão, a sincronização depende do próximo timer do próprio ns3: se o refresh já falhou durante o isolamento, ele está tentando a cada `retry` (10 s); se o refresh regular ainda não venceu, ele vence nos próximos segundos. Em ambos os casos, a próxima consulta de SOA cai em algum ponto de uma janela de até ~10 s depois da reconexão. Ao ver o serial maior (comparação pela RFC 1982), o ns3 pede a transferência.

**Possível exceção.** Se um reenvio de NOTIFY do ns1 ainda estiver pendente no momento da reconexão, a sincronização pode ser quase imediata. Isso gera valores próximos de 0 e deve ser identificado nos logs da repetição.

**Por que AXFR-style IXFR.** Na variante base, a zona é editada à mão + `rndc reload`, sem `ixfr-from-differences`. O ns1 não guarda um journal de diferenças entre versões e, por isso, não consegue montar uma resposta incremental (RFC 1995): ele responde ao pedido de IXFR com a zona completa. Na variante E9 (atualização dinâmica + `max-ixfr-ratio unlimited`, adaptação A8 do README) haveria journal, e o IXFR verdadeiro seria possível.

**Recuperação ≠ reconexão.** A interface voltar (`rede_ms`) não significa estar recuperado. Só consideramos recuperado quando o serial e os registros servidos pelo ns3 são iguais aos do ns1.

**Conceitos da disciplina.** Recuperação de estado por transferência do estado completo (AXFR, análogo a copiar um snapshot) ou por log de diferenças (IXFR + journal, análogo a reaplicar um log). A analogia é limitada: é o estado de um único escritor, versionado pelo serial, e não um snapshot distribuído de vários processos e canais (Chandy-Lamport). Q12.

## Números esperados (se houver medição)

| Série | tempo_ms esperado por repetição | Média esperada | Desvio esperado |
|---|---|---|---|
| 5 × 20 s isolado (antes do expire) | ~0 a ~10 000 ms (aprox. uniforme) | ~5 000 ms | ~2 900 ms (10 000/√12) |
| 1 × 330 s isolado (depois do expire) | ~0 a ~10 000 ms | — (n = 1) | — |

- O custo da transferência em si deve ser de milissegundos (zona com 9 registros; no teste do laboratório a transferência levou 0,001 s).
- Como na previsão do E3, as repetições podem não ser independentes (timers periódicos e intervalos regulares entre repetições). Com n = 5, o desvio é pouco representativo; vamos registrar isso na análise.

## O que invalidaria a previsão

- Recuperação acima de ~15 s de forma consistente: o ns3 estaria esperando o `refresh` (30 s) em vez do `retry`, ou haveria backoff do BIND. Investigar nos logs da repetição.
- Recuperação sempre próxima de 0: a sincronização estaria sendo disparada por NOTIFY, e não pelos timers do ns3.
- `IXFR started` (incremental verdadeiro) na variante base: o ns1 teria diferenças guardadas; conferir a variante em uso.
- Timeout (`NA`) em alguma repetição: problema de reconexão (IP diferente, `allow-transfer`), não comportamento do DNS.
