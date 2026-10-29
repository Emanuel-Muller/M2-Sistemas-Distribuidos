# Funções comuns aos scripts. Não execute diretamente: ele é carregado
# pelos outros scripts com ". scripts/lib.sh".
#
# Todos os scripts mudam para a raiz do repositório antes de agir, então
# caminhos relativos (ex.: experimentos/E3) valem a partir da raiz.

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
cd "$RAIZ" || exit 1

ZONA_BASE=zonas/db.sd.lab
ZONA_TRABALHO=runtime/ns1/db.sd.lab
SERIAL_BASE=$(awk '/; serial/ {print $1; exit}' "$ZONA_BASE")

# Executa um comando dentro de um contêiner (sem terminal interativo).
no() { alvo=$1; shift; docker compose exec -T "$alvo" "$@"; }

# Serial servido por um autoritativo (consulta direta, sem recursão).
serial_de() {
    no cliente dig @"$1" sd.lab SOA +short +norecurse +time=2 +tries=1 2>/dev/null \
        | awk '$4 ~ /^[0-9]+$/ {print $3; exit}'
}

# Carimbo de data/hora para nomes de arquivo.
carimbo() { date '+%Y%m%d-%H%M%S'; }

# Data/hora em UTC no formato aceito por "docker compose logs --since".
agora_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# Variante em uso, de acordo com COMPOSE_FILE.
variante() {
    case "${COMPOSE_FILE:-}" in
        *e9*)          echo "e9 (atualizacao dinamica)" ;;
        *sem-notify*)  echo "sem-notify (E3)" ;;
        "")            echo "base" ;;
        *)             echo "outra: $COMPOSE_FILE" ;;
    esac
}

# Verdadeiro se a zona do ns1 está em modo dinâmico (há journal ou variante e9).
modo_dinamico() {
    [ -f runtime/ns1/db.sd.lab.jnl ] && return 0
    case "${COMPOSE_FILE:-}" in *e9*) return 0 ;; esac
    return 1
}

# Espera os três autoritativos servirem o mesmo serial (até $1 segundos de
# relógio; o prazo é medido pelo tempo decorrido, não pelo número de tentativas).
espera_convergencia() {
    lim=${1:-60}; fim=$(( $(date +%s) + lim ))
    while :; do
        s1=$(serial_de 172.31.0.11); s2=$(serial_de 172.31.0.12); s3=$(serial_de 172.31.0.13)
        if [ -n "$s1" ] && [ "$s1" = "$s2" ] && [ "$s1" = "$s3" ]; then
            echo "Convergência: serial $s1 em ns1, ns2 e ns3."
            return 0
        fi
        [ "$(date +%s)" -ge "$fim" ] && break
        sleep 1
    done
    echo "AVISO: sem convergência em ${lim}s (ns1=$s1 ns2=$s2 ns3=$s3)."
    return 1
}

# Prepara uma pasta de saída de nome fixo sem apagar a execução anterior:
# se ela já existir, é renomeada para <pasta>-anterior-<carimbo>.
preparar_pasta() {
    if [ -e "$1" ]; then
        ant="$1-anterior-$(carimbo)"
        mv "$1" "$ant" || return 1
        echo "Execução anterior preservada em $ant"
    fi
    mkdir -p "$1"
}
