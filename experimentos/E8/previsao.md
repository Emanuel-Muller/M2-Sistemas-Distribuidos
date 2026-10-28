# Previsão: E8 (Coordenação e ordem)

- Responsável: Emanuel Müller Bueno
- Data/hora do registro: 27/10/2026 22:07
- Commit/tag do laboratório: c66fd2b

Ponto de partida assumido: ambiente-base (variante `base`, sem `COMPOSE_FILE`), `scripts/reset.sh` executado e `scripts/verificar.sh` APROVADO, ou seja, ns1, ns2 e ns3 servindo o serial inicial **2026101401** e `app IN A 10.0.0.1`.

## O que esperamos observar

**Etapa 1: coordenador estático e ordem pelo serial**

1. `dig SOA` direto (`+norecurse`) em ns1, ns2 e ns3 devolve o mesmo serial (2026101401). O campo MNAME do SOA aponta para `ns1.sd.lab.`, e os três respondem com a flag `aa`. Só o ns1 tem `type primary`; ns2 e ns3 têm `type secondary` com `primaries { 172.30.0.11; }`. Não existe eleição: ninguém mais pode assumir o papel de primário.
2. Uma tentativa de escrita (`nsupdate`) enviada ao ns2 é recusada (**REFUSED**), pois secundário não aceita escrita e a zona não tem `allow-update`. O ns1, na zona estática, também recusaria. A única forma de mudar a zona é editar o arquivo no ns1, incrementar o serial e recarregar.
3. Duas edições sucessivas (`scripts/zona.sh set app 10.0.0.2`, depois `... 10.0.0.3`) levam o ns1 a 2026101402 e depois 2026101403. ns2 e ns3 seguem o ns1 pelo NOTIFY e terminam em 2026101403. Se a segunda edição ocorrer dentro da janela do `notify-delay` (5 s), um secundário pode saltar direto de 01 para 03 sem passar por 02. Em qualquer caso, o serial visto em cada secundário só cresce. O que ordena as versões é o serial, não o horário da edição nem a ordem de chegada.
4. A transferência da zona estática deve ser completa (AXFR, ou resposta "AXFR-style IXFR" no log), porque `ixfr-from-differences` não está ativo nessa zona.

**Etapa 2: publicar serial menor que o atual**

Com o estado da etapa 1 (serial 2026101403), alterar `app` para `10.0.0.9` e forçar o serial para um valor menor (ex.: 2026101300, diferença de 103) num único reload no ns1:

1. O ns1 aceita e passa a servir serial 2026101300 com `app = 10.0.0.9`. O primário não valida monotonicidade da própria zona estática; quem aplica a regra são os consumidores.
2. ns2 e ns3 **não transferem a zona**. Continuam servindo serial 2026101403 com `app = 10.0.0.2`. Nos logs deve aparecer o NOTIFY recebido, seguido de uma mensagem do tipo `serial number (2026101300) received from primary 172.30.0.11#53 < ours (2026101403)` (ou "zone is up to date"), e nenhuma linha de transferência concluída.
3. Resultado: **divergência persistente**. O ns1 tem o serial "mais antigo" com dado novo, e os secundários têm o serial "mais novo" com dado antigo. Ela não se corrige com o passar do tempo (observar pelo menos 90 s, ou seja, 3 ciclos de refresh).
4. Via resolvedor, depois de expirar o TTL (60 s), a resposta de `app.sd.lab` pode alternar entre 10.0.0.9 (ns1) e 10.0.0.2 (ns2/ns3), conforme o autoritativo escolhido pelo encaminhamento. Isso é um efeito colateral a registrar, sem ser o foco.
5. Para convergir basta publicar um serial **maior** que 2026101403 (ex.: 2026101404, mantendo `app = 10.0.0.9`): ns2 e ns3 transferem em cerca de 1 s e passam a servir 10.0.0.9. Um `rndc retransfer sd.lab` no secundário também forçaria a cópia, ignorando a comparação de seriais, mas isso é intervenção manual de operador, não protocolo.

**Etapa 3: dois primários sem coordenação (discussão, sem execução)**

Prevemos, por análise, os seguintes cenários (não serão executados, a menos que a equipe decida simular):

- **Mesmo serial, conteúdos diferentes** (A e B editam a partir de 2026101403 e ambos chegam a ...404): um secundário que recebeu o ...404 de A considera o ...404 de B "já atualizado" e nunca o busca. Dois secundários podem ficar com conteúdos diferentes sob o mesmo serial. O serial deixa de identificar uma versão e a divergência é silenciosa.
- **Seriais diferentes**: vence o maior serial, não a edição mais recente nem a mais correta. As alterações do outro primário são perdidas sem aviso (lost update); não há merge.
- **Serial menor num dos primários**: ele é ignorado pelos secundários, como na etapa 2.
- **Atualização dinâmica nos dois**: os journals teriam histórias diferentes, e o IXFR de um não se aplica sobre a base do outro. Na prática cairia em AXFR ou em estado inconsistente.

## Por quê

- **Primário estático.** O DNS clássico é replicação primário→secundário: a escrita acontece num único ponto (o primário, `type primary`) e propaga por NOTIFY + IXFR/AXFR. O papel é fixado por configuração, sem eleição. Por isso o ns1 é ao mesmo tempo o coordenador e o ponto único de escrita (liga com S3 e com o E5, em que parar o ns1 não promove ninguém).
- **Serial como ordem de versões.** O serial do SOA é um contador escalar de versão da zona. Um secundário compara o serial do primário com o seu usando a aritmética de números seriais (RFC 1982): `s1 < s2` quando a diferença módulo 2³² é menor que 2³¹. Só transfere se o serial remoto for maior. Com seriais no formato AAAAMMDDnn (≈ 2,0·10⁹) e diferença de 103, a comparação é inequívoca.
- **Relação com relógio lógico.** A regra do secundário corresponde à monotonicidade de um relógio de Lamport, em que o valor nunca regride e uma versão com número menor é tratada como "do passado" e não reaplicada. Diferenças que vamos apontar na análise: (i) o secundário apenas **copia** o serial recebido, sem `max(local, recebido)+1`, porque não gera eventos próprios; (ii) com uma única fonte de escrita, o serial funciona como número de sequência de um sequenciador, isto é, uma ordem total trivial, e não como relógio distribuído; (iii) um escalar não detecta concorrência (C(a) < C(b) não implica a → b), só relógios vetoriais mostrariam versões incomparáveis (liga com Q9).
- **Dois primários.** Sem coordenação (nem consenso, nem época/termo), nada impede que dois escritores gerem o mesmo número para conteúdos diferentes. O DNS resolve o problema evitando-o: um único escritor serializa tudo (no E9, via journal). Sistemas com vários candidatos a líder (Raft, Paxos, ZAB) acrescentam termo/época e eleição por maioria, para rejeitar líderes obsoletos (liga com Q8 e Q9).
- **Consistência eventual com autoridade única.** Divergência entre primário e secundários só é corrigida se a regra de ordem a enxergar. Um serial regredido a esconde, e por isso a armadilha "esquecer de incrementar o serial" do roteiro tem a mesma causa.

## Números esperados (se houver medição)

O E8 é qualitativo (o que importa é quem aceita e quem recusa), mas registraremos alguns tempos de apoio:

| Item | Expectativa | Origem |
|---|---|---|
| Propagação de um serial maior (ns1 → ns2/ns3) | < 1 s; até ≈ 5–6 s se a edição ocorrer dentro de 5 s da anterior | NOTIFY do kit (README: < 1 s); `notify-delay` 5 s |
| Transferências de zona com serial **menor** | 0 em toda a janela de observação (≥ 90 s) | Regra do RFC 1982: só transfere se serial remoto > local |
| Frequência com que o secundário reconsulta e recusa | a cada 10–30 s (`retry` 10 s, `refresh` 30 s, `min-refresh-time` 10) | SOA da zona e `named.conf` dos secundários |
| Convergência após publicar serial maior (2026101404) | < 1 s, como na propagação normal | NOTIFY |
| Diferença entre o serial novo e o antigo | 2026101403 − 2026101300 = 103 (≪ 2³¹ = 2 147 483 648) | Aritmética de seriais |

Se o tempo de propagação for medido, repetir ao menos 5 vezes e reportar média e desvio (R7).
