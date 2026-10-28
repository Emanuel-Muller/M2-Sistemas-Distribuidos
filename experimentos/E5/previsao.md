# Previsão: E5 (Falha e quórum)

> Escrever ANTES de executar e fazer commit antes da execução.
> O histórico do Git é a prova de que a previsão veio antes do resultado.

- Responsável: Enzo Neumann (responsável principal do E5; apoio: a definir)
- Data/hora do registro: 2026-10-27 14:35 (-0300)
- Commit/tag do laboratório: c66fd2b (branch infra/laboratorio-base)

## O que esperamos observar

Seis cenários executados em sequência por `scripts/e5-falha.sh` (variante base). Em cada um, consultamos `app.sd.lab` direto em cada autoritativo (`+norecurse`) e pelo resolvedor, e testamos se é possível publicar uma alteração. O resultado é o quadro "nós ativos x leitura x escrita".

1. **C1, ns1 + ns2 + ns3 (base):** os três respondem `NOERROR` com flag `aa` e o mesmo valor. A escrita funciona: `zona.sh` sobe o serial e o ns1 passa a servir o serial novo.
2. **C2, ns1 parado:** ns2 e ns3 continuam respondendo `NOERROR` com `aa` e o último valor recebido; o ns1 dá timeout; o resolvedor continua respondendo. A escrita falha: `rndc reload` no ns1 não executa porque o serviço não está rodando.
3. **C3, ns1 e ns2 parados:** o ns3 sozinho continua respondendo `NOERROR` com `aa`, e o resolvedor ainda obtém resposta por ele. A escrita continua impossível.
4. **C4, ns3 sozinho até o expire:** o ns3 passa a responder `SERVFAIL`, e o resolvedor deixa de obter resposta válida. A escrita continua impossível.
5. **C5, só ns2 parado (extra):** ns1 e ns3 respondem e a escrita funciona; o ns3 recebe o serial novo em poucos segundos (NOTIFY), e o ns2 fica para trás até voltar.
6. **C6, só ns1 ativo (extra):** leitura e escrita funcionam, mas sem nenhuma réplica.
7. Em resumo: quem cai importa mais do que quantos caem. Perder o primário interrompe a escrita na hora; a leitura sobrevive com qualquer autoritativo vivo, mas só até o expire.

## Por quê

**Leitura sem primário.** Cada secundário guarda uma cópia completa da zona (arquivo `db.sd.lab` em `/var/bind`) e responde com autoridade a partir dela. Responder uma consulta não exige contato com o primário. Portanto, para leitura, basta um autoritativo (R = 1).

**Escrita só no primário.** No DNS clássico, a zona só é alterada no primário: edição do arquivo + serial + `rndc reload`. Os secundários são somente leitura (puxam cópias por AXFR/IXFR) e não aceitam alterações. Com o ns1 parado, não existe nenhum nó capaz de publicar uma nova versão. O ponto de falha da escrita é **um nó específico**, não a perda de uma maioria.

**Expire.** O secundário consulta o SOA do primário a cada `refresh` (30 s). Quando falha, tenta de novo a cada `retry` (10 s). Se passar `expire` (300 s) desde o último refresh bem-sucedido, ele considera a cópia velha demais e deixa de responder pela zona (`SERVFAIL`). O roteiro relata esse comportamento no teste do kit (p.13).

**Quórum.** O DNS não usa quórum (o roteiro, p.6, pede para demonstrar e justificar a ausência). Forçando a notação: N = 3 cópias; R = 1 (qualquer autoritativo responde sozinho); W = 1, mas não "qualquer 1 de N": é o primário, um nó fixo, que confirma a escrita localmente e replica depois, de forma assíncrona. Como R + W = 2 não é maior que N = 3, não há garantia de que a leitura veja a última escrita. Isso é coerente com a consistência eventual (E4). A tolerância a falhas é assimétrica: leitura tolera até N − 1 = 2 quedas, mas só por um tempo limitado (expire); escrita tolera 0 quedas do primário e qualquer número de quedas de secundários.

**Conceitos da disciplina.** Modelo de falhas por parada (`docker compose stop`); detecção por timeout, sem heartbeat (refresh/retry/expire); replicação primário-backup assíncrona × consenso com maioria (Raft/Paxos); Q10 e S3.

## Números esperados (se houver medição)

- **Momento do SERVFAIL no ns3 (C4):** entre ~270 s e ~300 s depois da parada do ns1. O expire conta a partir do **último refresh bem-sucedido**, que ocorreu até ~30 s antes da parada (ver `zonestatus-ns3-antes.txt`: o campo `expires` deve prever o instante). A resolução da medição é o intervalo de amostragem (5 s).
- **Consultas ao ns1 parado:** timeout de ~1–2 s (limite do `dig`).
- **Resolvedor em C2/C3:** respostas corretas, possivelmente com `Query time` maior que no C1, se ele tentar primeiro um forwarder morto antes de passar para outro.
- **C5:** ns3 com o serial novo em menos de ~1–2 s (NOTIFY, coerente com a previsão do E3).
- **Restauração depois do C4:** ns2 e ns3 voltam a servir em até ~10 s após o ns1 voltar (próxima tentativa no intervalo de `retry`).

## O que invalidaria a previsão

- ns2/ns3 dando `SERVFAIL` ou sem `aa` logo depois da parada do ns1: indicaria que a cópia não estava carregada (conferir `verificar.sh` e logs).
- Escrita "OK" com o ns1 parado: indicaria que o teste não atingiu o ns1 de verdade.
- SERVFAIL muito antes de ~270 s ou nunca até ~330 s: o expire efetivo é diferente de 300 s; conferir o SOA servido e o `zonestatus`.
- No C5, o ns3 levando cerca de 30 s para receber a escrita: o NOTIFY não chegou e a propagação dependeu do `refresh`.
