#!/bin/sh
# Ficha de ambiente de um integrante: sistema, versões, commit e imagem.
# uso: scripts/ficha-ambiente.sh <pessoa1|pessoa2|pessoa3|pessoa4>
# saída: docs/ambiente/<pessoa>.md (commitar via pull request)
. "$(dirname "$0")/lib.sh"

p=${1:?uso: ficha-ambiente.sh <pessoa1|pessoa2|pessoa3|pessoa4>}
arq="docs/ambiente/$p.md"
mkdir -p docs/ambiente
{
    echo "# Ficha de ambiente: $p"
    echo
    echo "Gerada em: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo
    echo '```'
    echo "== Sistema"
    uname -a
    [ -f /etc/os-release ] && grep -E '^(PRETTY_NAME)=' /etc/os-release
    command -v sw_vers >/dev/null 2>&1 && sw_vers
    grep -qi microsoft /proc/version 2>/dev/null && echo "Ambiente: WSL"
    echo
    echo "== Ferramentas"
    git --version
    docker version --format 'Docker cliente {{.Client.Version}} | servidor {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'
    docker compose version
    echo "contexto Docker: $(docker context show)"
    docker info --format 'motor: {{.OSType}}/{{.Architecture}} | CPUs: {{.NCPU}} | memória: {{.MemTotal}} bytes'
    echo
    echo "== Repositório"
    echo "commit: $(git rev-parse HEAD)"
    echo "tag/descrição: $(git describe --tags --always)"
    echo "alterações locais: $(git status --porcelain | wc -l | tr -d ' ') arquivo(s)"
    echo
    echo "== Imagem"
    echo "digest da base alpine:3.20: $(docker image inspect alpine:3.20 --format '{{index .RepoDigests 0}}' 2>/dev/null || echo 'imagem base não encontrada')"
    docker run --rm sd-bind named -v
    docker run --rm sd-bind sh -c 'for b in named rndc rndc-confgen named-checkconf named-checkzone named-journalprint tsig-keygen nsupdate dig ip; do printf "%-20s %s\n" "$b" "$(command -v $b || echo AUSENTE)"; done'
    echo "relógio no contêiner (date +%s%N): $(docker run --rm sd-bind date +%s%N)"
    echo "sleep fracionário: $(docker run --rm sd-bind sh -c 'sleep 0.1 && echo ok' 2>&1)"
    echo
    echo "== Redes Docker existentes"
    for n in $(docker network ls -q); do docker network inspect -f '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}} {{end}}' "$n"; done
    echo '```'
} > "$arq" 2>&1
cat "$arq"
echo
echo "Ficha salva em $arq"
