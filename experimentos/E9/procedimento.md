# Procedimento executado: E9 — Atualizações dinâmicas autenticadas e concorrência

- **Responsável:** Emanuel Müller Bueno
- **Data/hora:** 27/10/2026 (concorrência às 23:22 e 23:23; medições às 23:25; registro deste procedimento às 23:44)
- **Máquina (ver `docs/ambiente/emanuel-windows.md`):** Windows (build 26200), Git Bash; Docker 29.9.2; Compose v5.6.1; BIND 9.18.49
- **Commit/tag:** laboratório `c66fd2b` (informado na previsão); resultados commitados em `3922579`
- **Variante (`COMPOSE_FILE`):** `docker-compose.yml;docker-compose.e9.yml` — base + E9
- **Complemento e revisão:** Taryck Gean Santos Pego, 28/10/2026 (ver "Complemento: etapa 1" no fim deste arquivo)

## Condição inicial

O ambiente Docker Compose foi validado com `docker compose config --quiet`. Os contêineres foram reinicializados com a configuração E9 utilizando o script de restauração, e os três servidores DNS apresentaram o serial inicial `2026101401`.

Foram configuradas chaves TSIG para os clientes, incluindo uma chave inválida para testar a rejeição de atualizações não autorizadas.

Antes dos experimentos concorrentes, foi realizada uma atualização dinâmica autenticada com sucesso. As consultas confirmaram a propagação do registro para os três servidores.

## Passos e comandos

1. **Validar a configuração do Docker Compose:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'docker compose config --quiet'
   ```

2. **Preparar o ambiente E9:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/reset.sh'
   ```

   O script foi executado antes dos testes para restaurar a zona de trabalho. Os três servidores convergiram para o serial inicial `2026101401`.

3. **Testar atualização dinâmica autenticada com uma chave válida:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-atualizar.sh cliente cliente1 172.31.0.11 ordem.sd.lab teste-e9-1'
   ```

   Resultado: atualização aceita, com serial alterado de `2026101401` para `2026101402`. O registro TXT foi consultado nos três servidores e retornou `"teste-e9-1"`.

4. **Testar atualização sem chave de autenticação:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-atualizar.sh cliente nenhuma 172.31.0.11 ordem.sd.lab teste-sem-chave'
   ```

   Resultado: atualização rejeitada com `REFUSED`. O serial e o valor anterior do registro foram preservados.

5. **Testar atualização com chave TSIG inválida:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-atualizar.sh cliente invalida 172.31.0.11 ordem.sd.lab teste-chave-invalida'
   ```

   Resultado: atualização rejeitada com `NOTAUTH(BADSIG)`. O serial permaneceu em `2026101402` e o valor anterior do registro não foi alterado.

6. **Executar o experimento concorrente com registros distintos:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-concorrencia.sh 5 distintos'
   ```

   Resultado: 10 atualizações aceitas de 10 tentativas, com incremento do serial de `2026101402` para `2026101412`. Os três servidores convergiram para o mesmo estado. Foram observadas três transferências IXFR e nenhuma transferência AXFR-style.

7. **Executar o experimento concorrente com atualizações para o mesmo registro:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-concorrencia.sh 5 mesmo'
   ```

   Resultado: 10 atualizações aceitas de 10 tentativas, com incremento do serial de `2026101412` para `2026101422`. Os três servidores convergiram para o valor final `"c1-005"` no registro `ordem.sd.lab`. Foram observadas três transferências IXFR e nenhuma transferência AXFR-style.

8. **Medir os tempos de confirmação e propagação:**

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/e9-medir.sh 5'
   ```

   Foram realizadas cinco repetições, sem valores ausentes (`NA=0`).

   | Métrica | Média | Desvio-padrão | Mínimo | Máximo |
   | ------- | -----: | ------------: | -----: | -----: |
   | Confirmação da atualização | 32 ms | 11,0 ms | 20 ms | 50 ms |
   | Propagação para ns2 | 44 ms | 11,4 ms | 30 ms | 60 ms |
   | Propagação para ns3 | 622 ms | 14,8 ms | 600 ms | 640 ms |

9. **Registrar as evidências no Git:**

   ```powershell
   git add experimentos/E9/execucao-20261027-232237-distintos/ experimentos/E9/execucao-20261027-232327-mesmo/ experimentos/E9/medicoes-20261027-232512.csv
   git diff --cached --stat
   git commit -m "E9 Resultados"
   ```

   Commit criado: `3922579` (`E9 Resultados`).

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
| ------- | ------------ |
| `execucao-20261027-232237-distintos/cliente1.csv` | Resultados e tempos registrados pelo cliente 1 no experimento com registros distintos |
| `execucao-20261027-232237-distintos/cliente2.csv` | Resultados e tempos registrados pelo cliente 2 no experimento com registros distintos |
| `execucao-20261027-232237-distintos/envios.csv` | Registro dos envios realizados pelos clientes |
| `execucao-20261027-232237-distintos/estado-final.txt` | Estado final e serial dos servidores DNS |
| `execucao-20261027-232237-distintos/journal.txt` | Evidências do journal da zona durante a execução |
| `execucao-20261027-232237-distintos/logs.txt` | Logs do servidor durante o experimento |
| `execucao-20261027-232237-distintos/ordem-aplicacao.txt` | Ordem observada de aplicação das atualizações |
| `execucao-20261027-232237-distintos/resumo.txt` | Resumo dos resultados do experimento |
| `execucao-20261027-232237-distintos/transferencias.txt` | Evidências das transferências de zona |
| `execucao-20261027-232327-mesmo/cliente1.csv` | Resultados e tempos registrados pelo cliente 1 no experimento com o mesmo registro |
| `execucao-20261027-232327-mesmo/cliente2.csv` | Resultados e tempos registrados pelo cliente 2 no experimento com o mesmo registro |
| `execucao-20261027-232327-mesmo/envios.csv` | Registro dos envios realizados pelos clientes |
| `execucao-20261027-232327-mesmo/estado-final.txt` | Estado final e serial dos servidores DNS |
| `execucao-20261027-232327-mesmo/journal.txt` | Evidências do journal da zona durante a execução |
| `execucao-20261027-232327-mesmo/logs.txt` | Logs do servidor durante o experimento |
| `execucao-20261027-232327-mesmo/ordem-aplicacao.txt` | Ordem observada de aplicação das atualizações |
| `execucao-20261027-232327-mesmo/resumo.txt` | Resumo dos resultados do experimento |
| `execucao-20261027-232327-mesmo/transferencias.txt` | Evidências das transferências de zona |
| `medicoes-20261027-232512.csv` | Cinco repetições de medição de confirmação e propagação |

## Observações durante a execução

- A atualização autenticada com chave válida foi aceita e propagada para os três servidores DNS.
- As tentativas sem chave e com chave inválida foram rejeitadas, sem alteração do registro existente.
- Nos dois experimentos concorrentes, todas as 10 atualizações foram aceitas. O serial aumentou em 10 unidades em cada execução.
- No experimento com registros distintos, os valores finais de ambos os registros foram consistentes entre ns1, ns2 e ns3.
- No experimento com o mesmo registro, os servidores convergiram para o mesmo valor final. Esse valor representa o resultado observado naquela execução, não uma garantia de que o mesmo cliente sempre prevalecerá.
- Nas execuções concorrentes, foram observadas transferências IXFR, sem transferências AXFR-style registradas.
- Nas cinco medições, a propagação para ns3 foi consideravelmente mais lenta que para ns2. As médias observadas foram de 622 ms e 44 ms, respectivamente.
- As evidências dos experimentos concorrentes e das medições foram registradas no commit `3922579`.
- Horários exatos de preparação do ambiente e dos testes de autenticação: não registrados na execução original. Os testes de autorização foram repetidos com script e registro de horários (ver "Complemento: etapa 1").
- O teste de chave válida enviada ao secundário (item 4 da previsão) não foi feito na execução original; está no complemento.

## Restauração

O comando utilizado para restaurar a zona antes dos experimentos foi:

```powershell
& "C:\Program Files\Git\bin\bash.exe" -c 'export MSYS_NO_PATHCONV=1; ./scripts/reset.sh'
```

**Observação:** esse comando foi executado na preparação do ambiente, antes dos testes. Uma restauração posterior aos experimentos não foi registrada na execução original. No complemento, o script termina restaurando a variante base (`unset COMPOSE_FILE` + `scripts/reset.sh`), com a saída em `autorizacao/restauracao.txt`.

## Complemento: etapa 1 (autorização)

- **Executor:** Taryck Gean Santos Pego
- **Data:** 28/10/2026
- **Máquina:** ver `docs/ambiente/taryck-mac.md`
- **Commit e horários:** registrados em `autorizacao/contexto.txt` e `autorizacao/execucao.txt`
- **Variante:** `docker-compose.yml:docker-compose.e9.yml`

Motivo: a execução original registrou os testes de autorização só no texto deste procedimento, sem arquivo de evidência, e não testou o envio ao secundário.

Comandos:

```sh
scripts/gerar-chaves-tsig.sh
export COMPOSE_FILE=docker-compose.yml:docker-compose.e9.yml
scripts/e9-autorizacao.sh
unset COMPOSE_FILE
```

O script faz `scripts/reset.sh` na variante e9 e envia quatro UPDATEs com `scripts/e9-atualizar.sh`: chave `cliente1` ao ns1; sem chave ao ns1; chave inválida (nome `cliente1`, segredo diferente) ao ns1; chave `cliente1` ao ns2. Depois registra a propagação da escrita aceita, o journal e os logs, e restaura a variante base.

| Arquivo (`autorizacao/`) | O que mostra |
| ------- | ------------ |
| `contexto.txt`, `execucao.txt` | Data, hora, máquina, commit, variante e horário de cada teste |
| `1-valida.txt` a `4-secundario.txt` | Saída do `nsupdate`, código de saída, serial do ns1 antes e depois e valor de `ordem.sd.lab` |
| `propagacao.txt` | Serial e `ordem.sd.lab` em ns1, ns2 e ns3 após a escrita aceita |
| `journal.txt` | `named-journalprint` do ns1 (transações aplicadas) |
| `logs.txt`, `logs-relevantes.txt` | Logs do BIND: `update ... denied`, `tsig verify failure`, transferências |
| `restauracao.txt` | Saída do `scripts/reset.sh` na variante base |
| `resumo.txt` | Uma linha por teste (código, serial, mensagem do servidor) |

### Resultado do complemento

Execução em 28/10/2026, das 18:59:55 às 19:00:07 (UTC−3), em Darwin arm64, sobre o commit `645475b` com os scripts do complemento aplicados e ainda não commitados; chaves geradas às 18:59 com `scripts/gerar-chaves-tsig.sh`.

| Teste | Resposta | Código | Serial do ns1 |
| ----- | -------- | ------ | ------------- |
| Chave `cliente1`, ao ns1 | aceita | 0 | 2026101401 → 2026101402 |
| Sem chave, ao ns1 | `update failed: REFUSED` | 2 | 2026101402 → 2026101402 |
| Chave inválida (nome `cliente1`, segredo diferente), ao ns1 | `update failed: NOTAUTH(BADSIG)` | 2 | 2026101402 → 2026101402 |
| Chave `cliente1`, ao ns2 (secundário) | `update failed: REFUSED(BADKEY)` | 2 | 2026101402 → 2026101402 |

- A escrita aceita (`ordem.sd.lab` TXT "teste-valida") foi servida por ns1, ns2 e ns3 com o serial 2026101402 (`propagacao.txt`), e o journal registra uma transação (`journal.txt`).
- As três tentativas recusadas não alteraram o serial nem o valor.
- No ns2, a recusa veio da verificação TSIG (`BADKEY`): o secundário não tem as chaves dos clientes nem permissão de escrita.
- Ao final, o script restaurou a variante base (serial 2026101401 nos três; `restauracao.txt`).

**Comparação com a previsão.** Confirmados os quatro itens da etapa 1: aceitação com serial +1 e propagação aos secundários, REFUSED sem chave, NOTAUTH (BADSIG) com chave inválida e recusa no secundário (a previsão admitia REFUSED ou NOTAUTH; ocorreu REFUSED com erro TSIG BADKEY).

