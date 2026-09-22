#!/usr/bin/env bash
# Proves home isolation on a database built from the migrations, running each
# suite as the role it needs: DB_USER, the superuser that owns every table and
# runs migrations, and bluer_book_app, the non-owner role the server connects
# as. Everything created here is removed on exit, including on failure.

set -euo pipefail

cd "$(dirname "$0")/.."

CONTAINER="${RLS_TEST_CONTAINER:-bluer-book-rls-test}"
PORT="${RLS_TEST_PORT:-55433}"
IMAGE="${RLS_TEST_IMAGE:-postgres:17.5-alpine}"
PKG="./internal/infrastructure/storage/repository/..."

OWNER_USER="bluer_book"
OWNER_PASS="rls-test-owner"
APP_USER="bluer_book_app"
APP_PASS="rls-test-app"
DB_NAME="bluer_book"

OWNER_DSN="postgres://${OWNER_USER}:${OWNER_PASS}@127.0.0.1:${PORT}/${DB_NAME}?sslmode=disable"
APP_DSN="postgres://${APP_USER}:${APP_PASS}@127.0.0.1:${PORT}/${DB_NAME}?sslmode=disable"

cleanup() {
  docker rm --force --volumes "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "==> Starting $IMAGE on port $PORT"
docker run --detach --name "$CONTAINER" \
  --env "POSTGRES_USER=${OWNER_USER}" \
  --env "POSTGRES_PASSWORD=${OWNER_PASS}" \
  --env "POSTGRES_DB=${DB_NAME}" \
  --publish "127.0.0.1:${PORT}:5432" \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  if docker exec "$CONTAINER" pg_isready --quiet --username "$OWNER_USER" --dbname "$DB_NAME"; then
    break
  fi
  sleep 1
done
docker exec "$CONTAINER" pg_isready --username "$OWNER_USER" --dbname "$DB_NAME" >/dev/null

echo "==> Generating query stubs"
sqlc generate

# 00001 to 00006 predate goose and carry none of its annotations, so goose
# can't parse them; applying them by hand leaves the schema goose then
# recognises and seeds before running 00007 onwards, matching the deployed path.
echo "==> Applying the pre-goose schema"
for file in migrations/0000[1-6]_*.sql; do
  docker exec --interactive "$CONTAINER" \
    psql --username "$OWNER_USER" --dbname "$DB_NAME" --quiet \
    --set ON_ERROR_STOP=1 < "$file" >/dev/null
done

echo "==> Migrating as ${OWNER_USER}"
DB_HOST=127.0.0.1 DB_PORT="$PORT" DB_NAME="$DB_NAME" \
  DB_USER="$OWNER_USER" DB_PASS="$OWNER_PASS" \
  APP_DB_USER="$APP_USER" APP_DB_PASS="$APP_PASS" \
  go run . migrate

echo "==> Checking ${APP_USER}'s privileges"
attrs=$(docker exec "$CONTAINER" psql --username "$OWNER_USER" --dbname "$DB_NAME" \
  --no-align --tuples-only \
  --command "SELECT rolsuper || '|' || rolbypassrls FROM pg_roles WHERE rolname = '${APP_USER}'")
if [ "$attrs" != "false|false" ]; then
  echo "FAIL: ${APP_USER} reports rolsuper|rolbypassrls = ${attrs:-<no such role>}, want false|false" >&2
  exit 1
fi

# run_suite insists the suite actually ran. A skip is as quiet as a pass and
# says as little, so it fails the script just as a failure does.
run_suite() {
  local label="$1" dsn="$2"
  shift 2

  echo "==> ${label}"
  local output
  if ! output=$(BLUER_BOOK_TEST_DSN="$dsn" go test "$PKG" -v "$@" 2>&1); then
    echo "$output" >&2
    echo "FAIL: ${label}" >&2
    exit 1
  fi
  echo "$output"
  # Reading to the end, not stopping at the match: -q would leave printf
  # writing into a closed pipe, which pipefail reports as a failure of its own.
  if printf '%s' "$output" | grep -- '--- SKIP' >/dev/null; then
    echo "FAIL: ${label} skipped a case. A suite that skips proves nothing." >&2
    exit 1
  fi
  if ! printf '%s' "$output" | grep -- '--- PASS' >/dev/null; then
    echo "FAIL: ${label} ran no tests at all." >&2
    exit 1
  fi
}

run_suite "TestIsolation as ${APP_USER} (must pass)" "$APP_DSN" -run TestIsolation -count=1

echo "==> TestIsolation as ${OWNER_USER} (must fail, on the guard)"
if owner_output=$(BLUER_BOOK_TEST_DSN="$OWNER_DSN" go test "$PKG" -run TestIsolation -count=1 -v 2>&1); then
  echo "FAIL: the isolation suite passed as ${OWNER_USER}, which bypasses every policy." >&2
  echo "      Its role guard is broken, so the run above proved nothing." >&2
  exit 1
fi
# A compile error fails too, and would otherwise read as the guard working.
if ! printf '%s' "$owner_output" | grep 'which holds SUPERUSER or BYPASSRLS' >/dev/null; then
  echo "$owner_output" >&2
  echo "FAIL: the suite failed as ${OWNER_USER}, but not because the role guard fired." >&2
  exit 1
fi

run_suite "TestHomeScoping as ${OWNER_USER} (must pass)" "$OWNER_DSN" \
  -run 'TestHomeScoping|TestHomeScopedPantry' -count=1

run_suite "TestProvision as ${APP_USER} (must pass)" "$APP_DSN" -run TestProvision -count=3

# As ${APP_USER}, not the owner: identity tables carry no RLS policy since a
# token is looked up before either party's home is known, so this is what
# would catch one creeping onto invitations or home_members.
run_suite "TestMembership as ${APP_USER} (must pass)" "$APP_DSN" -run TestMembership -count=3

echo "==> Home isolation holds."
