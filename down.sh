#!/usr/bin/env bash
#
# Baja las bases de datos de este proyecto (docker compose down).
# Los datos no se pierden: cada servicio usa bind mounts en ./data/, que
# quedan intactos aunque el contenedor se elimine.
#
# Uso:
#   ./down.sh                             # baja las 6 bases de datos
#   ./down.sh --database mariadb          # baja solo mariadb
#   ./down.sh -d mysql57                  # baja solo mysql57
#   ./down.sh -d mariadb -d mongo         # baja varias (se puede repetir -d)
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

down_service() {
  local name="$1"
  local compose_file=".env.${name}"

  if [[ ! -f "$compose_file" ]]; then
    echo "⚠️  No existe $compose_file. Nada que bajar para $name." >&2
    return 1
  fi

  echo "⏹️  Bajando $name..."
  docker compose --env-file "$compose_file" --env-file .env.network -f "${name}.yml" down
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

status=0
for svc in "${SERVICES[@]}"; do
  down_service "$svc" || status=1
done
exit $status
