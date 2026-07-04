# Glossary

Canonical terms for The Bluer Book. One short paragraph per term, alphabetised. Cross-references in *italics*.

## Authenticated identity
A *user identity* present on a request, established by validating a Hydra-issued JWT (for Flutter and MCP, via OAuth 2.1 Authorization Code + PKCE) or a Kratos session cookie (for the browser-rendered web UI). Both flows resolve to the same Kratos `sub`, which is the canonical user identifier stored as `created_by_user_id` / `cooked_by_user_id` etc. There is no longer an "app identity" — the previous Hydra `client_credentials` grant for the Flutter app is retired in favour of user-bound tokens.

## Hedged workspace
A `workspace_id` column added to every domain table from the point of *household* introduction onwards, hardcoded to a single constant value. No invites, permissions UI, row-level security, or workspace switcher is built around it. Purpose: cheap optionality against a future multi-tenant product pivot — the column is the only part of multi-tenancy whose retrofit cost meaningfully drops if done upfront. Compare with *workspace (deferred)*.

## Household
The chosen scope for multi-user support: one shared recipe book for a small fixed set of co-resident users (currently Kieran + Edele). Identity is attached to writes for attribution ("edited by Kieran", "cooked by Edele on …") but reads are not partitioned and no permissions model exists. Distinct from *workspace (deferred)* and from a SaaS *tenant* model.

## Workspace (deferred)
Hypothetical future grouping enabling multi-tenant operation: multiple independent *households* on one deployment, with membership, invites, role-based access, and isolation enforcement. Not being built. The *hedged workspace* column exists to keep the option open without committing to the feature.
