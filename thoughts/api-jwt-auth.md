# API JWT Auth — Status & Remaining Work

## What's done

### IngressRoute (deployed)
Split into three rules:
- `/mcp` — no auth middleware
- `/api` — `jwt-auth` middleware (Oathkeeper forward-auth)
- Everything else — `ory-auth` middleware (Kratos browser sessions / Google login)

See `charts/bluer-book/templates/ingressroute.yaml`.

### Flutter client
- `AuthInterceptor` added to Dio — fetches a JWT via `client_credentials` grant from Hydra, caches it, auto-retries on 401
- OAuth config: `app/lib/infrastructure/config/oauth_config.dart` (compile-time `--dart-define` values)
- Credentials in `app/env/release.env` (gitignored), populated by GH Actions from secrets

### GH Actions (`release.yml`)
Writes `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` from GH environment secrets into `env/release.env` before `flutter build apk`.

### Hydra OAuth client
Registered as `the-bluer-book` with scope `recipes:api`. Client credentials grant.

## What's broken

The Flutter app gets 200s but the response body is the **Kratos login page**, not recipe data. This means the `jwt-auth` middleware (Oathkeeper) is either not matching the request or is rejecting the token and falling through to Kratos.

### Root cause (suspected)
**Oathkeeper has no access rule** for `https://recipes.kieranajp.uk/api/.*` with a bearer token authenticator.

The `jwt-auth` Traefik middleware forwards to Oathkeeper at:
```
http://oathkeeper-api.auth.svc.cluster.local:4456/decisions
```

Oathkeeper needs an access rule that:
1. **Matches** requests to `<https://recipes.kieranajp.uk/api/.*>` (or equivalent)
2. **Authenticates** via `oauth2_introspection` (validates the bearer token against Hydra)
3. **Authorises** — `allow` is fine for now (single-user app)
4. **Mutates** — passes `Authorization` and/or `X-User` headers downstream

### What the rule should look like (roughly)
```json
{
  "id": "bluer-book-api",
  "match": {
    "url": "<https://recipes.kieranajp.uk/api/<.*>>",
    "methods": ["GET", "POST", "PUT", "DELETE"]
  },
  "authenticators": [
    { "handler": "oauth2_introspection" }
  ],
  "authorizer": {
    "handler": "allow"
  },
  "mutators": [
    { "handler": "header" }
  ]
}
```

The `oauth2_introspection` authenticator needs to be configured in Oathkeeper's global config to point at Hydra's admin introspection endpoint (`/admin/oauth2/introspect`), with the required scope `recipes:api`.

## Files changed
- `charts/bluer-book/templates/ingressroute.yaml`
- `app/lib/infrastructure/config/oauth_config.dart` (new)
- `app/lib/infrastructure/network/auth_interceptor.dart` (new)
- `app/lib/infrastructure/network/api_client.dart` (modified)
- `app/env/release.env` (modified, gitignored)
- `.github/workflows/release.yml` (modified)

## Next steps
1. Add Oathkeeper access rule in IaC repo for `recipes.kieranajp.uk/api/*`
2. Ensure `oauth2_introspection` authenticator is enabled in Oathkeeper config
3. Redeploy Oathkeeper
4. Test from Flutter — should see actual recipe JSON instead of Kratos login redirect
