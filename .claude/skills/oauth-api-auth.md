# OAuth2 API Authentication

This skill describes how OAuth2 API authentication works in this homelab so agents can authenticate against protected services.

> **Provider: Authentik.** Tokens are now issued by Authentik (`https://auth.kieranajp.uk`),
> which replaced Ory Hydra — RS256-signed and validatable against Authentik's
> per-application JWKS. The infra-side provisioning (Terraform, the Authentik
> provider/application definitions) is maintained in the infra repository.
>
> **The Ory stack (Oathkeeper/Kratos) is being retired.** API routes are now validated by
> a Traefik `auth-token` middleware (`namespace: auth`, backed by the traefik-jwt-plugin)
> that checks the token's RS256 signature against the relevant Authentik JWKS and injects
> the `X-User` header (the JWT `sub`) — same ergonomics as the old `jwt-auth` middleware,
> so backends need no change. The Oathkeeper-specific detail in the "Architecture",
> "Traefik Setup" and "Access Rule Priority" sections below is historical; the current
> wiring lives in the infra repo.

## Quick Start: Get a Token and Call an API

```bash
# 1. Get a JWT access token (client_credentials grant)
curl -s -X POST https://auth.kieranajp.uk/application/o/token/ \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=mcp:api"

# 2. Use the token
curl -H "Authorization: Bearer ${TOKEN}" https://mcp.kieranajp.uk/api/endpoint
```

## Architecture

```
Client → Traefik → Oathkeeper (forwardAuth) → Backend Service
                        ↓
              Validates JWT via Authentik JWKS
              Sets X-User header on success
```

Traefik's `ory-auth` middleware forwards every request to Oathkeeper's `/decisions` endpoint. Oathkeeper validates the bearer token's signature against Authentik's JWKS and checks required scopes. On success, the request is proxied with an `X-User` header containing the token subject.

## Endpoints

Authentik exposes OAuth2/OIDC endpoints under `https://auth.kieranajp.uk/application/o/`.
JWKS and OIDC discovery are **per application** (path segment = the application slug, e.g.
`the-bluer-book`).

| Service | URL | Purpose |
|---------|-----|---------|
| Authorization | `https://auth.kieranajp.uk/application/o/authorize/` | Authorization endpoint (auth-code + PKCE) |
| Token | `https://auth.kieranajp.uk/application/o/token/` | Token endpoint |
| JWKS | `https://auth.kieranajp.uk/application/o/<app-slug>/jwks/` | Public keys for JWT validation |
| OIDC discovery | `https://auth.kieranajp.uk/application/o/<app-slug>/.well-known/openid-configuration` | Endpoint discovery |
| Oathkeeper Decisions | `http://oathkeeper-api.auth.svc.cluster.local:4456/decisions` | Internal auth decisions |

For the-bluer-book, `<app-slug>` is `the-bluer-book`.

## Token Endpoint Details

**URL**: `POST https://auth.kieranajp.uk/application/o/token/`
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

Clients are now Authentik OAuth2 providers/applications, provisioned via Terraform in the
**infra repository** (e.g. an `authentik_provider_oauth2` + `authentik_application` pair
such as `authentik_provider_oauth2.the_bluer_book`). Read the client ID and client secret
from that resource's output (or the Authentik UI). See the infra repo for the exact
resource schema and how scopes/URL matches map onto Oathkeeper access rules.

- The client ID and client secret are surfaced by the Authentik provider resource — don't
  hand-generate them.
- Oathkeeper access rules (which URLs require which scopes) continue to live in the infra
  repo's Oathkeeper config; the token's scopes/audience are set on the Authentik provider.

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

## Key Files (infra repository)

- `auth.tf` — Authentik, Oathkeeper, Kratos deployments and OAuth2 provider/application provisioning
- `values/oathkeeper.yaml` — Access rules, authenticators, error handlers
- `values/kratos.yaml` — Identity/session configuration
- `values/traefik-middlewares.yaml` — `ory-auth` forwardAuth middleware definition
- `authentik_provider_oauth2.the_bluer_book` — the-bluer-book's OAuth2 provider (client ID/secret output)
