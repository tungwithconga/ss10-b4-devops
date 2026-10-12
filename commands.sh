#!/usr/bin/env bash
set -euo pipefail

NETWORK=app-net
VOLUME=db-data
DB_CONTAINER=db-server
APP_CONTAINER=app-container
DB_USER=appuser
DB_PASSWORD=app123456
DB_NAME=appdb

create_resources() {
  docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create --driver bridge "$NETWORK"
  docker volume inspect "$VOLUME" >/dev/null 2>&1 || docker volume create "$VOLUME"
}

start_db() {
  if docker container inspect "$DB_CONTAINER" >/dev/null 2>&1; then
    echo "$DB_CONTAINER already exists; remove it before recreating."
    return 0
  fi
  docker run -d --name "$DB_CONTAINER" --network "$NETWORK" \
    -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$DB_PASSWORD" -e POSTGRES_DB="$DB_NAME" \
    -v "$VOLUME":/var/lib/postgresql/data postgres:15-alpine
  echo 'Waiting for PostgreSQL readiness...'
  for i in $(seq 1 45); do
    if docker exec "$DB_CONTAINER" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
      echo 'PostgreSQL ready.'; return 0
    fi
    sleep 2
  done
  echo 'PostgreSQL did not become ready; inspect docker logs db-server' >&2
  exit 1
}

start_app() {
  if docker container inspect "$APP_CONTAINER" >/dev/null 2>&1; then
    echo "$APP_CONTAINER already exists; remove it before recreating."
    return 0
  fi
  # Uses the backend image built in exercise 2. The sample backend has no DB client;
  # environment variables demonstrate configuration and DNS tests prove connectivity.
  docker run -d --name "$APP_CONTAINER" --network "$NETWORK" \
    -e DB_HOST="$DB_CONTAINER" -e DB_PORT=5432 -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" -e DB_NAME="$DB_NAME" \
    -p 8082:3000 hw-backend:v1
}

insert_data() {
  docker exec "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c 'CREATE TABLE IF NOT EXISTS persistence_test (id INTEGER PRIMARY KEY, note TEXT NOT NULL);'
  docker exec "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "INSERT INTO persistence_test (id,note) VALUES (1,'Data survives container recreation') ON CONFLICT (id) DO UPDATE SET note=EXCLUDED.note;"
  show_data
}

show_data() {
  docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c 'SELECT * FROM persistence_test;'
}

case "${1:-up}" in
  up) create_resources; start_db; start_app ;;
  insert) insert_data ;;
  recreate-db) docker rm -f "$DB_CONTAINER"; start_db; show_data ;;
  verify) docker network inspect "$NETWORK" --format '{{json .Containers}}'; docker volume inspect "$VOLUME" --format '{{.Name}}'; show_data ;;
  *) echo 'Usage: bash commands.sh [up|insert|recreate-db|verify]' >&2; exit 2 ;;
esac
