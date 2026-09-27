package repository

import (
	"context"
	"database/sql"
	"fmt"
)

// TenantTables are the tables home isolation covers; excluded tables decide
// which home a request acts on.
var TenantTables = []string{
	"recipes", "steps", "recipe_ingredient", "recipe_label", "photos",
	"meal_plan_recipes", "ingredients", "pantry_items", "shopping_list_items",
}

// CheckIsolation refuses a connection that would read and write every home
// while every request still looked right — the failure has no other symptom.
func CheckIsolation(ctx context.Context, sqlDB *sql.DB) (string, error) {
	role, super, bypass, err := connectedRole(ctx, sqlDB)
	if err != nil {
		return "", err
	}
	if super || bypass {
		return role, fmt.Errorf(
			"refusing to serve as %q: rolsuper=%t rolbypassrls=%t, so row-level security would not apply — point APP_DB_USER at the non-owner role",
			role, super, bypass,
		)
	}

	for _, table := range TenantTables {
		var enabled, forced bool
		var policies int
		err := sqlDB.QueryRowContext(ctx, `
			SELECT c.relrowsecurity, c.relforcerowsecurity,
			       (SELECT count(*) FROM pg_policy p WHERE p.polrelid = c.oid)
			FROM pg_class c WHERE c.oid = to_regclass('public.' || $1)`, table,
		).Scan(&enabled, &forced, &policies)
		if err != nil {
			return role, fmt.Errorf("failed to read row security settings for %s: %w", table, err)
		}
		if !enabled || !forced || policies == 0 {
			return role, fmt.Errorf(
				"refusing to serve: %s has row security enabled=%t forced=%t with %d policies, so any home could read it — run the migrations",
				table, enabled, forced, policies,
			)
		}
	}

	return role, nil
}

// CheckBypass is the inverse of CheckIsolation, for commands that must read
// every home: on a policy-bound role they would find nothing and exit 0.
func CheckBypass(ctx context.Context, sqlDB *sql.DB) (string, error) {
	role, super, bypass, err := connectedRole(ctx, sqlDB)
	if err != nil {
		return "", err
	}
	if !super && !bypass {
		return role, fmt.Errorf(
			"refusing to run as %q: it holds neither SUPERUSER nor BYPASSRLS, so row-level security would hide every home's rows — point DB_USER at a role that bypasses it",
			role,
		)
	}
	return role, nil
}

func connectedRole(ctx context.Context, sqlDB *sql.DB) (role string, super, bypass bool, err error) {
	err = sqlDB.QueryRowContext(ctx,
		`SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`,
	).Scan(&role, &super, &bypass)
	if err != nil {
		return "", false, false, fmt.Errorf("failed to read the connected role's privileges: %w", err)
	}
	return role, super, bypass, nil
}
