#!/usr/bin/env bash
# Proves who can reach a home over HTTP against an enforcing database: an
# invitation admits one person to one home, X-Home names a home rather than
# taking one, and a stranger naming another home is refused. Runs as
# bluer_book_app, so every read is bound by the policies as deployed.

# Requires a recipe already in home A — the run stops if it's missing, since
# an empty result would make every assertion trivially true.

set -euo pipefail

cd "$(dirname "$0")/.."

CONTAINER="${MEMBERSHIP_TEST_CONTAINER:-bluer-book-membership-test}"
PORT="${MEMBERSHIP_TEST_PORT:-55434}"
API_PORT="${MEMBERSHIP_TEST_API_PORT:-18099}"
MCP_PORT="${MEMBERSHIP_TEST_MCP_PORT:-18082}"
IMAGE="${MEMBERSHIP_TEST_IMAGE:-postgres:17.5-alpine}"

OWNER_USER="bluer_book"
OWNER_PASS="membership-test-owner"
APP_USER="bluer_book_app"
APP_PASS="membership-test-app"
DB_NAME="bluer_book"

FOUNDER_HOME="00000000-0000-0000-0000-000000000001"
SERVER_LOG="$(mktemp)"
BUILD_DIR="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  docker rm --force --volumes "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$SERVER_LOG" "$BUILD_DIR"
}
trap cleanup EXIT
cleanup

fail() {
  echo "FAIL: $*" >&2
  echo "--- server log ---" >&2
  cat "$SERVER_LOG" >&2
  exit 1
}

# A leftover server on this port would answer everything below, against whatever
# database it was started with. Refusing beats reporting on somebody else's run.
if curl --silent --fail --max-time 2 "localhost:${API_PORT}/health" >/dev/null 2>&1; then
  echo "FAIL: something is already serving on ${API_PORT}; this run would test it instead" >&2
  exit 1
fi

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

# 00001 to 00006 predate goose, as scripts/rls-test.sh explains at length.
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
  go run . migrate >/dev/null

echo "==> Serving as ${APP_USER}"
# Built rather than `go run`, which leaves its compiled child listening when
# the wrapper is killed. GOOGLE_API_KEY only needs to build; nothing here calls it.
go build -o "${BUILD_DIR}/server" .
DB_HOST=127.0.0.1 DB_PORT="$PORT" DB_NAME="$DB_NAME" \
  DB_USER="$OWNER_USER" DB_PASS="$OWNER_PASS" \
  APP_DB_USER="$APP_USER" APP_DB_PASS="$APP_PASS" \
  GOOGLE_API_KEY="membership-test-not-a-real-key" \
  FOUNDER_SUBJECT="subject-a" \
  LISTEN_ADDR="127.0.0.1:${API_PORT}" MCP_ADDR="127.0.0.1:${MCP_PORT}" \
  "${BUILD_DIR}/server" server > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 90); do
  curl --silent --fail "localhost:${API_PORT}/health" >/dev/null 2>&1 && break
  kill -0 "$SERVER_PID" 2>/dev/null || fail "the server exited before it listened"
  sleep 1
done
curl --silent --fail "localhost:${API_PORT}/health" >/dev/null || fail "the server never listened"

# as SUBJECT METHOD PATH [body] — one request from one caller, optionally
# naming a home through X-Home.
as() {
  local subject="$1" method="$2" path="$3" body="${4:-}"
  local args=(--silent --request "$method" --header "X-User: ${subject}")
  [ -n "${HOME_HEADER:-}" ] && args+=(--header "X-Home: ${HOME_HEADER}")
  [ -n "$body" ] && args+=(--header 'Content-Type: application/json' --data "$body")
  curl "${args[@]}" "localhost:${API_PORT}${path}"
}

status() {
  local subject="$1" method="$2" path="$3" body="${4:-}"
  local args=(--silent --output /dev/null --write-out '%{http_code}'
              --request "$method" --header "X-User: ${subject}")
  [ -n "${HOME_HEADER:-}" ] && args+=(--header "X-Home: ${HOME_HEADER}")
  [ -n "$body" ] && args+=(--header 'Content-Type: application/json' --data "$body")
  curl "${args[@]}" "localhost:${API_PORT}${path}"
}

expect() {
  local want="$1" got="$2" what="$3"
  if [ "$want" != "$got" ]; then
    fail "${what}: got ${got}, want ${want}"
  fi
  echo "    ok  ${what} — ${got}"
}

json() { python3 -c "import json,sys; print($1)"; }

recipe_count() { as "$1" GET /api/recipes | json 'json.load(sys.stdin)["total"]'; }

echo "==> The founder lands in the home that holds the collection"
HOME_A=$(as subject-a GET /api/me | json 'json.load(sys.stdin)["active_home_id"]')
expect "$FOUNDER_HOME" "$HOME_A" "subject-a's active home"

echo "==> That home holds something worth reading"
as subject-a POST /api/recipes '{
  "name": "Home A Paella",
  "description": "only home A should see this",
  "servings": 2,
  "steps": [{"order": 1, "description": "Cook the rice"}],
  "ingredients": [{"ingredient": {"name": "paella rice"},
                   "unit": {"name": "gram", "abbreviation": "g"},
                   "quantity": 300}]
}' >/dev/null
expect 1 "$(recipe_count subject-a)" "recipes in home A"

echo "==> An invitation hands back a token the database does not hold"
INVITE=$(as subject-a POST "/api/homes/${HOME_A}/invitations" '{"email": "b@example.com"}')
TOKEN=$(printf '%s' "$INVITE" | json 'json.load(sys.stdin)["token"]')
[ -n "$TOKEN" ] || fail "the invitation carried no token"

plaintext_rows=$(docker exec "$CONTAINER" psql --username "$OWNER_USER" --dbname "$DB_NAME" \
  --no-align --tuples-only \
  --command "SELECT count(*) FROM invitations WHERE token_hash = '${TOKEN}'")
expect 0 "$plaintext_rows" "invitation rows holding the token as sent"

stored=$(docker exec "$CONTAINER" psql --username "$OWNER_USER" --dbname "$DB_NAME" \
  --no-align --tuples-only --command "SELECT token_hash FROM invitations")
expect "$(printf '%s' "$TOKEN" | sha256sum | cut -d' ' -f1)" "$stored" "the stored hash"

echo "==> Naming a home you are not in is refused, not served"
expect 403 "$(HOME_HEADER="$HOME_A" status subject-b GET /api/recipes)" \
  "subject-b naming home A before accepting"

echo "==> Accepting admits exactly once"
accepted=$(as subject-b POST /api/invitations/accept "{\"token\": \"${TOKEN}\"}" \
  | json 'json.load(sys.stdin)["home"]["uuid"]')
expect "$HOME_A" "$accepted" "the home subject-b joined"
expect 409 "$(status subject-b POST /api/invitations/accept "{\"token\": \"${TOKEN}\"}")" \
  "replaying the token"

echo "==> X-Home names a home rather than taking one"
# Accepting made home A subject-b's most recent, so a single read of home A
# would pass with the header ignored. These two differ only in the header.
HOME_B=$(as subject-b GET /api/me \
  | python3 -c 'import json,sys; print(next(h["uuid"] for h in json.load(sys.stdin)["homes"] if h["uuid"] != sys.argv[1]))' "$HOME_A")
expect 0 "$(HOME_HEADER="$HOME_B" recipe_count subject-b)" "recipes subject-b sees in its own home"
expect 1 "$(HOME_HEADER="$HOME_A" recipe_count subject-b)" "recipes subject-b sees in home A"

echo "==> A stranger gets nothing, whichever home they name"
expect 403 "$(HOME_HEADER="$HOME_A" status subject-c GET /api/recipes)" "subject-c naming home A"
expect 0 "$(recipe_count subject-c)" "recipes subject-c sees at all"

# The assistant reaches its tools through an MCP server pinned to one home, so
# it answers for that home whoever asks. Only its own home may reach it.
echo "==> The assistant is reachable only from the home it acts on"
expect 403 "$(status subject-c POST /api/chat '{"message": "what is in my book?"}')" \
  "subject-c reaching the assistant from their own home"
expect 403 "$(HOME_HEADER="$HOME_B" status subject-b POST /api/chat '{"message": "what is in my book?"}')" \
  "subject-b reaching the assistant from their own home"

echo "==> An unusable X-Home is refused before anybody is resolved"
expect 400 "$(HOME_HEADER='not-a-uuid' status subject-a GET /api/recipes)" "a home id that does not parse"
expect 400 "$(HOME_HEADER='00000000-0000-0000-0000-000000000000' status subject-a GET /api/recipes)" "the nil home id"

echo "==> Membership is the owner's to change"
expect 403 "$(status subject-b POST "/api/homes/${HOME_A}/invitations" '{"email": "d@example.com"}')" \
  "subject-b inviting"

members=$(as subject-a GET "/api/homes/${HOME_A}/members")
expect 2 "$(printf '%s' "$members" | json 'json.load(sys.stdin)["total"]')" "members of home A"
OWNER_ID=$(printf '%s' "$members" | python3 -c 'import json,sys; print(next(m["user_id"] for m in json.load(sys.stdin)["members"] if m["role"] == "owner"))')
MEMBER_ID=$(printf '%s' "$members" | python3 -c 'import json,sys; print(next(m["user_id"] for m in json.load(sys.stdin)["members"] if m["role"] != "owner"))')

expect 409 "$(status subject-a DELETE "/api/homes/${HOME_A}/members/${OWNER_ID}")" \
  "the last owner removing itself"
expect 204 "$(status subject-a DELETE "/api/homes/${HOME_A}/members/${MEMBER_ID}")" \
  "the owner removing the member"
expect 403 "$(HOME_HEADER="$HOME_A" status subject-b GET /api/recipes)" \
  "subject-b naming home A once removed"

# Strips ANSI colour first, since the console writer separates the role from
# its label in the bytes. grep reads to the end, not --quiet, since sed writing
# into a closed pipe would otherwise report as pipefail failing the check.
sed 's/\x1b\[[0-9;]*m//g' "$SERVER_LOG" | grep "role=${APP_USER}" >/dev/null \
  || fail "the server did not report connecting as ${APP_USER}"

# The access log records every path, so a token in one would sit in the log for
# as long as it stayed redeemable.
if grep --quiet "$TOKEN" "$SERVER_LOG"; then
  fail "the invitation token reached the server log"
fi
echo "    ok  the token never reached the log"

echo "==> Homes admit only who they were told to."
