# docker-db

Compose files independientes para levantar bases de datos locales de desarrollo: MariaDB, MySQL 5.7, MySQL 8, MongoDB, PostgreSQL y Redis. Cada motor tiene su propio archivo `.yml`, su propio archivo de variables de entorno y su propio volumen de datos — se pueden levantar juntos o por separado sin chocar entre sí.

## Servicios

| Servicio | Compose file | Contenedor | Puerto host | Imagen |
|---|---|---|---|---|
| MariaDB | `mariadb.yml` | `mariadb` | `3306` | `mariadb:11` |
| MySQL 5.7 | `mysql57.yml` | `mysql57` | `3307` | `mysql:5.7` |
| MySQL 8 | `mysql8.yml` | `mysql8` | `3308` | `mysql:8` |
| MongoDB | `mongo.yml` | `mongodb` | `27017` | `mongo:7` |
| PostgreSQL | `postgres.yml` | `postgres` | `5432` | `postgres:14.3` |
| Redis | `redis.yml` | `redis` | `6379` | `redis:7` |

## Configuración inicial

Ningún archivo de credenciales se versiona en este repo. Antes de levantar cualquier servicio, copia su plantilla y completa tus propios valores:

```bash
cp .env.mariadb.example  .env.mariadb
cp .env.mysql57.example  .env.mysql57
cp .env.mysql8.example   .env.mysql8
cp .env.mongo.example    .env.mongo
cp .env.postgres.example .env.postgres
cp .env.redis.example    .env.redis
```

Edita cada `.env.<servicio>` recién creado y reemplaza los valores `changeme` por credenciales propias. Estos archivos (`.env`, `.env.*`, excepto los `.example`) están en `.gitignore` — no deben commitearse nunca.

## Cómo levantar cada uno

La sustitución de variables `${...}` dentro de cada `.yml` se resuelve con el archivo pasado en `--env-file`, no con `env_file:` del servicio — por eso hay que indicarlo explícito en cada comando:

```bash
docker compose --env-file .env.mariadb  -f mariadb.yml  up -d
docker compose --env-file .env.mysql57  -f mysql57.yml  up -d
docker compose --env-file .env.mysql8   -f mysql8.yml   up -d
docker compose --env-file .env.mongo    -f mongo.yml    up -d
docker compose --env-file .env.postgres -f postgres.yml up -d
docker compose --env-file .env.redis    -f redis.yml    up -d
```

Cada `.yml` trae este mismo comando como comentario en su primera línea.

### Con el script `up.sh`

También hay un script que envuelve estos comandos:

```bash
./up.sh                          # levanta las 6 bases de datos
./up.sh --database mongo         # levanta solo mongo
./up.sh -d postgres              # levanta solo postgres
./up.sh -d mariadb -d mongo      # levanta varias (repite -d para cada una)
```

Si el `.env.<servicio>` correspondiente no existe (ver "Configuración inicial"), el script avisa y no intenta levantar ese servicio.

### Bajarlas con `down.sh`

Mismo patrón de flags, pero para `docker compose down`:

```bash
./down.sh                          # baja las 6 bases de datos
./down.sh --database mongo         # baja solo mongo
./down.sh -d postgres              # baja solo postgres
./down.sh -d mariadb -d mongo      # baja varias (repite -d para cada una)
```

Los datos no se pierden al bajar un servicio: cada uno usa bind mounts en `./data/`, que quedan intactos aunque el contenedor se elimine.

## Variables de entorno

Un `.env.<servicio>` por cada compose file (no hay un `.env` compartido). Las plantillas versionadas (`*.example`) documentan qué variables espera cada uno:

- **`.env.mariadb`** / **`.env.mysql57`** / **`.env.mysql8`** — `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `MYSQL_ROOT_HOST`
- **`.env.mongo`** — `MONGO_INITDB_ROOT_USERNAME`, `MONGO_INITDB_ROOT_PASSWORD`
- **`.env.postgres`** — `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_HOST`, `DB_PORT`
- **`.env.redis`** — `REDIS_PASSWORD`

## Volúmenes de datos

Cada servicio persiste en su propia carpeta bajo `./data/`, montada por bind mount:

| Servicio | Carpeta host |
|---|---|
| MariaDB | `./data/mariadb-data/db` |
| MySQL 5.7 | `./data/mysql57-data/db` |
| MySQL 8 | `./data/mysql8-data/db` |
| MongoDB | `./data/mongo` |
| PostgreSQL | `./data/postgres_data` |
| Redis | `./data/redis` |

**Nota:** `./data/mariadb-data/db` contiene datos reales en uso (más de 20 bases: `laravel`, `dashboard`, `miflota`, `wordpress`, etc.). Originalmente esos datos vivían en `./data/mysql-data/db`, compartida entre `mariadb.yml` y el compose que hoy es `mysql57.yml` — se separaron para evitar que ambos motores escribieran sobre el mismo volumen. `./data/mysql-data/db` sigue existiendo como copia de respaldo de ese momento, pero ya no la usa ningún compose file de este directorio. `./data/mysql57-data/db` y `./data/mysql8-data/db` son volúmenes nuevos y vacíos, exclusivos de cada uno.

## Notas por servicio

- **mysql57 vs mysql8**: son dos motores/versiones distintas de MySQL corriendo en paralelo, cada uno con su propio volumen, puerto y `.env`. `mysql:5.7` no puede leer el formato InnoDB que escribe MariaDB (ni el que escribe `mysql:8`), por eso ninguno comparte volumen con MariaDB ni entre sí.
- **Mongo**: el usuario root se crea automáticamente solo la primera vez que el volumen de datos está vacío (variables `MONGO_INITDB_ROOT_*`). Si el volumen ya tiene datos previos sin usuarios configurados, hay que crearlo a mano usando la excepción de conexión local que Mongo permite cuando no existe ningún usuario (sustituye `$MONGO_INITDB_ROOT_USERNAME` / `$MONGO_INITDB_ROOT_PASSWORD` por los valores de tu `.env.mongo`):
  ```bash
  docker exec -it mongodb mongosh --quiet admin --eval '
  db.createUser({
    user: "'"$MONGO_INITDB_ROOT_USERNAME"'",
    pwd: "'"$MONGO_INITDB_ROOT_PASSWORD"'",
    roles: [{ role: "root", db: "admin" }]
  })'
  ```

## Verificar que un servicio esté funcional

Carga las variables del `.env.<servicio>` correspondiente en tu shell (o sustitúyelas manualmente) antes de correr esto:

```bash
docker exec mariadb  mariadb  -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"
docker exec mysql57  mysql    -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"
docker exec mysql8   mysql    -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"
docker exec mongodb  mongosh --quiet --eval "db.runCommand({ping:1})" -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin
docker exec postgres pg_isready -U postgres
docker exec redis    redis-cli -a "$REDIS_PASSWORD" ping
```

## Licencia

MIT — ver [LICENSE](./LICENSE).
