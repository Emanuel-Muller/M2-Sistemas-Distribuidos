#!/bin/sh
# E9: envia UMA atualização dinâmica e mostra a resposta do servidor.
# Serve para a validação inicial e para os testes de autorização.
# uso: scripts/e9-atualizar.sh <cliente|cliente2> <chave> <servidor_ip> <nome> <valor_txt>
#   chave: cliente1 | cliente2 | invalida | nenhuma
#   ex.: scripts/e9-atualizar.sh cliente cliente1 172.31.0.11 ordem.sd.lab teste-1
#        scripts/e9-atualizar.sh cliente nenhuma  172.31.0.11 ordem.sd.lab sem-chave
#        scripts/e9-atualizar.sh cliente cliente1 172.31.0.12 ordem.sd.lab no-secundario
# Código de saída: o mesmo do nsupdate (0 = aceito; 2 = recusado pelo servidor).
# Nos testes negativos a recusa é o resultado esperado.
. "$(dirname "$0")/lib.sh"

c=${1:?}; k=${2:?}; srv=${3:?}; nome=${4:?}; v=${5:?}
case "$k" in nenhuma) opt="" ;; *) opt="-k /chaves/$k.key" ;; esac
antes=$(serial_de 172.31.0.11)
echo "Enviando de $c (chave: $k) para $srv: $nome TXT \"$v\""
printf 'server %s\nzone sd.lab\nupdate delete %s TXT\nupdate add %s 60 TXT "%s"\nsend\n' "$srv" "$nome" "$nome" "$v" \
    | no "$c" nsupdate $opt
st=$?
depois=$(serial_de 172.31.0.11)
echo "código de saída do nsupdate: $st (0 = aceito)"
echo "serial do ns1: $antes -> $depois"
echo "valor no ns1: $(no cliente dig @172.31.0.11 "$nome" TXT +short +norecurse | tr -d '\r')"
exit "$st"
