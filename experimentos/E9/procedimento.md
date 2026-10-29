# Procedimento executado: E9 — Atualizações dinâmicas autenticadas e concorrência

- **Responsável:** Emanuel Müller Bueno
- **Data/hora:** 27/10/2026 (concorrência às 23:22 e 23:23; medições às 23:25; registro deste procedimento às 23:44)
- **Máquina (ver `docs/ambiente/emanuel-windows.md`):** Windows (build 26200), Git Bash; Docker 29.9.2; Compose v5.6.1; BIND 9.18.49
- **Commit/tag:** laboratório `c66fd2b` (informado na previsão); resultados commitados em `3922579`
- **Variante (`COMPOSE_FILE`):** `docker-compose.yml;docker-compose.e9.yml` — base + E9
- **Complemento e revisão:** Taryck Gean Santos Pego, 28/10/2026 (ver "Complemento: etapa 1" e "Complemento: etapas 2 e 3 com 20 mensagens por cliente" no fim deste arquivo)

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

Execução em 28/10/2026, das 20:51:32 às 20:52:32 (UTC−3), em Darwin arm64, sobre o commit `05f68f1` com as correções dos scripts aplicadas e ainda não commitadas (elas foram commitadas depois, em `51562c8`). As chaves de `secrets/` são as geradas às 18:59 com `scripts/gerar-chaves-tsig.sh`; o script as manteve.

Esta execução substitui a de 18:59:55 a 19:00:07 (commit `645475b`), que continua no histórico do Git. Naquela execução o filtro de horário de `logs.txt` descartava as linhas do mesmo segundo do início, e a linha da atualização aceita (`updating zone ... adding an RR ... "teste-valida"`) não aparecia. O script foi corrigido e o `logs.txt` novo traz essa linha (`grep -c teste-valida autorizacao/logs.txt` devolve 1). Os resultados dos quatro testes são os mesmos.

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

## Complemento: etapas 2 e 3 com 20 mensagens por cliente

- **Executor:** Taryck Gean Santos Pego
- **Data/hora:** 28/10/2026, `distintos` às 21:27 e `mesmo` às 21:28 (UTC−3); os logs do BIND estão em UTC (00:27 de 29/10)
- **Máquina:** ver `docs/ambiente/taryck-mac.md` (Darwin arm64)
- **Commit/tag:** `b1840b7` (HEAD no momento da execução; os scripts de concorrência não gravam o commit)
- **Variante:** `docker-compose.yml:docker-compose.e9.yml`

Motivo: a previsão e o roteiro pedem 20 mensagens por cliente (40 por execução), mas a execução original de 27/10 usou 5 por cliente (10 por execução), e o motivo da redução não ficou registrado. Esta execução repete as etapas 2 e 3 na escala prevista. A original continua valendo como segunda amostra.

Comandos:

```sh
export COMPOSE_FILE=docker-compose.yml:docker-compose.e9.yml
scripts/reset.sh
scripts/e9-concorrencia.sh 20 distintos
scripts/e9-concorrencia.sh 20 mesmo
unset COMPOSE_FILE
scripts/reset.sh
```

As duas execuções rodaram em sequência, sem `reset.sh` entre elas. Por isso o serial continua de uma para a outra (1441 → 1481) e o `journal.txt` da segunda traz também as 40 transações da primeira.

| Pasta | Conteúdo |
| ----- | -------- |
| `execucao-20261028-212722-distintos/` | Etapa 2: `cliente1.csv`, `cliente2.csv`, `envios.csv`, `ordem-aplicacao.txt`, `journal.txt`, `transferencias.txt`, `estado-final.txt`, `logs.txt`, `resumo.txt` |
| `execucao-20261028-212750-mesmo/` | Etapa 3: os mesmos arquivos |

### Resultado

| | Etapa 2 (nomes distintos) | Etapa 3 (mesmo nome) |
| - | ------------------------- | -------------------- |
| Mensagens aceitas (`NOERROR`) | 40 de 40 | 40 de 40 |
| Serial do ns1 | 2026101401 → 2026101441 (delta 40) | 2026101441 → 2026101481 (delta 40) |
| Linhas `adding an RR` no ns1 | 40 | 40 |
| Transações no journal | 40, seriais 1402 a 1441, consecutivos | 40 novas, seriais 1442 a 1481, consecutivas (80 no arquivo, desde o reset) |
| Transferências (IXFR / AXFR-style) | 3 / 0 (ns2: 2, ns3: 1) | 3 / 0 (ns2: 2, ns3: 1) |
| Convergência dos secundários após o fim dos envios | 5 s | 5 s |
| Estado final em ns1, ns2 e ns3 | `c1.sd.lab = "c1-020"`, `c2.sd.lab = "c2-020"`, serial 2026101441 | `ordem.sd.lab = "c2-020"`, serial 2026101481 |
| Latência por mensagem (n = 40) | média 21,8 ms, desvio 3,8 ms, mín. 20 ms, máx. 30 ms | média 21,2 ms, desvio 4,0 ms, mín. 20 ms, máx. 40 ms |
| Duração dos envios (primeiro envio à última resposta) | 450 ms | 450 ms |

Detalhes observados nos arquivos:

- **Simultaneidade.** Os dois clientes começaram no mesmo instante (`envio_ms` 9374460 nos dois, na etapa 2; 9403460 e 9403470, na etapa 3) e terminaram juntos, de modo que os intervalos de envio se sobrepõem por inteiro.
- **Ordem de aplicação.** Em `ordem-aplicacao.txt`, cada cliente aparece em ordem crescente (c1-001 a c1-020 e c2-001 a c2-020), nas duas etapas. Os clientes aparecem intercalados sem padrão fixo (etapa 2: `1212211212121212122121212121122121121221`, em que 1 é o cliente1 e 2 é o cliente2). Comparando a ordem de aplicação com a ordem de `envio_ms`, 9 de 780 pares (etapa 2) e 7 de 780 pares (etapa 3) ficaram invertidos. O `envio_ms` tem resolução de 10 ms, então mensagens com o mesmo valor não têm ordem definida entre si.
- **Journal.** Cada transação traz a troca do SOA (serial antigo → novo) junto com a troca do TXT. Na etapa 3, o arquivo tem 40 linhas `add ordem.sd.lab`, ou seja, todas as versões intermediárias. As linhas `add c1.sd.lab` e `add c2.sd.lab` (20 de cada) desse arquivo vêm da etapa 2.
- **Transferências.** Etapa 2: o ns2 transferiu 1401 → 1402 às 00:27:25,028 (1 passo, logo após o primeiro UPDATE) e 1402 → 1441 às 00:27:30,028 (39 passos, 5,0 s depois, coerente com o `notify-delay` de 5 s); o ns3 transferiu 1401 → 1441 de uma vez às 00:27:25,531 (160 registros, 4474 bytes), ~0,5 s depois do ns2, como no E3 (escalonamento de NOTIFY). Na etapa 3 o padrão se repetiu (ns2 às 00:27:54,032 e 00:27:59,032; ns3 às 00:27:54,532).
- **Valor final na etapa 3.** As duas últimas mensagens (c1-020 e c2-020) foram enviadas no mesmo instante (`envio_ms` 9403890) e a c2-020 foi aplicada por último. Os outros 39 valores gravados em `ordem.sd.lab` foram sobrescritos sem aviso a nenhum cliente, inclusive o c1-020. Na execução original (5 mensagens por cliente) o valor final foi `c1-005`, então o vencedor variou entre as execuções.

### Comparação com a previsão (etapas 2 e 3)

| Item previsto | Observado | Resultado |
| ------------- | --------- | --------- |
| Etapa 2.1: 40 de 40 aceitas | 40 de 40 | **Confirmado** |
| Etapa 2.2: delta de serial 40 | 40 (1401 → 1441) | **Confirmado** |
| Etapa 2.3: journal com seriais consecutivos, sem repetição e sem lacuna | 1402 a 1441, sem lacuna nem repetição | **Confirmado** |
| Etapa 2.4: 40 `adding an RR`; ordem de cada cliente preservada; clientes intercalados | 40; crescente nos dois clientes; intercalados | **Confirmado** |
| Etapa 2.5: estado final idêntico (`c1-020`, `c2-020`) | Idêntico nos três, serial 2026101441 | **Confirmado** |
| Etapa 2.6: 1 a 3 transferências por secundário, todas IXFR, nenhuma AXFR | ns2: 2, ns3: 1; todas IXFR; 0 AXFR-style | **Confirmado** |
| Etapa 3.1: 40 de 40 aceitas, sem erro de conflito | 40 de 40 `NOERROR` | **Confirmado** |
| Etapa 3.2: delta 40 e journal consecutivo | 40 (1441 → 1481); 1442 a 1481 consecutivos | **Confirmado** |
| Etapa 3.3: valor final é o da última mensagem aplicada (`c1-020` ou `c2-020`), idêntico nos três; os demais se perdem | `c2-020`, idêntico nos três; 39 valores sobrescritos | **Confirmado** (*lost update*) |
| Etapa 3.4: 40 `adding an RR`; journal com as 40 versões intermediárias | 40 linhas `adding an RR`; 40 `add ordem.sd.lab` no journal | **Confirmado** |
| Latência de cada UPDATE: dezenas de ms | média de 21,2 a 21,8 ms | **Confirmado** |
| Convergência dos secundários após a rajada: 0 a ≈ 6 s | 5 s | **Confirmado** |
| Duração dos envios: poucos segundos | 450 ms | **Divergente** (mais rápido que o previsto: 20 mensagens × ~22 ms ≈ 440 ms) |

### Etapa 4 (execução original de 27/10, 5 repetições)

A etapa 4 não foi repetida. Os números da execução original (`medicoes-20261027-232512.csv`) frente à previsão:

| Item previsto | Observado | Resultado |
| ------------- | --------- | --------- |
| Confirmação de cada UPDATE em dezenas de ms (10 a 100 ms) | média 32 ms, desvio 11,0 ms (20 a 50 ms) | **Confirmado** |
| Propagação ns1 → ns2 e ns3 em menos de 1 s, "na casa de 100 a 500 ms" | ns2: média 44 ms; ns3: média 622 ms (600 a 640 ms) | **Confirmado** o limite de 1 s; a faixa estimada não: o ns2 ficou abaixo e o ns3 acima |
| Nenhuma repetição estoura o timeout de 60 s | `NA = 0` | **Confirmado** |

A diferença de ~0,5 s entre ns2 e ns3 vem do escalonamento de NOTIFY descrito no E3 (o ns2 é avisado na hora e o ns3 ~500 ms depois). Ela também aparece nas duas execuções de 20 mensagens (ns2 às 00:27:25,028 e ns3 às 00:27:25,531, na etapa 2).

### Conclusão das etapas 2 e 3

O primário serializou as 80 mensagens dos dois clientes concorrentes em uma ordem total, registrada no serial e no journal, sem lacuna e sem repetição. Todas foram aceitas, inclusive as que sobrescreveram o mesmo nome: o DNS não detecta escritas concorrentes, e o valor final é o da última mensagem aplicada, que não é necessariamente a do último cliente a enviar. Os secundários receberam tudo por IXFR, em 1 ou 2 transferências cada, com várias mensagens por transferência.

### Limitações

- Uma execução de 20 mensagens por modo, mais a original de 5 por modo. As duas rodaram em máquinas diferentes (Windows e Mac).
- A resolução do relógio de envio é de 10 ms.
- O vencedor da etapa 3 depende da ordem de chegada ao primário; duas execuções não bastam para estimar com que frequência cada cliente vence.
