# OAuth2 API Authentication

This skill describes how OAuth2 API authentication works in this homelab so agents can authenticate against protected services.

## Quick Start: Get a Token and Call an API

```bash
# 1. Get a JWT access token (client_credentials grant)
curl -s -X POST https://hydra.kieranajp.uk/oauth2/token \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=mcp:api"

# 2. Use the token
curl -H "Authorization: Bearer ${TOKEN}" https://mcp.kieranajp.uk/api/endpoint
```

## Architecture

```
Client → Traefik → Oathkeeper (forwardAuth) → Backend Service
                        ↓
              Validates JWT via Hydra JWKS
              Sets X-User header on success
```

Traefik's `ory-auth` middleware forwards every request to Oathkeeper's `/decisions` endpoint. Oathkeeper validates the bearer token's signature against Hydra's JWKS and checks required scopes. On success, the request is proxied with an `X-User` header containing the token subject.

## Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Hydra Public | `https://hydra.kieranajp.uk` | Token endpoint, JWKS |
| Hydra Admin | `https://hydra-admin.kieranajp.uk` | Client management (protected) |
| Oathkeeper Decisions | `http://oathkeeper-api.auth.svc.cluster.local:4456/decisions` | Internal auth decisions |
| JWKS | `https://hydra.kieranajp.uk/.well-known/jwks.json` | Public keys for JWT validation |

### Internal service addresses (in-cluster only)

- Hydra Public: `http://hydra-public:4444`
- Hydra Admin: `http://hydra-admin:4445`
- Oathkeeper Proxy: `http://oathkeeper-proxy:4455`
- Oathkeeper API: `http://oathkeeper-api.auth.svc.cluster.local:4456`

## Token Endpoint Details

**URL**: `POST https://hydra.kieranajp.uk/oauth2/token`
**Auth method**: `client_secret_basic` (HTTP Basic with client_id:client_secret)
**Grant type**: `client_credentials`
**Content-Type**: `application/x-www-form-urlencoded`

**Request body parameters**:
- `grant_type=client_credentials` (required)
- `scope=<space-separated scopes>` (optional, limits token scopes)

**Response** (JSON):
```json
{
  "access_token": "<JWT>",
  "token_type": "bearer",
  "expires_in": 3600,
  "scope": "mcp:api"
}
```

## Adding a New API Client

In `terraform.tfvars`, add to `hydra_oauth_clients`:

```hcl
hydra_oauth_clients = {
  "my-app" = {
    name      = "My App"
    secret    = ""  # Generate with: openssl rand -hex 32
    scopes    = ["my-app:api"]
    url_match = "<https?://my-app\\.kieranajp\\.uk/api(/.*)?>"
  }
}
```

- `url_match` creates an Oathkeeper rule requiring the listed scopes for that URL pattern
- Without `url_match`, the token still works against the generic `/api` rule (no scope check)
- Oathkeeper uses regex: `<pattern>` wraps the regex in `^...$` anchors. Escape dots with `\\.` (double backslash — the value passes through templatefile into single-quoted YAML)

Run `tofu apply` to create the client via a Kubernetes Job that calls `hydra create client`.

## Traefik Setup

Two auth middlewares are available cluster-wide (defined in `values/traefik-middlewares.yaml`, deployed to every namespace via `traefik-middlewares.tf`):

| Middleware | Use for | Forwards to backend |
|------------|---------|-------------------|
| `ory-auth` | Browser-facing routes | `X-User` header |
| `jwt-auth` | API routes where the service needs the token | `X-User` + `Authorization` headers |

Both call the same Oathkeeper `/decisions` endpoint. The difference is only which response headers get forwarded to your backend. Use `jwt-auth` if your app needs to inspect the JWT itself; use `ory-auth` if `X-User` is sufficient.

### IngressRoute patterns

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
spec:
  entryPoints:
    - websecure
  routes:
    # API route — JWT only
    - kind: Rule
      match: {{ printf "%s && PathPrefix(`/api`)" .Values.ingress.match | quote }}
      middlewares:
        - name: jwt-auth
          namespace: auth
      services:
        - name: {{ .Release.Name }}
          port: {{ .Values.service.port }}
    # UI route — browser session auth
    - kind: Rule
      match: {{ .Values.ingress.match | quote }}
      middlewares:
        - name: ory-auth
          namespace: auth
      services:
        - name: {{ .Release.Name }}
          port: {{ .Values.service.port }}
  tls:
    certResolver: letsencrypt
```

## Access Rule Priority

Rules are evaluated in order:

1. **Per-client rules** (`api-{client_id}`) — specific URL + required scopes
2. **`api-bearer-auth`** — any `/api` path, JWT required, no scope enforcement
3. **`browser-auth`** — everything else, tries cookie then JWT, redirects to login on failure

## Headers Set by Oathkeeper

On successful authentication, Oathkeeper adds:
- `X-User`: The token subject (client ID for client_credentials, identity ID for sessions)

Backend services can trust this header since it's set by the auth proxy, not the client.

## Key Files

- `auth.tf` — Hydra, Oathkeeper, Kratos deployments and client provisioning
- `values/hydra.yaml` — Hydra configuration
- `values/oathkeeper.yaml` — Access rules, authenticators, error handlers
- `values/kratos.yaml` — Identity/session configuration
- `values/traefik-middlewares.yaml` — `ory-auth` forwardAuth middleware definition
- `variables.tf` — `hydra_oauth_clients` variable schema
