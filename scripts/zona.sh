#!/bin/sh
# Edita a cópia de trabalho da zona do ns1 (runtime/ns1/db.sd.lab), incrementa
# o serial e recarrega o primário. Só para a zona ESTÁTICA (E2-E8).
# Na variante dinâmica (E9) a zona é alterada por nsupdate.
#
# uso: scripts/zona.sh set <nome> <ip> [--sem-reload]   cria/troca registro A
#      scripts/zona.sh del <nome>                       remove registro A
#      scripts/zona.sh serial <numero>                  força um serial (E8)
#      scripts/zona.sh ver                              mostra serial e registros
#
# Saída (última linha): o serial que o ns1 passou a servir.
. "$(dirname "$0")/lib.sh"

if modo_dinamico; then
    echo "ERRO: zona em modo dinâmico (journal/variante e9). Use nsupdate, ou"
    echo "      'rndc freeze sd.lab' + edição + 'rndc thaw sd.lab'. Nunca edite o .jnl."
    exit 1
fi
[ -f "$ZONA_TRABALHO" ] || { echo "ERRO: $ZONA_TRABALHO não existe. Rode scripts/reset.sh"; exit 1; }

op=${1:-}; nome=${2:-}; valor=${3:-}; recarregar=1
for a in "$@"; do [ "$a" = "--sem-reload" ] && recarregar=0; done

tmp="$ZONA_TRABALHO.tmp"
incrementa_serial() { awk '/; serial/ && !f { sub($1, $1 + 1); f = 1 } { print }' "$1"; }

case "$op" in
    set)
        [ -n "$nome" ] && [ -n "$valor" ] || { echo "uso: zona.sh set <nome> <ip>"; exit 1; }
        awk -v n="$nome" -v v="$valor" '
            $1 == n && $2 == "IN" && $3 == "A" { print n " IN A " v; achou = 1; next }
            { print }
            END { if (!achou) print n " IN A " v }' "$ZONA_TRABALHO" > "$tmp.1"
        incrementa_serial "$tmp.1" > "$tmp"; rm -f "$tmp.1" ;;
    del)
        [ -n "$nome" ] || { echo "uso: zona.sh del <nome>"; exit 1; }
        awk -v n="$nome" '!($1 == n && $2 == "IN" && $3 == "A") { print }' "$ZONA_TRABALHO" > "$tmp.1"
        incrementa_serial "$tmp.1" > "$tmp"; rm -f "$tmp.1" ;;
    serial)
        [ -n "$nome" ] || { echo "uso: zona.sh serial <numero>"; exit 1; }
        awk -v s="$nome" '/; serial/ && !f { sub($1, s); f = 1 } { print }' "$ZONA_TRABALHO" > "$tmp" ;;
    ver)
        echo "Serial no arquivo: $(awk '/; serial/ {print $1; exit}' "$ZONA_TRABALHO")"
        echo "Serial servido pelo ns1: $(serial_de 172.31.0.11)"
        grep -E '^[a-z0-9-]+[[:space:]]+IN[[:space:]]+A[[:space:]]' "$ZONA_TRABALHO"
        exit 0 ;;
    *)
        sed -n '2,13p' "$0"; exit 1 ;;
esac

cat "$tmp" > "$ZONA_TRABALHO"; rm -f "$tmp"
novo=$(awk '/; serial/ {print $1; exit}' "$ZONA_TRABALHO")

if [ "$recarregar" -eq 0 ]; then
    echo "Arquivo alterado (sem reload). Serial no arquivo: $novo"
    echo "$novo"; exit 0
fi

# Recarrega e confere (armadilha do roteiro: duas edições no mesmo segundo
# podem passar despercebidas; por isso o serial servido é conferido).
for tentativa in 1 2 3; do
    no ns1 rndc reload sd.lab >/dev/null
    sleep 1
    servido=$(serial_de 172.31.0.11)
    [ "$servido" = "$novo" ] && break
    touch "$ZONA_TRABALHO"
done
if [ "$servido" != "$novo" ]; then
    echo "AVISO: ns1 serve $servido, esperado $novo. Veja: docker compose logs ns1 | tail"
    exit 1
fi
echo "ns1 recarregado. Serial servido:"
echo "$novo"
