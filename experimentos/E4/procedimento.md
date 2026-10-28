# Procedimento executado: E4 (Consistência: cache, TTL e janela de inconsistência)

- Responsável: Taryck Gean (responsável principal do E4, conforme o planejamento). Executor da execução oficial: João Balhego, no próprio terminal. O Claude Code apenas escreveu o script de medição e não participou da execução.
- Data/hora: 27/10/2026, execução oficial a partir de 16:35:02 (carimbo `20261027-163502`); fase positiva 16:35–16:39 e fase negativa 16:40–16:41 (UTC-3)
- Máquina (ver docs/ambiente/joao-windows.md): WSL2 (kernel 6.18.33.2-microsoft-standard-WSL2) e BIND 9.18.49, ambos conforme os logs
- Commit/tag (git rev-parse --short HEAD): `51713c8` (script `medir-consistencia.sh`, 16:31:03), usado na execução. A previsão está no commit `e72a439` (15:36:55), anterior à execução. As evidências brutas foram commitadas depois, em `999d23f` (16:43:39).
- Variante (COMPOSE_FILE): base

## Condição inicial

- **Ordem dos comandos:** `scripts/reset.sh`, `scripts/verificar.sh` e `scripts/medir-consistencia.sh`.
- **`reset.sh`:** os logs confirmam que os contêineres foram criados às 16:31:58–16:31:59.
- **`verificar.sh`:** o executor viu `RESULTADO: APROVADO` na tela, com a saída datada de 16:32:58 e commit `51713c8`, logo após o `reset.sh` (16:31:58) e antes da execução oficial (16:35:02). **Essa saída não foi salva em `experimentos/E4/`**: a informação vem do terminal do executor, não dos arquivos da pasta. Os logs são consistentes com ela: o ns3 recebeu a zona às 16:31:59,776 e o ns2 às 16:32:57,067, ou seja, os três autoritativos convergiram um segundo antes das 16:32:58.
- **Rodada anterior:** declarado pelo executor que **não houve execução de teste antes** da oficial, e que o histórico do terminal mostra um único comando de execução do script. Isso é consistente com os arquivos: a pasta tem um único conjunto (carimbo `20261027-163502`). Porém o `scripts/reset.sh` apaga o estado do laboratório, então a ausência de rodada anterior **não é comprovável só pelos logs**.
- Estado-base: serial inicial 2026101401 (a 1ª alteração gravou o serial 2026101402) e `app.sd.lab` = 10.0.0.1 (primeira leitura da repetição 1).
- Previsão commitada antes (`e72a439`, 15:36:55). O campo "Commit/tag do laboratório" da previsão registra `3812b43`, o HEAD na hora em que ela foi escrita. O script ainda não existia, e a execução usou `51713c8`.

## Passos e comandos

1. `scripts/reset.sh` (volta ao estado-base).
2. `scripts/verificar.sh` (prontidão).
3. `scripts/medir-consistencia.sh` (argumentos padrão; pela saída: 5 repetições por fase, alteração 5 s após o início da sondagem, fase `ambas`). A saída foi salva em `saida-e4.txt`.
4. Estatísticas: `scripts/estatisticas.sh <csv> <coluna>` para `ns1_ms`, `ns2_ms`, `ns3_ms`, `janela_ms`, `ttl_antes_s` e `erro_vs_ttl_ms` de cada fase. O script de medição imprime só quatro colunas; as demais foram calculadas depois, com o mesmo `estatisticas.sh`, sobre os CSVs.

**Sobre o script.** O Claude Code escreveu o script e checou a sintaxe com `sh -n` (nos dois arquivos, `scripts/medir-consistencia.sh` e `scripts/conteiner/janela.sh`). **A execução foi feita por João Balhego no próprio terminal, sem o Claude Code.** Não houve execução de teste antes da oficial (declarado pelo executor), então a lógica de `awk` e de `set --` só foi exercitada nesta execução.

**Cada repetição, fase positiva** (`app.sd.lab`, TTL 60 s):
1. `preparar_cache` consulta o resolvedor e exige TTL ≥ 50. Nas 5 repetições o TTL já era 60 e não houve espera. **Nenhum `rndc flush` é usado pelo script, e os logs têm 0 ocorrências de "flush".**
2. A sondagem (`janela.sh`, dentro do `cliente`) consulta o resolvedor e ns1, ns2 e ns3 (`@IP` explícito, `+norecurse` nos autoritativos) a cada ~0,14 s.
3. ~5 s depois da 1ª leitura, `zona.sh set app <valor> --sem-reload` sobe o serial; o t0 é marcado dentro do ns1 e segue `rndc reload sd.lab`.
4. A sondagem termina na 1ª leitura em que o resolvedor devolve o valor novo.

**Cada repetição, fase negativa:** o mesmo, com um nome inexistente (`novo.sd.lab`, depois `novo2` a `novo5`), criação ~3 s após a 1ª leitura (NXDOMAIN) e sem preparar o cache.

## Evidências geradas (arquivos nesta pasta)

| Arquivo | O que mostra |
|---|---|
| `previsao.md` | Previsão (commit e72a439), não alterada |
| `positivo-20261027-163502.csv` | 5 repetições da fase positiva (ns1, ns2, ns3, janela, TTL antes, leituras divergentes, erro vs TTL) |
| `negativo-20261027-163502.csv` | 5 repetições da fase negativa |
| `linha-positivo-1..5-20261027-163502.csv` | Linha do tempo bruta (resolvedor e autoritativos a cada ~0,14 s) |
| `linha-negativo-1..5-20261027-163502.csv` | Idem, fase negativa |
| `saida-e4.txt` | Saída do script, com média e desvio |
| `logs-e4.txt` | Logs de ns1, ns2, ns3 e resolvedor, de 16:31:58 a 16:41:22 |

## Observações durante a execução

- Os logs mostram 44 linhas `refused notify from non-primary`. É esperado (secundários se notificam pela rede de clientes, como no E3).
- Todas as transferências das repetições nos logs foram "IXFR version not in journal, falling back to AXFR": a zona é estática e não tem journal.
- Na partida (reset), o ns2 registrou `refresh: failure ... connection refused` às 16:31:59 (o ns1 ainda não estava no ar) e só obteve a zona às 16:32:57, cerca de 58 s depois; o ns3 a obteve às 16:31:59. Não investiguei a causa. É anterior à medição (16:35:02).
- O `resolvedor` **não tem nenhuma linha de log depois da inicialização** (log de consultas desligado). Nenhuma atividade do cache aparece nos logs.
- A zona acabou com serial 2026101411: 5 alterações de `app` e 5 criações de `novo*`. Para outro experimento é preciso `scripts/reset.sh`.

## Restauração

`scripts/reset.sh` (volta ao estado-base). Antes de rodar o E4 de novo, ele também é necessário, porque os nomes `novo*` já existem na zona.

---

# Análise: previsão x resultado

## Dados e conta

Fonte: colunas dos CSVs de cada fase, tempos em ms. O `estatisticas.sh` usa desvio amostral (n−1). Nada foi arredondado, exceto onde indicado.

| Fase | Coluna | Valores (ms) | Média | Desvio | Min–Max |
|---|---|---|---|---|---|
| Positiva | ns1 | 130, 40, 120, 90, 130 | 102,0 | 38,3 | 40–130 |
| Positiva | ns2 | 130, 40, 120, 510, 130 | 186,0 | 185,0 | 40–510 |
| Positiva | ns3 | 540, 480, 550, 510, 550 | 526,0 | 30,5 | 480–550 |
| Positiva | janela | 52550, 52580, 52690, 52670, 52590 | 52616,0 | 60,7 | 52550–52690 |
| Positiva | erro vs TTL | −2450, −2420, −2310, −2330, −2410 | −2384,0 | 60,7 | −2450 a −2310 |
| Negativa | ns1 e ns2 | 110, 40, 40, 10, 120 (iguais nas duas) | 64,0 | 48,3 | 10–120 |
| Negativa | ns3 | 510, 470, 470, 590, 540 | 516,0 | 50,8 | 470–590 |
| Negativa | janela | 16640, 16750, 16740, 16840, 16800 | 16754,0 | 75,4 | 16640–16840 |
| Negativa | erro vs TTL | −360, −250, −260, −160, −200 | −246,0 | 75,4 | −360 a −160 |

`ttl_antes_s` foi 55 nas 5 repetições positivas e 17 nas 5 negativas (média 55,0 e 17,0, desvio 0,0). As "leituras divergentes" foram 363, 362, 363, 363 e 357 (positiva) e 111, 113, 114, 113 e 113 (negativa).

Conferência manual (janela positiva): soma = 52550 + 52580 + 52690 + 52670 + 52590 = 263080; média = 263080/5 = 52616; desvios (−66, −36, 74, 54, −26); quadrados 4356, 1296, 5476, 2916, 676, soma 14720; 14720/4 = 3680; √3680 ≈ 60,66, mostrado como 60,7. O `erro vs TTL` é a janela menos 55000 em todas as repetições, então tem o mesmo desvio.
Janela negativa: soma 83770, média 16754; desvios (−114, −4, −14, 86, 46); quadrados 12996, 16, 196, 7396, 2116, soma 22720; 22720/4 = 5680; √5680 ≈ 75,37, mostrado como 75,4.
ns2 positivo: soma 930, média 186; desvios (−56, −146, −66, 324, −56); quadrados 3136, 21316, 4356, 104976, 3136, soma 136920; 136920/4 = 34230; √34230 ≈ 185,0. Sem a repetição 4 (cálculo feito à mão, não pelo script): média 105,0 e desvio ≈ 43,6.

## Fase positiva (app.sd.lab, TTL 60 s)

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| TTL da 1ª resposta | 60 | 60 nas 5 repetições (1ª leitura ~5,0 s antes de t0) | **Acertou** |
| TTL decrescendo | 60 − N, ±1 s | Cai 1 por ~1 s ao longo de toda a linha do tempo; vale 55 em t0 (5,0 s depois da 1ª leitura) em todas as 5 repetições | **Acertou** |
| ns1 com o valor novo | logo após o reload (poucos ms) | `loaded serial` no mesmo ms do reload (logs); 40–130 ms medidos (média 102,0 ± 38,3) | **Acertou** (o medido é limitado pela sondagem) |
| ns2 | poucos ms (≤ ~0,1 s medido) | 130, 40, 120, 130 ms; 510 ms na repetição 4 | **Acertou em 4 de 5; a repetição 4 foi exceção** |
| ns3 | ~0,5 s (E3: 0,57 a 0,63 s) | 480–550 ms (média 526,0 ± 30,5); nos logs a transferência do ns3 começa exatamente +500 ms após o reload nas 5 repetições | **Acertou** |
| Valor antigo no resolvedor | 60 − t_c ≈ 55 s | 52,55 a 52,69 s (média 52,6 s) | **Errou** (~2,3 a 2,45 s a menos) |
| 1º valor novo no resolvedor | TTL 60 (ou 59) | TTL 60 nas 5 repetições | **Acertou** |
| Janela máxima teórica | ≈ 60,6 s | 60,55 s (60 s + 550 ms, o maior atraso observado); medido ≤ 52,69 s | **Acertou** (o medido fica abaixo do máximo) |
| Janela medida | ≈ 60 − t_c ≈ 55 s | 52,6 s | **Errou** (~2,4 s a menos) |
| Prefetch, ressalva da previsão | "pode aparecer até ~2 s antes" | Troca 1,83 a 1,88 s antes de o TTL chegar a 0 (ver abaixo) | **A ressalva cobriu o fenômeno**, mas o número principal da previsão não o incluía |

**Todos os autoritativos tinham o valor novo enquanto o resolvedor seguia com o antigo.** Isso ocorreu por ~52 s em cada repetição (357 a 363 leituras divergentes de ~0,14 s). É o comportamento previsto: consistência eventual, limitada pelo TTL.

### Por que o resolvedor trocou o valor ~2,4 s antes do TTL de t0

O `erro vs TTL` (−2450 a −2310 ms) compara a janela com `ttl_antes × 1000`. Com a linha do tempo, ele se divide exatamente em duas partes:

| Rep. | Janela | Última mudança do TTL antes de t0 (TTL 55, t_rel) | Instante em que o TTL mostraria 0 (esse t_rel + 55000) | Adiantamento (instante TTL 0 − janela) | Erro vs TTL |
|---|---|---|---|---|---|
| 1 | 52550 | −590 | 54410 | 1860 | −2450 = −590 − 1860 |
| 2 | 52580 | −540 | 54460 | 1880 | −2420 = −540 − 1880 |
| 3 | 52690 | −440 | 54560 | 1870 | −2310 = −440 − 1870 |
| 4 | 52670 | −480 | 54520 | 1850 | −2330 = −480 − 1850 |
| 5 | 52590 | −580 | 54420 | 1830 | −2410 = −580 − 1830 |

1. **Parte 1: 0,44 a 0,59 s por alinhamento do TTL do `dig`.** O TTL mostrado muda em fronteiras de segundo, e a última mudança antes de t0 ocorreu 0,44 a 0,59 s antes. Por isso `ttl_antes × 1000` superestima o tempo restante. É um artefato da medição (resolução de 1 s do TTL).
2. **Parte 2: 1,83 a 1,88 s antes de o TTL mostrar 0.** Em todas as 5 repetições a última leitura com o valor antigo mostra TTL 2, e a leitura seguinte, 130 a 170 ms depois, traz o valor novo com TTL 60. O resolvedor nunca mostrou TTL 1 ou 0. Esse é o único dado direto sobre essa parte.

**Fatos verificados:**
- `resolvedor/named.conf` não define `prefetch` nem nenhuma opção de TTL; se há prefetch, ele vem do padrão do BIND.
- Os logs **não** têm registro de prefetch (0 ocorrências de "prefetch") e o resolvedor não loga nada após a inicialização (log de consultas desligado). Portanto os logs não confirmam nem refutam.
- A troca ocorre ao redor de TTL = 2 em todas as repetições, sempre na leitura seguinte à primeira com TTL 2.

**Hipótese (não verificada nos dados): é o prefetch do BIND.** O prefetch consulta de novo o registro em segundo plano quando uma consulta chega perto do fim do TTL, e devolve ao cliente o valor que está em cache. Isso casa com o padrão observado (a leitura com TTL 2 ainda devolve o valor antigo, e a seguinte já traz o novo com TTL 60).
- **Fonte externa:** artigo da ISC (https://kb.isc.org/aa-01315), consultado pelo executor (João Balhego) em 27/10/2026. Ele informa que o prefetch está ativado por padrão no BIND 9.10. O artigo é sobre a versão 9.10 e o laboratório usa a 9.18, então o comportamento exato na 9.18, os valores de limiar e o efeito sobre o cache negativo não foram verificados. Continua sendo hipótese.
- Foi mencionado de memória, sem fonte, que o padrão seria `prefetch 2 9;`. Isso não está confirmado por nenhuma fonte usada aqui. O comportamento observado (troca com TTL 2) é compatível com esse valor, mas o valor em si não foi verificado.
- Nem os logs nem o artigo provam que foi o prefetch que atuou na troca. Não foi feito `rndc dumpdb` nem ligado o log de consultas.

**Consequência da hipótese:** se for prefetch, a própria sondagem (consultas a cada ~0,14 s) é quem dispara o refresh. Um cliente que consultasse o resolvedor só uma vez veria o valor antigo até o TTL realmente expirar (~54,4 s), e não 52,6 s. Isso também não foi testado.

## Fase negativa (novo.sd.lab, TTL negativo)

| Item da previsão | Previsto | Observado | Resultado |
|---|---|---|---|
| NXDOMAIN e TTL do SOA | 20, decrescendo | 1ª leitura NXDOMAIN com TTL 20 nas 5 repetições; TTL cai de 20 a 1 | **Acertou** |
| ns1 e ns2 após criar o nome | poucos ms | 10–120 ms (média 64,0 ± 48,3) | **Acertou** |
| ns3 após criar o nome | ~0,5 s | 470–590 ms (média 516,0 ± 50,8); logs: +500 ms exatos nas 5 repetições | **Acertou** |
| Duração do NXDOMAIN após a criação | ≤ 20 s (≈ 20 − t_c ≈ 17 s) | 16,64 a 16,84 s (média 16,75 s) | **Acertou** |
| Janela máxima teórica | ≈ 20,6 s | 20,59 s (20 s + 590 ms); medido ≤ 16,84 s | **Acertou** |
| Janela medida vs TTL antes | ≈ 17 s | erro −160 a −360 ms | **Acertou, com artefato de 1 s do TTL** (abaixo) |

**O erro de −0,16 a −0,36 s é só o alinhamento do TTL do `dig`.** Em cada repetição, a janela é o instante da última mudança do TTL antes de t0 mais 17 s, com diferença de −40 a +10 ms:

| Rep. | TTL 17 desde (t_rel) | + 17000 | Janela | Diferença |
|---|---|---|---|---|
| 1 | −320 | 16680 | 16640 | −40 |
| 2 | −230 | 16770 | 16750 | −20 |
| 3 | −270 | 16730 | 16740 | +10 |
| 4 | −150 | 16850 | 16840 | −10 |
| 5 | −160 | 16840 | 16800 | −40 |

O resolvedor devolveu o valor novo (TTL 60) 130–150 ms depois da última leitura com TTL 1, que é o instante em que o TTL mostraria 0. **Não houve adiantamento**: o NXDOMAIN em cache expirou com o TTL normalmente.

**O que isso mostra sobre o TTL negativo.** O 1º TTL do NXDOMAIN foi 20 (o campo `minimum` do SOA), e não 60 (o `$TTL` da zona). Isso é compatível com a dedução da previsão (menor valor entre 60 e 20). A previsão ainda dizia que, se o NXDOMAIN persistisse por ~60 s, a dedução estaria errada. Isso não ocorreu.

**Contraste com a fase positiva (hipótese):** o adiantamento de ~1,8 s só aparece no registro positivo. Isso é compatível com um prefetch que valha só para respostas positivas, mas **não está verificado**: o efeito do prefetch sobre o cache negativo não foi verificado (o artigo da ISC consultado pelo executor é sobre o BIND 9.10). Se valesse também para o cache negativo e o gatilho fosse o mesmo, um adiantamento seria esperado aqui, e ele não ocorreu.

## Replicação nos logs (fases positiva e negativa)

Do `reload` no ns1 até a transferência concluída (hora do BIND, ms; o `loaded serial` do ns1 ocorre no mesmo ms do reload):

| Fase / rep. | ns2 | ns3 |
|---|---|---|
| Positiva 1 a 5 | 0, 4, 0, **468**, 4 | 500, 500, 500, 500, 500 |
| Negativa 1 a 5 | 0, 4, 0, 0, 0 | 500, 500, 500, 500, 500 |

Isso confirma o que o E3 mostrou: o ns3 sempre recebe o NOTIFY 500 ms depois do ns2. A previsão usava isso e acertou.

### Repetição 4 da fase positiva: ns2 em 510 ms (ns1 em 90 ms)

O CSV mostra ns1 = 90 ms e ns2 = 510 ms, diferente das outras repetições (ns2 igual ao ns1). Os logs da repetição 4 (serial 2026101405, reload às 16:38:08.562):

- **ns1:** `reload` e `loaded serial 2026101405` às 08.562, `sending notifies` no mesmo instante.
- **ns2:** `received notify` e `notify from 172.30.0.11: serial 2026101405` às 08.562 (mesmo instante). **`Transfer started` só às 09.030, 468 ms depois.** O ns1 registra a transferência pedida pelo ns2 às 09.030 (IXFR caindo para AXFR, 0,001 s).
- **ns3:** recebe o NOTIFY às 09.062 (+500 ms, como sempre) e transfere em seguida.
- Nas outras 9 repetições (positivas e negativas), o `Transfer started` do ns2 vem 0 a 4 ms depois do `notify from`.

**O que os logs provam:** o ns2 aceitou o NOTIFY no instante esperado, e o atraso de 468 ms ocorreu **depois** do NOTIFY e **antes** de o ns2 iniciar a transferência. Nenhuma outra linha de log do ns2 aparece nesse intervalo, e o ns1 só vê o pedido às 09.030.
**Causa: não determinada.** Os logs não registram a consulta de SOA que o secundário faz antes de transferir (log de consultas desligado), então não dá para dizer se o atraso foi no ns2, na rede entre ns2 e ns1 ou no ns1. A janela do resolvedor da repetição 4 (52,67 s) ficou igual à das outras, o que é esperado: o ns2 ainda atualizou antes do refresh do resolvedor.

## Conclusão do E4

- **Positiva:** o resolvedor devolveu o valor antigo por ~52,6 s depois da alteração (feita ~5 s após o preenchimento), enquanto ns1, ns2 e ns3 tinham o valor novo em ≤ 0,55 s. A janela medida ficou abaixo do máximo teórico de 60,55 s.
- **Previsão não ajustada.** O número da previsão (≈ 55 s) errou por ~2,4 s: 0,44–0,59 s pelo alinhamento do TTL do `dig` e 1,83–1,88 s por uma troca antecipada. A ressalva sobre prefetch estava na previsão, mas o número central não a incluía. Isso fica registrado como erro da previsão.
- **Negativa:** o NXDOMAIN ficou em cache ~16,75 s depois da criação do nome (≈ 20 − 3 s), abaixo do máximo de 20,59 s. Nesta fase a previsão acertou.
- **Replicação:** com NOTIFY, o ns2 convergiu em ≤ 4 ms (exceto a repetição 4: 468 ms) e o ns3 em 500 ms, em todas as repetições.
- **Critério de invalidação da previsão:** o critério literal ("o resolvedor devolve o valor novo antes de o TTL expirar") seria disparado, mas isso ocorreu por uma troca antecipada no resolvedor, que a ressalva da previsão já antecipava. O cache esteve em uso por ~52 s. Os demais critérios não foram acionados.

## Limitações

- 5 repetições por fase. As repetições não são independentes: o cache de cada repetição vem do refresh da anterior, o intervalo entre repetições foi quase constante (~58 s), e o desvio pequeno da janela (60,7 ms e 75,4 ms) reflete a fase fixa do TTL em segundos mais o ciclo da sondagem, não a variabilidade real.
- O TTL do `dig` tem resolução de 1 s, e `ttl_antes_s` é o TTL da última leitura anterior a t0.
- A sondagem tem ciclo de 130 a 180 ms (média ~144 ms, pelas linhas do tempo). Todos os tempos medidos têm essa incerteza.
- Uma única máquina e um único relógio para todos os contêineres.
- O log de consultas do resolvedor está desligado, então não dá para ver o cache, o prefetch nem as consultas de SOA dos secundários.
- A sondagem consulta o resolvedor a cada ~0,14 s e pode influenciar o próprio cache (hipótese do prefetch). A janela medida pode ser menor do que a de um cliente que consulta raramente.
- O experimento não variou `t_c` (sempre ~5 s na positiva e ~3 s na negativa), então a relação "janela ≈ TTL − t_c" foi testada em um único ponto.
- A ausência de rodada anterior é declarada pelo executor e consistente com os arquivos, mas não é comprovável pelos logs, já que o `reset.sh` apaga o estado do laboratório. O `verificar.sh` também só consta no terminal do executor.
