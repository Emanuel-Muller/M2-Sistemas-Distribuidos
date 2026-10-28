# Procedimento executado: E8 — Coordenação e ordem

- **Responsável:** Emanuel Müller Bueno
- **Data/hora:** 27/10/2026 23:44
- **Máquina (ver `docs/ambiente/emanuel-windows.md`):**
- **Commit/tag 3922579

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
| `coordenacao.txt` | Consultas iniciais utilizadas para demonstrar a coordenação e a versão inicial da zona. |
| `resultados.txt` | Registros das etapas E8.1, E8.2 e da restauração, incluindo a saída da consulta ao resolvedor e a anotação sobre a falha inicial. |
| `estado-final.txt` | Estado final dos três servidores e do resolvedor, todos com `app.sd.lab = 10.0.0.1` e serial SOA `2026101403`. |
| `zona-antes-e8.db.sd.lab` | Cópia da zona de trabalho anterior às alterações do experimento. |

## Observações durante a execução

- A primeira tentativa de alterar o serial falhou devido à interpretação incorreta de `$1` na string de substituição da função PowerShell. O arquivo permaneceu com o serial `2026101401`, embora o registro `app.sd.lab` tenha sido alterado para `10.0.0.2`.
- A função de alteração foi corrigida para utilizar um `MatchEvaluator`, permitindo substituir o serial e o registro A corretamente.
- Após a correção, o primário passou a servir o serial `2026101402`, e a atualização foi propagada aos dois secundários.
- No teste de serial menor, o primário serviu `2026101301`, enquanto os secundários mantiveram `2026101402`. Isso demonstra que os secundários não aceitaram a versão de serial inferior como uma atualização mais recente.
- Para restaurar a consistência, foi utilizado o serial `2026101403`, superior ao serial conservado pelos secundários.
- Ao final, os três servidores autoritativos e o resolvedor retornaram `10.0.0.1` para `app.sd.lab`.
- A execução original foi realizada manualmente pelo PowerShell. A limitação de Bash/WSL referia-se àquele ambiente e momento; não implica que os scripts não possam ser executados em outro ambiente.
- O commit correspondente à execução original do E8 precisa ser confirmado no histórico do Git.

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

