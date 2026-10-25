#!/bin/sh
# Verificação de prontidão do laboratório (não é o E1/E2 formal).
# Imprime OK/FALHA por item e termina com código 0 só se tudo passou.
#
# uso: scripts/verificar.sh            (saída na tela)
#      scripts/verificar.sh > arquivo  (para anexar a um PR ou ficha)
. "$(dirname "$0")/lib.sh"

falhas=0
ok()    { echo "OK     $*"; }
falha() { echo "FALHA  $*"; falhas=$((falhas + 1)); }
info()  { echo "INFO   $*"; }

info "data: $(date '+%Y-%m-%d %H:%M:%S %z')"
info "commit: $(git rev-parse --short HEAD 2>/dev/null || echo '?') $(git describe --tags --always 2>/dev/null || true)"
info "variante: $(variante)"

# 1. contêineres em execução
for s in ns1 ns2 ns3 resolvedor cliente cliente2; do
    est=$(docker inspect -f '{{.State.Status}} reinicios={{.RestartCount}}' "$s" 2>/dev/null || echo "inexistente")
    case "$est" in running*) ok "contêiner $s: $est" ;; *) falha "contêiner $s: $est" ;; esac
done

# 2. SOA com flag aa e mesmo serial nos três autoritativos
ref=""
for ip in 172.31.0.11 172.31.0.12 172.31.0.13; do
    saida=$(no cliente dig @"$ip" sd.lab SOA +norecurse +time=2 +tries=1 2>&1)
    serial=$(echo "$saida" | awk '$4=="SOA" {print $7; exit}')
    if echo "$saida" | grep -q 'flags:.* aa'; then aa=sim; else aa=nao; fi
    if [ -n "$serial" ] && [ "$aa" = sim ]; then ok "SOA em $ip: serial $serial, flag aa"; else falha "SOA em $ip: serial='$serial' aa=$aa"; fi
    [ -z "$ref" ] && ref=$serial
    [ -n "$serial" ] && [ "$serial" != "$ref" ] && falha "serial de $ip ($serial) difere do ns1 ($ref)"
done

# 3. conteúdo da zona nos secundários (registro app igual ao do primário)
v1=$(no cliente dig @172.31.0.11 app.sd.lab A +short +norecurse +time=2 +tries=1)
for ip in 172.31.0.12 172.31.0.13; do
    v=$(no cliente dig @"$ip" app.sd.lab A +short +norecurse +time=2 +tries=1)
    if [ -n "$v" ] && [ "$v" = "$v1" ]; then ok "app.sd.lab em $ip = $v (igual ao ns1)"; else falha "app.sd.lab em $ip = '$v' (ns1 = '$v1')"; fi
done

# 4. resolvedor responde com recursão (ra) e sem autoridade (aa)
saida=$(no cliente dig @172.31.0.53 app.sd.lab A +time=2 +tries=1 2>&1)
v=$(echo "$saida" | awk '$4=="A" {print $5; exit}')
if [ -n "$v" ] && echo "$saida" | grep -q 'flags:.* ra' && ! echo "$saida" | grep -q 'flags:.* aa'; then
    ok "resolvedor: app.sd.lab = $v, flag ra, sem aa"
else
    falha "resolvedor: resposta inesperada para app.sd.lab ('$v')"
fi

# 5. rede interna: secundário alcança o primário
if no ns2 dig @172.30.0.11 sd.lab SOA +short +time=2 +tries=1 2>/dev/null | grep -q 'ns1\.sd\.lab'; then
    ok "ns2 alcança 172.30.0.11 pela rede interna"
else
    falha "ns2 não alcança 172.30.0.11 pela rede interna"
fi

# 6. rndc nos quatro servidores
for s in ns1 ns2 ns3 resolvedor; do
    if no "$s" rndc status >/dev/null 2>&1; then ok "rndc status em $s"; else falha "rndc status em $s"; fi
done

# 7. secundários gravaram a cópia da zona
for s in ns2 ns3; do
    if no "$s" test -s /var/bind/db.sd.lab; then ok "$s gravou /var/bind/db.sd.lab"; else falha "$s não gravou /var/bind/db.sd.lab"; fi
done

# 8. usuário named consegue gravar no diretório da zona do ns1 (journal do E9)
if docker compose exec -T -u named ns1 sh -c 'touch /var/lib/bind/.teste-escrita && rm /var/lib/bind/.teste-escrita' 2>/dev/null; then
    ok "usuário named grava em /var/lib/bind do ns1"
else
    falha "usuário named NÃO grava em /var/lib/bind do ns1 (ver contingência no README)"
fi

# 9. erros graves nos logs
if docker compose logs --no-color 2>/dev/null | grep -Eiq 'permission denied|loading configuration: |exiting \(due to fatal error'; then
    falha "logs contêm erro grave (procure 'permission denied' ou 'fatal')"
else
    ok "logs sem 'permission denied' nem erro fatal"
fi

# 10. informativos
info "memória (uso / limite):"
docker stats --no-stream --format '         {{.Name}}: {{.MemUsage}}' ns1 ns2 ns3 resolvedor cliente cliente2 2>/dev/null
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then info "git status: limpo"; else info "git status: há arquivos alterados (ver git status)"; fi

echo
if [ "$falhas" -eq 0 ]; then echo "RESULTADO: APROVADO"; else echo "RESULTADO: $falhas FALHA(S)"; fi
[ "$falhas" -eq 0 ]
