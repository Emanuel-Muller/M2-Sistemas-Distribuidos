# T1 DNS — Ênfase B (Sistemas Distribuídos, Trabalho 2)

Laboratório DNS distribuído com BIND 9 em contêineres Alpine (Docker Compose):
primário `ns1`, secundários `ns2` e `ns3`, resolvedor com cache e dois clientes.
Zona `sd.lab`. Ênfase B: atualização dinâmica (RFC 2136) com TSIG e ordem das escritas.

## Topologia

| Contêiner | Papel | Rede interna (172.30.0.0/24) | Rede clientes (172.31.0.0/24) | Portas |
|---|---|---|---|---|
| ns1 | Primário autoritativo | 172.30.0.11 | 172.31.0.11 | 53/udp, 53/tcp, 953 (rndc, local) |
| ns2 | Secundário autoritativo | 172.30.0.12 | 172.31.0.12 | 53/udp, 53/tcp, 953 (rndc, local) |
| ns3 | Secundário autoritativo | 172.30.0.13 | 172.31.0.13 | 53/udp, 53/tcp, 953 (rndc, local) |
| resolvedor | Recursivo com cache | — | 172.31.0.53 | 53/udp, 53/tcp, 953 (rndc, local) |
| cliente | dig / nsupdate | — | 172.31.0.100 | — |
| cliente2 | Segundo cliente (E9) | — | 172.31.0.101 | — |

Nenhuma porta é publicada no computador: todas as consultas partem de dentro do `cliente`.
Limites de memória: 128 MB por servidor BIND, 32 MB por cliente.

## Pré-requisitos

- Docker com Compose v2 (`docker compose version`) e Git.
- Windows: Docker Desktop com WSL 2; clonar e rodar **dentro do terminal do WSL** (pasta `~`, não `C:\`).
- macOS: Docker Desktop ou Colima. Linux: Docker Engine + plugin Compose.
- Todos os comandos abaixo são executados **na raiz do repositório**, num terminal Linux/macOS/WSL.

## Subir do zero

```sh
git clone <url-do-repositorio> sd-dns-t1
cd sd-dns-t1
docker compose build          # constrói a imagem sd-bind (Alpine 3.20 + BIND)
scripts/reset.sh              # cria a zona de trabalho, sobe tudo e espera convergir
scripts/verificar.sh          # deve terminar com "RESULTADO: APROVADO"
```

## Encerrar

```sh
docker compose stop           # pausa mantendo o estado
docker compose down           # remove os contêineres
```

## Scripts

| Script | Para quê |
|---|---|
| `scripts/reset.sh` | Volta ao estado-base (salva os logs antes) |
| `scripts/verificar.sh` | Teste de prontidão (OK/FALHA por item) |
| `scripts/ficha-ambiente.sh <pessoaN>` | Registra sistema, versões e commit em `docs/ambiente/` |
| `scripts/salvar-logs.sh <pasta> [rotulo]` | Salva os logs de todos os contêineres |
| `scripts/zona.sh set\|del\|serial\|ver` | Edita a zona estática do ns1, incrementa o serial e recarrega |
| `scripts/observar.sh <nome> <int> <dur> <csv>` | Linha do tempo de ns1, ns2, ns3 e resolvedor |
| `scripts/medir-propagacao.sh <rotulo> [n]` | E3: tempo primário → secundários |
| `scripts/medir-consistencia.sh [repeticoes] [atraso_antes_s] [fase]` | E4: cache, TTL e janela de inconsistência (fase: `ambas`, `positivo` ou `negativo`) |
| `scripts/medir-recuperacao.sh [n] [espera_s]` | E7: tempo de recuperação do ns3 após partição |
| `scripts/e5-falha.sh [int] [limite] [extras]` | E5: quadro nós ativos x leitura x escrita; ns3 até o expire |
| `scripts/e6-particao.sh [int] [limite] [--manter-isolado]` | E6: ns3 isolado da rede interna, divergência e expire |
| `scripts/e8-complemento.sh [dur] [int]` | E8: papéis, serial crescente, `nsupdate` no secundário, serial menor observado por `dur` s e restauração |
| `scripts/estatisticas.sh <csv> <coluna>` | Média e desvio padrão de uma coluna |
| `scripts/gerar-chaves-tsig.sh` | E9: chaves TSIG em `secrets/` (fora do Git) |
| `scripts/e9-atualizar.sh ...` | E9: uma atualização dinâmica (validação e testes de autorização) |
| `scripts/e9-concorrencia.sh [n] [mesmo\|distintos]` | E9: atualizações concorrentes dos dois clientes |
| `scripts/e9-medir.sh [n]` | E9: tempo de confirmação e de propagação de um UPDATE |
| `scripts/e9-autorizacao.sh [--sem-restaurar]` | E9: testes de autorização (chave válida, sem chave, chave inválida, envio ao secundário) |

## Variantes

| Variante | Ativar | Voltar à base |
|---|---|---|
| Sem NOTIFY (E3, 2ª série) | `export COMPOSE_FILE=docker-compose.yml:docker-compose.sem-notify.yml` e `docker compose up -d ns1` | `unset COMPOSE_FILE` e `docker compose up -d ns1` |
| Atualização dinâmica (E9) | `scripts/gerar-chaves-tsig.sh`, `export COMPOSE_FILE=docker-compose.yml:docker-compose.e9.yml` e `scripts/reset.sh` | `unset COMPOSE_FILE` e `scripts/reset.sh` |

`COMPOSE_FILE` vale só para o terminal onde foi definido.

## Adaptações em relação ao roteiro

O roteiro permite adaptar as configurações (p.11). Diferenças em relação aos trechos das p.12–16:

| # | O que mudou | Motivo |
|---|---|---|
| A1 | Dockerfile gera `/etc/bind/rndc.key` se ela não existir | Garantir `rndc reload`, `querylog` e `flush` usados nos experimentos |
| A2 | `name: sdlab` no compose | Nomes de rede iguais em todas as máquinas (`sdlab_interna`, `sdlab_clientes`), usados no E6 |
| A3 | O ns1 lê a zona de `runtime/ns1` (cópia de trabalho da zona-base) | Edições dos experimentos e o journal do E9 não alteram o arquivo versionado; reset em um comando |
| A4 | Serviço `cliente2` (172.31.0.101) | O E9 exige dois clientes |
| A5 | Clientes também com `build: .` | O Compose não tenta baixar a imagem `sd-bind` da internet |
| A6 | Variante sem NOTIFY por arquivo de sobreposição | Segunda série do E3 sem editar a configuração-base |
| A7 | Variante E9 por arquivo de sobreposição, uma chave TSIG por cliente e `update-policy` | Base estática intacta para E1–E8; origem de cada UPDATE identificável nos logs |
| A8 | `max-ixfr-ratio unlimited;` na zona da variante E9 | Zona pequena: sem isso o BIND troca IXFR por transferência completa |
| A9 | Scripts de medição próprios | Medem ns2 e ns3, com valor e serial novos a cada repetição e relógio comum aos contêineres |

Contingência: se `verificar.sh` reprovar a escrita do usuário `named` em `/var/lib/bind`, trocar a montagem `./runtime/ns1` por um volume nomeado.

Comportamentos do BIND que afetam os procedimentos:

- Com `named -g`, o bloco `logging` do `named.conf` é ignorado; tudo vai para `docker logs`.
- O BIND adia NOTIFY de mudanças muito próximas (`notify-delay`, 5 s); os scripts esperam 6 s entre repetições.
- Linhas `refused notify from non-primary: 172.31.0.x` nos logs são esperadas (NOTIFY entre secundários pela rede de clientes).
- Zona dinâmica não aceita `rndc reload`; edição manual só com `rndc freeze sd.lab` / `rndc thaw sd.lab`. Nunca editar o `.jnl`.

## Estado do laboratório

| Operação | Comando | Efeito |
|---|---|---|
| Parar | `docker compose stop` / `docker compose start` | Mantém tudo, inclusive a zona dos secundários |
| Remover contêineres | `docker compose down` | Secundários perdem a cópia da zona |
| Restaurar a base | `scripts/reset.sh` | Salva os logs em `logs/`, remove tudo e volta ao estado inicial |

Chaves TSIG ficam em `secrets/` (fora do Git), geradas em cada máquina por `scripts/gerar-chaves-tsig.sh`.

## Informações da equipe (README original)

# T1: Sistema de nomes distribuído (DNS)
Ênfase B: Atualização dinâmica e ordem das escritas.
Habilitar atualização dinâmica (RFC 2136) com chave TSIG e nsupdate. Disparar atualizações concorrentes a partir de dois clientes e mostrar como o primário as serializa (journal, serial, IXFR).
