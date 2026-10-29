#!/bin/sh
# E9: gera as chaves TSIG em secrets/ (pasta fora do Git).
#   cliente1.key e cliente2.key: chaves válidas, uma por cliente
#   invalida.key: mesmo nome "cliente1", segredo diferente (teste negativo)
# Cada integrante gera as próprias chaves na sua máquina.
# Chaves existentes e válidas são mantidas; só as que faltam (ou estão vazias
# ou corrompidas) são geradas. Com --substituir, as três são geradas de novo.
# uso: scripts/gerar-chaves-tsig.sh [--substituir]
. "$(dirname "$0")/lib.sh"

substituir=0; [ "${1:-}" = "--substituir" ] && substituir=1
docker image inspect sd-bind >/dev/null 2>&1 || { echo "ERRO: imagem sd-bind não existe. Rode: docker compose build"; exit 1; }
mkdir -p secrets

# Verdadeiro se o arquivo contém uma chave TSIG com o nome esperado.
chave_valida() { [ -s "$1" ] && grep -q "key \"$2\"" "$1" && grep -q 'secret "' "$1"; }

# gera <arquivo sem .key> <nome da chave>
gera() {
    tmp="secrets/.$1.tmp"
    if docker run --rm sd-bind tsig-keygen -a hmac-sha256 "$2" > "$tmp" 2>/dev/null && chave_valida "$tmp" "$2"; then
        mv "$tmp" "secrets/$1.key"
        echo "gerada:  secrets/$1.key (nome $2)"
    else
        rm -f "$tmp"
        echo "ERRO: falha ao gerar secrets/$1.key"
        return 1
    fi
}

falhas=0; geradas=0
for par in "cliente1 cliente1" "cliente2 cliente2" "invalida cliente1"; do
    set -- $par
    if [ "$substituir" -eq 0 ] && chave_valida "secrets/$1.key" "$2"; then
        echo "mantida: secrets/$1.key"
        continue
    fi
    if gera "$1" "$2"; then geradas=$((geradas + 1)); else falhas=$((falhas + 1)); fi
done
chmod 0644 secrets/*.key 2>/dev/null

if cmp -s secrets/cliente1.key secrets/invalida.key; then
    echo "ERRO: invalida.key é idêntica a cliente1.key. Rode: scripts/gerar-chaves-tsig.sh --substituir"
    falhas=$((falhas + 1))
fi

echo "Chaves em secrets/ (não versionar):"
ls -l secrets/*.key 2>/dev/null
[ "$geradas" -gt 0 ] && echo "Se o laboratório já estava no ar com a variante e9, rode scripts/reset.sh para o ns1 ler as chaves novas."
[ "$falhas" -eq 0 ]
