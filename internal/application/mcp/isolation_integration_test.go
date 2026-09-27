package mcp

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http/httptest"
	"os"
	"slices"
	"testing"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/mark3labs/mcp-go/client"
	mcplib "github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

// requireRestrictedRole fails, never skips, on a connection the isolation
// policy would not bind: every read below would then see every home.
func requireRestrictedRole(t *testing.T, sqlDB *sql.DB) {
	t.Helper()

	var role string
	var privileged, owns bool
	if err := sqlDB.QueryRow(`
		SELECT r.rolname, r.rolsuper OR r.rolbypassrls, pg_get_userbyid(c.relowner) = current_user
		FROM pg_roles r, pg_class c
		WHERE r.rolname = current_user AND c.oid = to_regclass('public.ingredients')`,
	).Scan(&role, &privileged, &owns); err != nil {
		t.Fatalf("read the connected role's privileges: %v", err)
	}
	if privileged {
		t.Fatalf("connected as %q, which holds SUPERUSER or BYPASSRLS: point BLUER_BOOK_TEST_DSN at the application role", role)
	}
	if owns {
		t.Fatalf("connected as %q, which owns ingredients: point BLUER_BOOK_TEST_DSN at the application role", role)
	}
}

// seedHome creates a home holding the named ingredients. Deleting the home
// afterwards cascades to them.
func seedHome(t *testing.T, sqlDB *sql.DB, name string, ingredients ...string) uuid.UUID {
	t.Helper()

	home := uuid.New()
	if _, err := sqlDB.Exec(`INSERT INTO homes (uuid, name) VALUES ($1, $2)`, home, name); err != nil {
		t.Fatalf("create home %s: %v", name, err)
	}
	t.Cleanup(func() {
		if _, err := sqlDB.Exec(`DELETE FROM homes WHERE uuid = $1`, home); err != nil {
			t.Errorf("clean up home %s: %v", name, err)
		}
	})

	tx, err := sqlDB.Begin()
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`SELECT set_config('app.home_id', $1, true)`, home.String()); err != nil {
		t.Fatalf("publish home %s: %v", name, err)
	}
	for _, ingredient := range ingredients {
		if _, err := tx.Exec(`INSERT INTO ingredients (name) VALUES ($1)`, ingredient); err != nil {
			t.Fatalf("seed %q into %s: %v", ingredient, name, err)
		}
	}
	if err := tx.Commit(); err != nil {
		t.Fatalf("commit seed for %s: %v", name, err)
	}
	return home
}

// listIngredientsOverHTTP calls list_ingredients through the same pinned HTTP
// server the binary runs, with a real MCP client on the other end.
func listIngredientsOverHTTP(t *testing.T, sqlDB *sql.DB, home uuid.UUID) []string {
	t.Helper()

	log := logger.New(logger.LogLevelError)
	recipes := service.NewRecipeService(repository.NewRecipeRepository(sqlDB, log), metrics.NewRecipeProbe(log))
	mcpServer := server.NewMCPServer("isolation test", "0.0.0", server.WithToolCapabilities(true))
	NewRecipeMCPHandler(recipes, nil, log).RegisterTools(mcpServer)

	httpServer := httptest.NewServer(NewPinnedHTTPServer(mcpServer, home))
	defer httpServer.Close()

	ctx := context.Background()
	c, err := client.NewStreamableHttpClient(httpServer.URL)
	if err != nil {
		t.Fatalf("create MCP client: %v", err)
	}
	defer c.Close()
	if err := c.Start(ctx); err != nil {
		t.Fatalf("start MCP client: %v", err)
	}
	init := mcplib.InitializeRequest{}
	init.Params.ProtocolVersion = mcplib.LATEST_PROTOCOL_VERSION
	init.Params.ClientInfo = mcplib.Implementation{Name: "isolation test", Version: "0.0.0"}
	if _, err := c.Initialize(ctx, init); err != nil {
		t.Fatalf("initialize MCP session: %v", err)
	}

	call := mcplib.CallToolRequest{}
	call.Params.Name = "list_ingredients"
	result, err := c.CallTool(ctx, call)
	if err != nil {
		t.Fatalf("call list_ingredients: %v", err)
	}
	if result.IsError || len(result.Content) != 1 {
		t.Fatalf("list_ingredients answered %+v, want one text result", result.Content)
	}
	text, ok := mcplib.AsTextContent(result.Content[0])
	if !ok {
		t.Fatalf("list_ingredients answered %T, want text", result.Content[0])
	}

	var body struct {
		Ingredients []struct {
			Name string `json:"name"`
		} `json:"ingredients"`
	}
	if err := json.Unmarshal([]byte(text.Text), &body); err != nil {
		t.Fatalf("decode %q: %v", text.Text, err)
	}
	names := make([]string, len(body.Ingredients))
	for i, ingredient := range body.Ingredients {
		names[i] = ingredient.Name
	}
	slices.Sort(names)
	return names
}

func TestIsolationMCPListIngredients(t *testing.T) {
	dsn := os.Getenv("BLUER_BOOK_TEST_DSN")
	if dsn == "" {
		t.Skip("BLUER_BOOK_TEST_DSN not set")
	}
	sqlDB, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { sqlDB.Close() })
	requireRestrictedRole(t, sqlDB)

	homes := map[uuid.UUID][]string{}
	homeA := seedHome(t, sqlDB, "mcp isolation A", "mcp isolation anise", "mcp isolation allspice")
	homes[homeA] = []string{"mcp isolation allspice", "mcp isolation anise"}
	homeB := seedHome(t, sqlDB, "mcp isolation B", "mcp isolation basil")
	homes[homeB] = []string{"mcp isolation basil"}

	// Pinning each home in turn shows the empty case is not what passes.
	for home, want := range homes {
		if got := listIngredientsOverHTTP(t, sqlDB, home); !slices.Equal(got, want) {
			t.Errorf("MCP pinned to %s listed %v, want only its own %v", home, got, want)
		}
	}
}
