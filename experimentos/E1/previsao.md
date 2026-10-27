# Previsão: E1 (Subida e topologia)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: João Balhego
- Data/hora do registro: 27/10/2026 19:06
- Commit/tag do laboratório: 8c48e53

## O que esperamos observar

Variante base. Roteiro (seção 5.3, E1): subir o ambiente, conferir nos logs dos secundários a transferência da zona, consultar o SOA nos três autoritativos e desenhar a topologia. Como o E3 e o E4 já foram executados neste mesmo laboratório, o formato das linhas de log e a lentidão do ns2 abaixo vêm dessas execuções (`experimentos/E3/` e `experimentos/E4/logs-e4.txt`); não são previsões independentes.

1. **`scripts/reset.sh`.** Recria a zona de trabalho com serial 2026101401, sobe os 6 contêineres e termina com `Convergência: serial 2026101401 em ns1, ns2 e ns3.`
2. **`docker compose ps`.** Seis serviços em execução: `ns1`, `ns2`, `ns3`, `resolvedor`, `cliente` e `cliente2`, todos da imagem `sd-bind`. A coluna de portas vem vazia: o Dockerfile não tem `EXPOSE` e o compose não publica portas.
3. **Logs de ns2 e ns3, filtrados por `transfer`.** Cada secundário registra a transferência inicial da zona vinda de `172.30.0.11` (primário, rede interna), com 5 linhas, na ordem:
   - `zone sd.lab/IN: Transfer started.`
   - `transfer of 'sd.lab/IN' from 172.30.0.11#53: connected using 172.30.0.11#53`
   - `zone sd.lab/IN: transferred serial 2026101401`
   - `transfer of 'sd.lab/IN' from 172.30.0.11#53: Transfer status: success`
   - `transfer of 'sd.lab/IN' from 172.30.0.11#53: Transfer completed: 1 messages, 9 records, ... (serial 2026101401)`

   Total: 10 linhas (5 por secundário). Linhas de falha de refresh (`refresh: failure ... connection refused`), se aparecerem, não contêm "transfer" e não entram no filtro.
4. **SOA nos três autoritativos.** Três linhas idênticas: `ns1.sd.lab. admin.sd.lab. 2026101401 30 10 300 20`. O serial é o mesmo em ns1, ns2 e ns3.
5. **Redes e endereços (para o diagrama).**

| Contêiner | Papel | Rede interna 172.30.0.0/24 | Rede clientes 172.31.0.0/24 |
|---|---|---|---|
| ns1 | Primário | 172.30.0.11 | 172.31.0.11 |
| ns2 | Secundário | 172.30.0.12 | 172.31.0.12 |
| ns3 | Secundário | 172.30.0.13 | 172.31.0.13 |
| resolvedor | Recursivo com cache | não conectado | 172.31.0.53 |
| cliente | dig / nsupdate | não conectado | 172.31.0.100 |
| cliente2 | Segundo cliente (E9) | não conectado | 172.31.0.101 |

As redes se chamam `sdlab_interna` e `sdlab_clientes` (projeto `sdlab`).

## Por quê

**Transferência inicial.** Um secundário sem cópia da zona busca a zona inteira no primário. Não existe versão anterior, então a transferência é completa (AXFR, e não IXFR). Pelos arquivos do kit, o ns1 só permite transferência para 172.30.0.12 e 172.30.0.13 (`allow-transfer`) e os secundários apontam para `172.30.0.11` (`primaries`), então o tráfego passa pela rede interna. A zona-base tem 9 registros na transferência: SOA, 3 NS, 4 A (ns1, ns2, ns3 e app) e o SOA final que fecha a AXFR.

**Serial igual.** A AXFR copia o SOA do primário junto com os dados. Depois da convergência, os três autoritativos têm o mesmo serial da zona-base (2026101401).

**Sem portas publicadas.** O README declara que nenhuma porta é publicada e que todas as consultas partem de dentro do `cliente`.

## Números esperados (se houver medição)

- **Contagem:** 6 contêineres, 10 linhas no filtro `transfer` (5 por secundário), 3 linhas de SOA iguais, 9 registros em cada transferência.
- **Tempo até a convergência no reset:** o ns3 em ~1 s. O ns2 em algo entre ~1 s e ~60 s. **Esse intervalo largo vem de uma única observação:** na execução do E4 (`logs-e4.txt`, reset às 16:31:58), o ns3 transferiu a zona em ~1 s (16:31:59,776), enquanto o ns2 registrou `refresh: failure ... connection refused` às 16:31:59 e só transferiu às 16:32:57 (~58 s). A causa não foi determinada.
- **Risco:** o `reset.sh` espera no máximo 60 s pela convergência. Se o ns2 repetir os ~58 s, a execução fica perto desse limite e pode imprimir `AVISO: sem convergência em 60s`. Nesse caso o SOA do ns2 pode sair vazio na primeira consulta.

## O que invalidaria a previsão

- SOA com seriais diferentes entre ns1, ns2 e ns3 depois do reset.
- Menos de 6 contêineres em execução no `docker compose ps`, ou portas publicadas.
- A transferência inicial nos logs vir de outro endereço (por exemplo 172.31.0.11, a rede de clientes), ou ser incremental em vez de completa.
- Log de ns2 ou ns3 sem nenhuma transferência bem-sucedida.
- Número de registros diferente de 9 na transferência.
