# Procedimento executado: E7 (Recuperação), execução complementar de 28/10/2026

- Executor: Taryck Gean Santos Pego
- Data/hora: 28/10/2026, 20:56 a 20:59 (UTC−3); os logs do BIND estão em UTC (23:56 a 23:59)
- Máquina (ver `docs/ambiente/taryck-mac.md`): Darwin arm64
- Commit/tag: `05f68f1`, com as correções dos scripts aplicadas e ainda não commitadas (elas foram commitadas depois, em `51562c8`)
- Variante (COMPOSE_FILE): base
- Previsão: `experimentos/E7/previsao.md` (a mesma da execução de 27/10)

Motivo: a versão anterior do `scripts/medir-recuperacao.sh` não consultava o estado final nos três servidores (a igualdade só aparecia nos logs do ns1) e seguia em frente mesmo sem convergência antes de uma repetição. A versão corrigida aborta se ns1, ns2 e ns3 não convergiram antes da repetição, grava `estado-final.csv` com serial e `app.sd.lab` dos três e sai com código diferente de 0 se alguma repetição não termina idêntica ou sem medida.

## Condição inicial

Variante base, serial 2026101401 nos três (laboratório restaurado ao fim do E9, às 20:52).

## Passos e comandos

```sh
scripts/medir-recuperacao.sh 5 20
```

Cinco repetições, ns3 isolado 20 s em cada. Código de saída: 0. Depois, `scripts/reset.sh` e `scripts/verificar.sh` (RESULTADO: APROVADO, 21:00:54, commit `05f68f1`).

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
| ------- | ------------ |
| `recuperacao.csv` | Por repetição: serial alvo, `rede_ms`, `sincronizado_ms`, `tempo_ms` e tipo de transferência |
| `estado-final.csv` | Por repetição: serial e `app.sd.lab` em ns1, ns2 e ns3, e se os três são idênticos |
| `repeticao-N-logs.txt` | Logs dos contêineres durante a repetição N |

## Resultados

| Repetição | Serial alvo | tempo_ms | Transferência | Início da transferência no ns3 (UTC) |
| --------- | ----------- | -------: | ------------- | ------------------------------------ |
| 1 | 2026101402 | 1750 | AXFR-style IXFR | 23:57:04,335 |
| 2 | 2026101403 | 3220 | AXFR-style IXFR | 23:57:34,342 |
| 3 | 2026101404 | 2280 | AXFR-style IXFR | 23:58:03,358 |
| 4 | 2026101405 | 2250 | AXFR-style IXFR | 23:58:32,362 |
| 5 | 2026101406 | 4280 | AXFR-style IXFR | 23:59:03,372 |

Saída do script: `tempo_ms: n=5  media=2756,0  desvio_padrao=1004,1  min=1750,0  max=4280,0  (NA=0)`

Estado final (`estado-final.csv`):

| Repetição | ns1 (serial, `app`) | ns2 (serial, `app`) | ns3 (serial, `app`) | Idêntico |
| --------- | ------------------- | ------------------- | ------------------- | -------- |
| 1 | 2026101402, 10.7.1.51 | 2026101402, 10.7.1.51 | 2026101402, 10.7.1.51 | sim |
| 2 | 2026101403, 10.7.2.79 | 2026101403, 10.7.2.79 | 2026101403, 10.7.2.79 | sim |
| 3 | 2026101404, 10.7.3.109 | 2026101404, 10.7.3.109 | 2026101404, 10.7.3.109 | sim |
| 4 | 2026101405, 10.7.4.138 | 2026101405, 10.7.4.138 | 2026101405, 10.7.4.138 | sim |
| 5 | 2026101406, 10.7.5.167 | 2026101406, 10.7.5.167 | 2026101406, 10.7.5.167 | sim |

O script imprimiu `repetições com estado final idêntico nos três: 5 de 5`.

## Observações durante a execução

- **Recuperação sem intervenção nas 5 repetições** (NA = 0), entre 1,75 s e 4,28 s depois da volta da interface.
- **Transferência.** Em cada repetição o ns1 registrou `IXFR version not in journal, falling back to AXFR` duas vezes (uma para o ns2, no reload, e uma para o ns3, depois da reconexão), cada uma seguida de `AXFR-style IXFR ended: 1 messages, 9 records, 224 bytes`.
- **NOTIFY.** Em cada repetição o ns3 recusou dois NOTIFY vindos da rede de clientes (`refused notify from non-primary`, de 172.31.0.12 e 172.31.0.11) e não aceitou nenhum antes da transferência. A sincronização veio do timer do próprio ns3.
- **Sem falhas de conexão.** Os logs das cinco repetições não têm nenhuma linha com `retry limit`, `unreachable`, `timed out`, `connection refused` ou `failed`.

---

# Análise: previsão × resultado

## Itens previstos

| Item da previsão | Previsto | Observado | Resultado |
| ---------------- | -------- | --------- | --------- |
| 1. Recuperação sem intervenção | Em todas as repetições | 5 de 5 (`NA = 0`) | **Confirmado** |
| 2. Tempo de recuperação | ~0 a ~10 s; média ~5 000 ms; desvio ~2 900 ms | 1 750 a 4 280 ms; média 2 756 ms; desvio 1 004 ms | **Faixa confirmada; distribuição divergente** (mesmo comportamento da execução de 27/10) |
| 3. Tipo de transferência | AXFR-style IXFR | Nas 5 repetições, com 9 registros e 224 bytes | **Confirmado** |
| 4. Estado final | Mesmo serial e mesmo valor nos três | 5 de 5 idênticos, por consulta direta aos três (`estado-final.csv`) | **Confirmado** |
| Gatilho da sincronização | `retry` (10 s), se o refresh falhou; senão, o próximo refresh regular | Nenhuma falha de conexão; nenhum NOTIFY aceito; a sincronização veio do refresh regular | A previsão admitia os dois caminhos; ocorreu o do refresh regular |

## Comparação com a execução de 27/10

| | 27/10 (Windows, `0e1dfd9`) | 28/10 (Mac, `05f68f1` com correções) |
| - | -------------------------- | ------------------------------------ |
| Repetições | 5 | 5 |
| Faixa de `tempo_ms` | 1 550 a 3 550 ms | 1 750 a 4 280 ms |
| Média e desvio | 2 232 ms e 859,5 ms | 2 756 ms e 1 004 ms |
| Tipo de transferência | AXFR-style IXFR | AXFR-style IXFR |
| Falhas de conexão nos logs | nenhuma | nenhuma |
| Estado final | 2026101406 nos três (pelos logs do ns1) | idêntico nos três, por consulta direta |

Os valores diferem entre as execuções, e isso é esperado: o `tempo_ms` depende da fase entre a reconexão e o próximo refresh do ns3.

## A fase entre dois relógios

Como na análise da execução original, `tempo_ms` é o instante do próximo refresh do ns3 menos o instante da reconexão. Então `tempo_ms` de uma repetição é igual ao da anterior mais a diferença entre o intervalo das transferências e o intervalo das reconexões:

| Rep. | Intervalo entre reconexões (`rede_ms`) | Intervalo entre transferências (log do ns3) | `tempo_ms` anterior + diferença | `tempo_ms` medido |
| ---- | -------------------------------------: | ------------------------------------------: | ------------------------------: | ----------------: |
| 1 | — | — | — | 1 750 |
| 2 | 28,490 s | 30,007 s | 3 267 | 3 220 |
| 3 | 29,950 s | 29,016 s | 2 286 | 2 280 |
| 4 | 28,970 s | 29,004 s | 2 314 | 2 250 |
| 5 | 29,000 s | 31,010 s | 4 260 | 4 280 |

A diferença entre a conta e o medido fica em no máximo 64 ms, dentro da resolução do vigia (consulta a cada ~0,1 s, mais o tempo do `dig`). As cinco repetições, portanto, não são amostras independentes de "0 a 10 s": a média e o desvio descrevem esta sequência, não a distribuição do tempo de recuperação.

## Conclusão

Com 20 s de isolamento, o ns3 se recuperou sozinho nas 5 repetições, entre 1,75 e 4,28 s depois da reconexão, por AXFR-style IXFR de 224 bytes. O estado final foi idêntico nos três servidores nas 5 repetições, o que agora está provado por consulta direta e não só pelos logs do ns1. O resultado reproduz o da execução de 27/10 em outra máquina e com o script corrigido.

## Limitações

- 5 repetições, não independentes (intervalo quase fixo do script e jitter do refresh).
- Resolução do vigia de ~0,1 s, mais o tempo do `dig`.
- Só um tempo de isolamento (20 s). O caso além do expire está no E5 e no E6.
- O intervalo entre as transferências das repetições 4 e 5 foi de 31,010 s, acima dos 24 a 30 s descritos na análise da execução de 27/10. A causa não foi investigada.
- Uma única máquina por execução.

## Restauração

Depois da execução foram rodados `scripts/reset.sh` e `scripts/verificar.sh` (APROVADO), deixando a variante base com serial 2026101401 nos três.
