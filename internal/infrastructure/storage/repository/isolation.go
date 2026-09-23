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
	var role string
	var super, bypass bool
	err := sqlDB.QueryRowContext(ctx,
		`SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`,
	).Scan(&role, &super, &bypass)
	if err != nil {
		return "", fmt.Errorf("failed to read the connected role's privileges: %w", err)
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
