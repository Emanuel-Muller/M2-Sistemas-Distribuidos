# Imagem única usada por todos os papéis (roteiro, p.12).
FROM alpine:3.20

RUN apk add --no-cache bind bind-tools

# [ADAPTAÇÃO A1] Garante a chave do rndc. Se o pacote já criar a chave,
# esta linha não faz nada. Ver README.md, "Adaptações em relação ao roteiro" (A1).
RUN if [ ! -f /etc/bind/rndc.key ]; then rndc-confgen -a -u named; fi

CMD ["named", "-g", "-u", "named", "-c", "/etc/bind/named.conf"]
