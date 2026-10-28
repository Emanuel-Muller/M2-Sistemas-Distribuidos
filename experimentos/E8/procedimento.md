# Procedimento executado: E8 — Coordenação e ordem

- **Responsável:** Emanuel Müller Bueno
- **Data/hora:** 27/10/2026 (estado inicial às 22:30:58; registro deste procedimento às 23:44)
- **Máquina (ver `docs/ambiente/emanuel-windows.md`):** Windows (build 26200), PowerShell e Git Bash; Docker 29.9.2; Compose v5.6.1; BIND 9.18.49
- **Commit/tag:** laboratório `c66fd2b` (informado na previsão); previsão commitada em `6ec3be0`; resultados commitados em `2ee4065`
- **Variante (`COMPOSE_FILE`):** base (vazia)
- **Complemento e revisão:** Taryck Gean Santos Pego, 28/10/2026 (ver "Complemento" no fim deste arquivo)

## Condição inicial

O laboratório estava em execução com os serviços `ns1`, `ns2`, `ns3`, `resolvedor`, `cliente` e `cliente2` ativos.

Foi verificado que os três servidores autoritativos serviam inicialmente o serial SOA `2026101401`, e que `app.sd.lab` apontava para `10.0.0.1`.

Na execução original, os procedimentos foram realizados manualmente pelo PowerShell, utilizando `docker compose` e `dig`, em vez dos scripts Bash do projeto, pois o ambiente não possuía Bash/WSL funcional naquela ocasião.

O estado inicial foi registrado em `experimentos/E8/estado-inicial.txt`.

## Passos e comandos

1. **Registro do estado inicial:** foram consultados os registros SOA de `sd.lab` nos três servidores autoritativos, utilizando `dig`. Todos retornaram o serial `2026101401`.

2. **Preparação das evidências:** foi criada a pasta `experimentos/E8` para armazenar os resultados e uma cópia da zona de trabalho anterior ao experimento, em `zona-antes-e8.db.sd.lab`.

3. **Demonstração da coordenação — E8.1:** foi alterada a zona de trabalho do primário (`runtime/ns1/db.sd.lab`), modificando o registro `app.sd.lab` para `10.0.0.2` e incrementando o serial para `2026101402`. Após o recarregamento da zona com:

   ```powershell
   docker compose exec -T ns1 rndc reload sd.lab
   ```

   foram consultados o primário e os dois secundários. A atualização foi propagada, e os três servidores passaram a servir o serial `2026101402` e o endereço `10.0.0.2`.

4. **Teste de serial menor — E8.2:** o primário foi alterado para o serial `2026101301`, e o registro `app.sd.lab` foi modificado para `10.0.0.3`. Após recarregar a zona e aguardar seis segundos, foram consultados os três servidores. O primário passou a servir a versão com serial `2026101301` e endereço `10.0.0.3`, enquanto os secundários conservaram o serial `2026101402` e o endereço `10.0.0.2`.

5. **Restauração da consistência:** a zona de trabalho do primário foi modificada para o serial `2026101403`, e o registro `app.sd.lab` foi restaurado para `10.0.0.1`. Após recarregar a zona, foi aguardada a convergência dos secundários. Os três servidores passaram a servir o serial `2026101403` e o endereço `10.0.0.1`.

   ```powershell
   docker compose exec -T ns1 rndc reload sd.lab
   ```

6. **Verificação do resolvedor:** foi executada uma consulta ao resolvedor `172.31.0.53` para `app.sd.lab`. A resposta foi `10.0.0.1`, com status `NOERROR`.

7. **Análise da ausência de coordenação — E8.3:** foi preparada a análise conceitual do cenário de dois primários editando a mesma zona sem coordenação. Não foi realizada uma simulação com dois primários independentes.

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
| ------- | ------------ |
| `estado-inicial.txt` | Serial SOA inicial dos três servidores: `2026101401`. |
| `resultados.txt` | Registros das etapas E8.1, E8.2 e da restauração (estado dos três servidores após cada etapa) e a análise do E8.3. |
| `zona-antes-e8.db.sd.lab` | Cópia da zona de trabalho anterior às alterações do experimento. |
| `zona-e8-1.db.sd.lab` | Zona de trabalho após a E8.1 (serial `2026101402`, `app = 10.0.0.2`). |

A execução original não salvou a saída bruta do `dig` nem os logs do BIND; as consultas e o estado final foram registrados em `resultados.txt`. Essas evidências foram completadas pela execução com script descrita em "Complemento".

## Observações durante a execução

- A primeira tentativa de alterar o serial falhou devido à interpretação incorreta de `$1` na string de substituição da função PowerShell. O arquivo permaneceu com o serial `2026101401`, embora o registro `app.sd.lab` tenha sido alterado para `10.0.0.2`.
- A função de alteração foi corrigida para utilizar um `MatchEvaluator`, permitindo substituir o serial e o registro A corretamente.
- Após a correção, o primário passou a servir o serial `2026101402`, e a atualização foi propagada aos dois secundários.
- No teste de serial menor, o primário serviu `2026101301`, enquanto os secundários mantiveram `2026101402`. Isso demonstra que os secundários não aceitaram a versão de serial inferior como uma atualização mais recente.
- Para restaurar a consistência, foi utilizado o serial `2026101403`, superior ao serial conservado pelos secundários.
- Ao final, os três servidores autoritativos e o resolvedor retornaram `10.0.0.1` para `app.sd.lab`.
- A execução original foi realizada manualmente pelo PowerShell. A limitação de Bash/WSL referia-se àquele ambiente e momento; não implica que os scripts não possam ser executados em outro ambiente.
- Na execução original, a divergência da E8.2 foi observada 6 s após o reload; a previsão pedia ao menos 90 s. A observação de 90 s está no complemento.

## Restauração

A restauração foi realizada manualmente, alterando a zona de trabalho do primário para:

- **Serial SOA:** `2026101403`
- **Registro `app.sd.lab`:** `10.0.0.1`

Em seguida, foi executado:

```powershell
docker compose exec -T ns1 rndc reload sd.lab
```

A convergência foi verificada por consultas SOA e A aos três servidores autoritativos. O resolvedor também foi consultado e retornou `10.0.0.1`.

**Estado final registrado:** os três servidores autoritativos serviam o serial `2026101403`, e `app.sd.lab` resolvia para `10.0.0.1` tanto diretamente quanto pelo resolvedor.

## Complemento (execução com script)

- **Executor:** Taryck Gean Santos Pego
- **Data:** 28/10/2026
- **Máquina:** ver `docs/ambiente/taryck-mac.md`
- **Commit e horários:** registrados em `complemento/contexto.txt` e `complemento/execucao.txt`
- **Variante:** base (`unset COMPOSE_FILE`)

Motivo: registrar as evidências que a execução original não salvou (saída bruta do `dig`, papéis configurados, logs do BIND), observar a E8.2 pelo tempo previsto (90 s, três ciclos de refresh) e testar a escrita por `nsupdate` no secundário, item da previsão não executado.

Comando:

```sh
unset COMPOSE_FILE
scripts/e8-complemento.sh 90 10
```

O script executa, em sequência: `scripts/reset.sh`; registro dos papéis (`type primary`/`type secondary` nos `named.conf`) e do SOA com a flag `aa` nos três autoritativos; E8.1 (`zona.sh set app 10.0.0.2`); `nsupdate` sem chave ao ns2 e ao ns1; E8.2 (`app = 10.0.0.3` com `zona.sh serial 2026101301`) com consulta aos três servidores a cada 10 s por 90 s; restauração (`app = 10.0.0.1` com `zona.sh serial 2026101403`).

| Arquivo (`complemento/`) | O que mostra |
| ------- | ------------ |
| `contexto.txt` | Data, hora, máquina, commit e variante |
| `execucao.txt` | Horário de cada etapa |
| `reset.txt` | Saída do `scripts/reset.sh` |
| `coordenacao.txt` | `type primary`/`secondary` e `primaries` de cada `named.conf`; SOA com flags (`aa`) e MNAME nos três servidores |
| `estado-inicial.txt`, `e8-1-estado.txt` | Serial e `app.sd.lab` nos três servidores antes e depois da E8.1 |
| `escrita-nsupdate.txt` | Resposta e código de saída do `nsupdate` enviado ao ns2 e ao ns1 |
| `linha-do-tempo.csv` | E8.2: serial e `app.sd.lab` de ns1, ns2 e ns3 a cada 10 s por 90 s |
| `logs-e8-2.txt`, `logs-e8-2-relevantes.txt` | Logs do BIND desde o reload com serial menor (NOTIFY, comparação de seriais, transferências) |
| `restauracao.txt`, `estado-final.txt` | Restauração com serial maior, tempo até convergir e estado final (inclui o resolvedor) |
| `logs.txt` | Logs de ns1, ns2 e ns3 desde o reset |
| `resumo.txt` | Contagens: amostras com ns2/ns3 em `2026101402`, transferências na observação, linhas `has gone backwards`, `< ours` e `zone is up to date` |

### Resultado do complemento

Execução em 28/10/2026, das 18:56:20 às 18:58 (UTC−3), em Darwin arm64, sobre o commit `645475b` com os scripts do complemento aplicados e ainda não commitados. Uma primeira execução, às 18:51, teve o mesmo resultado; foi repetida porque o filtro de horário dos logs descartava as linhas do mesmo segundo do reload (corrigido no script).

| Etapa | ns1 | ns2 e ns3 | Evidência |
| ----- | --- | --------- | --------- |
| Estado inicial | 2026101401, 10.0.0.1 | 2026101401, 10.0.0.1 | `estado-inicial.txt` |
| E8.1: serial crescente | 2026101402, 10.0.0.2 | 2026101402, 10.0.0.2 | `e8-1-estado.txt` |
| `nsupdate` sem chave ao ns2 e ao ns1 | `update failed: REFUSED`, código 2; zona inalterada | — | `escrita-nsupdate.txt` |
| E8.2: serial menor, 10 amostras de 1 a 99 s | 2026101301, 10.0.0.3 em 10 de 10 | 2026101402, 10.0.0.2 em 10 de 10 | `linha-do-tempo.csv` |
| Restauração (2026101403) | 2026101403, 10.0.0.1 | 2026101403, 10.0.0.1, em 1 s (resolução de 1 s) | `restauracao.txt`, `estado-final.txt` |

Logs da E8.2 (`logs-e8-2.txt`):

- ns1: `zone serial (2026101301/2026101402) has gone backwards`, às 21:56:33,423 UTC, no reload com serial menor. O primário avisa, mas carrega e serve a zona.
- ns2 e ns3: 17 linhas `serial number (2026101301) received from primary 172.30.0.11#53 < ours (2026101402)` e 2 linhas `notify from 172.30.0.11#…: zone is up to date`.
- Nenhuma transferência concluída em ns2 ou ns3 durante a observação.

O resolvedor devolveu `10.0.0.1` depois da restauração.

**Comparação com a previsão.** Confirmados: o coordenador estático, a propagação do serial crescente, a recusa da escrita por `nsupdate` (REFUSED no secundário e no primário com zona estática), o serial menor aceito só pelo primário, a divergência persistente por pelo menos 90 s (três ciclos de refresh, com 17 recusas `< ours` registradas ao longo da janela) e a convergência com serial maior. Não observado: o `notify-delay` com duas edições seguidas.

