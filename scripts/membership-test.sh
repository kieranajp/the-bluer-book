#!/usr/bin/env bash
# Proves who can reach a home over HTTP, running as bluer_book_app so every read is bound by the deployed policies.

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
  # Over TCP: the image's first-boot init server listens only on the socket, then restarts.
  if docker exec "$CONTAINER" pg_isready --quiet --host 127.0.0.1 --username "$OWNER_USER" --dbname "$DB_NAME"; then
    break
  fi
  sleep 1
done
docker exec "$CONTAINER" pg_isready --host 127.0.0.1 --username "$OWNER_USER" --dbname "$DB_NAME"

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

# link_as TOKEN PATH [curl args] — one read from a linked app, which sends
# no identity of its own.
link_as() {
  local token="$1" path="$2"
  shift 2
  curl --silent --header "Authorization: Bearer ${token}" "$@" "localhost:${API_PORT}${path}"
}

link_status() {
  local token="$1" path="$2"
  shift 2
  link_as "$token" "$path" --output /dev/null --write-out '%{http_code}' "$@"
}

owner_cli() {
  DB_HOST=127.0.0.1 DB_PORT="$PORT" DB_NAME="$DB_NAME" \
    DB_USER="$OWNER_USER" DB_PASS="$OWNER_PASS" \
    "${BUILD_DIR}/server" "$@"
}

recipe_ids() { python3 -c 'import json,sys; print(" ".join(sorted(r[sys.argv[1]] for r in json.load(sys.stdin)["recipes"])))' "$1"; }

echo "==> A link token reads the home it was issued for and nothing else"
new_recipe() {
  local subject="$1" name="$2"
  as "$subject" POST /api/recipes "{
    \"name\": \"${name}\", \"description\": \"seeded for the link checks\", \"servings\": 2,
    \"steps\": [{\"order\": 1, \"description\": \"Cook it\"}],
    \"ingredients\": [{\"ingredient\": {\"name\": \"rice\"}, \"unit\": {\"name\": \"gram\", \"abbreviation\": \"g\"}, \"quantity\": 100}]
  }" | json 'json.load(sys.stdin)["uuid"]'
}

PAELLA_ID=$(as subject-a GET /api/recipes | json 'next(r["uuid"] for r in json.load(sys.stdin)["recipes"] if r["name"] == "Home A Paella")')
TORTILLA_ID=$(new_recipe subject-a "Home A Tortilla")
expect 204 "$(status subject-a POST "/api/recipes/${PAELLA_ID}/meal-plan")" "planning home A's paella"

B_RECIPE_ID=$(HOME_HEADER="$HOME_B" new_recipe subject-b "Home B Risotto")
expect 204 "$(HOME_HEADER="$HOME_B" status subject-b POST "/api/recipes/${B_RECIPE_ID}/meal-plan")" \
  "planning home B's risotto"

LINK_ERR="$(mktemp)"
LINK_TOKEN=$(owner_cli issue-link --home "$HOME_A" 2>"$LINK_ERR")
[ -n "$LINK_TOKEN" ] || fail "issue-link printed no token: $(cat "$LINK_ERR")"
LINK_ID=$(sed -n 's/^Issued link \([0-9a-f-]*\) .*/\1/p' "$LINK_ERR")
rm -f "$LINK_ERR"
[ -n "$LINK_ID" ] || fail "issue-link named no link id"

stored=$(docker exec "$CONTAINER" psql --username "$OWNER_USER" --dbname "$DB_NAME" \
  --no-align --tuples-only --command "SELECT token_hash FROM link_tokens WHERE uuid = '${LINK_ID}'")
expect "$(printf '%s' "$LINK_TOKEN" | sha256sum | cut -d' ' -f1)" "$stored" "the stored link hash"

expect "$(printf '%s\n' "$PAELLA_ID" "$TORTILLA_ID" | sort | xargs)" \
  "$(link_as "$LINK_TOKEN" /link/v1/recipes | recipe_ids id)" "home A's recipe index"
expect "$HOME_A" "$(link_as "$LINK_TOKEN" /link/v1/recipes | json 'json.load(sys.stdin)["home"]["id"]')" \
  "the home the index names"
expect "$PAELLA_ID" "$(link_as "$LINK_TOKEN" /link/v1/meal-plan | recipe_ids uuid)" "home A's meal plan"
expect 200 "$(link_status "$LINK_TOKEN" "/link/v1/recipes/${PAELLA_ID}")" "reading home A's recipe"
expect 404 "$(link_status "$LINK_TOKEN" "/link/v1/recipes/${B_RECIPE_ID}")" "reading home B's recipe"

expect "$(printf '%s\n' "$PAELLA_ID" "$TORTILLA_ID" | sort | xargs)" \
  "$(link_as "$LINK_TOKEN" /link/v1/recipes --header "X-User: subject-b" --header "X-Home: ${HOME_B}" | recipe_ids id)" \
  "home A's index with a forged X-User and X-Home naming B"
expect "$PAELLA_ID" \
  "$(link_as "$LINK_TOKEN" /link/v1/meal-plan --header "X-User: subject-b" --header "X-Home: ${HOME_B}" | recipe_ids uuid)" \
  "home A's meal plan with a forged X-Home naming B"

expect 401 "$(curl --silent --output /dev/null --write-out '%{http_code}' --header "X-User: subject-a" \
  "localhost:${API_PORT}/link/v1/recipes")" "an identity header with no link token"
expect 405 "$(link_status "$LINK_TOKEN" "/link/v1/recipes/${PAELLA_ID}" --request DELETE)" "deleting through a link"

owner_cli revoke-link --id "$LINK_ID" >/dev/null 2>&1 || fail "revoke-link refused ${LINK_ID}"
expect 401 "$(link_status "$LINK_TOKEN" /link/v1/recipes)" "the index once the link is revoked"
expect 401 "$(link_status "$LINK_TOKEN" /link/v1/meal-plan)" "the meal plan once the link is revoked"

# Strips ANSI colour first since the console writer embeds it in the label.
# grep reads to the end, not --quiet, to avoid pipefail on a closed pipe.
sed 's/\x1b\[[0-9;]*m//g' "$SERVER_LOG" | grep "role=${APP_USER}" >/dev/null \
  || fail "the server did not report connecting as ${APP_USER}"

# The access log records every path, so a token in one would sit in the log for
# as long as it stayed redeemable.
for secret in "$TOKEN" "$LINK_TOKEN"; do
  if grep --quiet -- "$secret" "$SERVER_LOG"; then
    fail "a token reached the server log"
  fi
done
echo "    ok  no token reached the log"

echo "==> Homes admit only who they were told to."
