# Procedimento executado: E6 (Partição de rede)

- Responsável: Enzo Neumann
- Data/hora: 2026-10-27 14:54–15:02 (-0300); observação complementar até 15:12
- Máquina (ver docs/ambiente/<pessoa>.md): docs/ambiente/enzo-windows.md
- Commit/tag (git rev-parse --short HEAD): 0e1dfd9 (previsão no commit 662e825)
- Variante (COMPOSE_FILE): base

## Condição inicial

`scripts/reset.sh` executado às 14:54. Serial 2026101401 e `app.sd.lab = 10.0.0.1` em ns1, ns2 e ns3. Cache do resolvedor limpo pelo script.

## Passos e comandos

1. `unset COMPOSE_FILE; sh scripts/reset.sh`
2. `sh scripts/e6-particao.sh` (padrões: intervalo 5 s, limite 420 s, reconexão no fim)
   - P0 (14:54:14): `docker network disconnect sdlab_interna ns3`; isolamento conferido.
   - P1 (t = 4 s): `zona.sh set app 10.6.158.58` no ns1 (serial 2026101402).
   - Linha do tempo a cada ~6 s até o ns3 responder SERVFAIL (P2), mais duas amostras.
   - Reconexão (14:59:21): `docker network connect --ip 172.30.0.13 sdlab_interna ns3`; espera de 120 s.
3. Observação complementar (fora do script): consulta ao SOA do ns3 a cada 10 s, sem nenhuma intervenção, até ele voltar a servir a zona (máximo 15 min).

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| resumo.txt | Saída completa, com P0, P1 e P2 |
| linha-do-tempo.csv | t desde P0, fase, status/valor/serial de ns1, ns2, ns3 e valor/TTL do resolvedor |
| isolamento.txt | Redes do ns3 depois da desconexão (só `sdlab_clientes`), timeout ns3 → ns1, resposta `aa` do ns3 ao cliente |
| zonestatus-ns3-antes.txt | Último carregamento 17:54:10 GMT; `expires` 17:59:10 GMT |
| logs.txt | Logs de todos os contêineres durante a execução |
| recuperacao-natural.txt | Observação complementar: serial do ns3 a cada 10 s depois da reconexão e logs do ns3 |

## Observações durante a execução

- **Isolamento efetivo.** Depois de P0, o ns3 ficou só na `sdlab_clientes` (172.31.0.13); `dig @172.30.0.11` a partir do ns3 deu `timed out`; o cliente continuou recebendo resposta com `aa`.
- **Divergência.** A partir da primeira amostra depois de P1 (t = 5 s), ns1 e ns2 serviram `10.6.158.58`/2026101402, e o ns3 serviu `10.0.0.1`/2026101401 com `NOERROR`, até t = 293 s.
- **Expire.** Primeira amostra com SERVFAIL no ns3: t = 299 s. O log do ns3 registra `zone sd.lab/IN: expired` às 17:59:10.900, igual ao `expires` do zonestatus (último carregamento + 300 s). Antes disso, tentativas de transferência com `failed to connect: timed out` e `refresh: retry limit for primary 172.30.0.11#53 exceeded` a cada ~30 s.
- **Resolvedor (resultado não previsto).** Durante toda a partição (49 amostras, t = 5 s a 293 s), o resolvedor devolveu o valor **antigo** `10.0.0.1`, renovando o cache a cada ~60 s (TTL voltando a 59), embora ns1 e ns2 já servissem o valor novo. O resolvedor tem `forwarders { 172.31.0.11; 172.31.0.12; 172.31.0.13; };`. Só depois do SERVFAIL do ns3 (t = 299 s) ele passou a devolver `10.6.158.58`.
- **NOTIFY.** O filtro do script não encontrou linhas de NOTIFY do ns1 para 172.30.0.13 em `logs.txt` (o grep do resumo veio vazio). Não há evidência no log sobre a falha do NOTIFY para o ns3.
- **Reconexão sem recuperação em 120 s.** Depois da reconexão, o ns3 registrou `refresh: skipping zone transfer as primary 172.30.0.11#53 (source 0.0.0.0#0) is unreachable (cached)`. O script terminou com `AVISO: sem convergência em 120s`.
- **Recuperação natural (observação complementar).** O ns3 voltou a servir a zona às 18:12:07 UTC (transferência de 9 registros em 0,001 s), **12 min 46 s** depois da reconexão. As tentativas de refresh registradas foram em 17:59:24, 18:00:16, 18:01:51, 18:05:49 e 18:12:07: intervalos crescentes (~52 s, ~95 s, ~238 s, ~378 s).

## Restauração

O ns3 recuperou a zona sozinho às 18:12:07 UTC (serial 2026101402 nos três). Em seguida, `sh scripts/reset.sh` antes do E7.
