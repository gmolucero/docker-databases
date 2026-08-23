#!/usr/bin/env bash
#
# Levanta las bases de datos de este proyecto.
#
# Uso:
#   ./up.sh                             # levanta las 6 bases de datos
#   ./up.sh --database mariadb          # levanta solo mariadb
#   ./up.sh -d mysql57                  # levanta solo mysql57
#   ./up.sh -d mariadb -d mongo         # levanta varias (se puede repetir -d)
#
# Servicios válidos: mariadb, mysql57, mysql8, mongo, postgres, redis

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VALID_SERVICES=(mariadb mysql57 mysql8 mongo postgres redis)

usage() {
  echo "Uso: $0 [--database|-d <servicio>]"
  echo "Servicios válidos: ${VALID_SERVICES[*]}"
  exit 1
}

ensure_network() {
  if [[ ! -f .env.network ]]; then
    echo "⚠️  No existe .env.network. Copia .env.network.example y ajústalo si hace falta." >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  local network_name
  network_name="$(grep -E '^NETWORK_NAME=' .env.network | cut -d= -f2- | tr -d "'\"")"
  if ! docker network inspect "$network_name" >/dev/null 2>&1; then
    echo "🌐 Creando red $network_name..."
    docker network create "$network_name" >/dev/null
  fi
}

SERVICES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --database|-d)
      [[ -z "${2:-}" ]] && usage
      SERVICES+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Argumento desconocido: $1"
      usage
      ;;
  esac
done

up_service() {
  local name="$1"
  local compose_file=".env.${name}"

  if [[ ! -f "$compose_file" ]]; then
    echo "⚠️  No existe $compose_file. Copia .env.${name}.example y complétalo antes de levantar $name." >&2
    return 1
  fi

  echo "▶️  Levantando $name..."
  docker compose --env-file "$compose_file" --env-file .env.network -f "${name}.yml" up -d
}

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=("${VALID_SERVICES[@]}")
fi

for svc in "${SERVICES[@]}"; do
  if [[ ! " ${VALID_SERVICES[*]} " =~ " ${svc} " ]]; then
    echo "Servicio inválido: $svc"
    usage
  fi
done

ensure_network

status=0
for svc in "${SERVICES[@]}"; do
  up_service "$svc" || status=1
done
exit $status
