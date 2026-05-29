package tag

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
	_ "github.com/lib/pq"
	"github.com/urfave/cli/v2"
	"google.golang.org/genai"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// Taxonomy mirrors the canonical (type, name) pairs locked down by
// migrations/00007_label_taxonomy.sql. Keep these in sync — any value the
// model returns that isn't in this map will be skipped.
var taxonomy = map[string][]string{
	"course": {
		"main", "side", "starter", "dessert", "breakfast", "lunch", "snack",
		"soup", "stew", "salad", "sauce", "bread", "pastry", "drink", "condiment",
	},
	"cuisine": {
		"british", "irish", "german", "french", "spanish", "italian", "greek",
		"mediterranean", "middle_eastern", "indian", "thai", "chinese", "korean",
		"japanese", "vietnamese", "indonesian", "mexican", "american", "moroccan",
		"african", "georgian",
	},
	"diet": {
		"vegetarian", "vegan", "gluten_free", "dairy_free", "egg_free", "nut_free",
		"low_fodmap", "low_carb", "low_calorie",
	},
	"method": {
		"slow_cooked", "baked", "grilled", "fried", "roasted", "raw", "no_cook",
		"fermented", "microwave", "sous_vide", "stir_fry",
	},
}

var Command = &cli.Command{
	Name:  "tag-recipes",
	Usage: "Use Gemini to tag every recipe with the canonical label taxonomy",
	Flags: []cli.Flag{
		&cli.StringFlag{Name: "db-user", EnvVars: []string{"DB_USER"}},
		&cli.StringFlag{Name: "db-pass", EnvVars: []string{"DB_PASS"}},
		&cli.StringFlag{Name: "db-name", EnvVars: []string{"DB_NAME"}},
		&cli.StringFlag{Name: "db-host", EnvVars: []string{"DB_HOST"}},
		&cli.StringFlag{Name: "db-port", EnvVars: []string{"DB_PORT"}},
		&cli.StringFlag{
			Name:    "google-api-key",
			Usage:   "Google AI Studio API key",
			EnvVars: []string{"GOOGLE_API_KEY"},
		},
		&cli.StringFlag{
			Name:  "model",
			Usage: "Gemini model to use",
			Value: "gemini-3.5-flash",
		},
		&cli.BoolFlag{
			Name:  "all",
			Usage: "Re-tag recipes that already have labels (additive — never removes existing tags)",
		},
		&cli.IntFlag{
			Name:  "concurrency",
			Usage: "Number of recipes to tag in parallel",
			Value: 2,
		},
		&cli.IntFlag{
			Name:  "limit",
			Usage: "Stop after tagging this many recipes (0 = no limit)",
			Value: 0,
		},
		&cli.BoolFlag{
			Name:  "dry-run",
			Usage: "Print proposed tags without writing to the database",
		},
	},
	Action: run,
}

type recipeForTagging struct {
	UUID        uuid.UUID
	Name        string
	Description string
	Ingredients []string
}

type geminiResponse struct {
	Course  string   `json:"course"`
	Cuisine []string `json:"cuisine"`
	Diet    []string `json:"diet"`
	Method  []string `json:"method"`
}

func run(c *cli.Context) error {
	log := logger.New(logger.LogLevelInfo)
	ctx := c.Context

	apiKey := c.String("google-api-key")
	if apiKey == "" {
		return fmt.Errorf("GOOGLE_API_KEY is required")
	}

	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		c.String("db-user"), c.String("db-pass"),
		c.String("db-host"), c.String("db-port"),
		c.String("db-name"),
	)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return fmt.Errorf("ping db: %w", err)
	}

	client, err := genai.NewClient(ctx, &genai.ClientConfig{APIKey: apiKey})
	if err != nil {
		return fmt.Errorf("create genai client: %w", err)
	}

	recipes, err := loadRecipes(ctx, db, !c.Bool("all"))
	if err != nil {
		return fmt.Errorf("load recipes: %w", err)
	}
	if limit := c.Int("limit"); limit > 0 && len(recipes) > limit {
		recipes = recipes[:limit]
	}
	log.Info().Int("count", len(recipes)).Msg("Recipes to tag")
	if len(recipes) == 0 {
		return nil
	}

	labelIDs, err := loadLabelIDs(ctx, db)
	if err != nil {
		return fmt.Errorf("load label ids: %w", err)
	}

	cfg := buildGenerateConfig()

	sem := make(chan struct{}, c.Int("concurrency"))
	var wg sync.WaitGroup
	var mu sync.Mutex
	tagged, skipped, failed := 0, 0, 0

	for _, r := range recipes {
		sem <- struct{}{}
		wg.Add(1)
		go func(r recipeForTagging) {
			defer wg.Done()
			defer func() { <-sem }()

			tags, err := callGemini(ctx, client, c.String("model"), cfg, r)
			if err != nil {
				log.Error().Err(err).Str("recipe", r.Name).Msg("Gemini tagging failed")
				mu.Lock()
				failed++
				mu.Unlock()
				return
			}

			labels := normaliseTags(tags)
			if len(labels) == 0 {
				log.Warn().Str("recipe", r.Name).Msg("No valid labels returned")
				mu.Lock()
				skipped++
				mu.Unlock()
				return
			}

			log.Info().
				Str("recipe", r.Name).
				Strs("labels", flattenLabels(labels)).
				Msg("Tagged")

			if c.Bool("dry-run") {
				mu.Lock()
				tagged++
				mu.Unlock()
				return
			}

			if err := applyLabels(ctx, db, r.UUID, labels, labelIDs, &mu); err != nil {
				log.Error().Err(err).Str("recipe", r.Name).Msg("Failed to apply labels")
				mu.Lock()
				failed++
				mu.Unlock()
				return
			}
			mu.Lock()
			tagged++
			mu.Unlock()
		}(r)
	}
	wg.Wait()

	log.Info().
		Int("tagged", tagged).
		Int("skipped", skipped).
		Int("failed", failed).
		Msg("Done")

	if failed > 0 {
		os.Exit(1)
	}
	return nil
}

func loadRecipes(ctx context.Context, db *sql.DB, onlyUntagged bool) ([]recipeForTagging, error) {
	query := `
		SELECT r.uuid, r.name, COALESCE(r.description, ''),
		       COALESCE(
		           ARRAY_AGG(DISTINCT i.name) FILTER (WHERE i.name IS NOT NULL),
		           '{}'
		       ) AS ingredient_names
		FROM recipes r
		LEFT JOIN recipe_ingredient ri ON ri.recipe_id = r.uuid
		LEFT JOIN ingredients i ON i.uuid = ri.ingredient_id
		WHERE r.archived_at IS NULL
	`
	if onlyUntagged {
		query += ` AND NOT EXISTS (SELECT 1 FROM recipe_label rl WHERE rl.recipe_id = r.uuid)`
	}
	query += ` GROUP BY r.uuid ORDER BY r.created_at`

	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []recipeForTagging
	for rows.Next() {
		var r recipeForTagging
		if err := rows.Scan(&r.UUID, &r.Name, &r.Description, pq.Array(&r.Ingredients)); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func loadLabelIDs(ctx context.Context, db *sql.DB) (map[string]uuid.UUID, error) {
	rows, err := db.QueryContext(ctx, `SELECT uuid, type, name FROM labels`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make(map[string]uuid.UUID)
	for rows.Next() {
		var id uuid.UUID
		var typ, name string
		if err := rows.Scan(&id, &typ, &name); err != nil {
			return nil, err
		}
		ids[typ+":"+name] = id
	}
	return ids, rows.Err()
}

func buildGenerateConfig() *genai.GenerateContentConfig {
	courseEnum := taxonomy["course"]
	cuisineEnum := taxonomy["cuisine"]
	dietEnum := taxonomy["diet"]
	methodEnum := taxonomy["method"]

	temp := float32(0.1)
	return &genai.GenerateContentConfig{
		Temperature:      &temp,
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{
			Type:     genai.TypeObject,
			Required: []string{"course", "cuisine", "diet", "method"},
			Properties: map[string]*genai.Schema{
				"course": {
					Type:        genai.TypeString,
					Enum:        courseEnum,
					Description: "The primary course this recipe is. Pick exactly one.",
				},
				"cuisine": {
					Type:        genai.TypeArray,
					Description: "Cuisine(s) the recipe belongs to. Empty if not clearly tied to any.",
					Items:       &genai.Schema{Type: genai.TypeString, Enum: cuisineEnum},
				},
				"diet": {
					Type:        genai.TypeArray,
					Description: "Diets the recipe naturally satisfies. Empty if none apply.",
					Items:       &genai.Schema{Type: genai.TypeString, Enum: dietEnum},
				},
				"method": {
					Type:        genai.TypeArray,
					Description: "Cooking methods used. Empty if none of the listed methods clearly apply.",
					Items:       &genai.Schema{Type: genai.TypeString, Enum: methodEnum},
				},
			},
		},
		SystemInstruction: &genai.Content{
			Role: "system",
			Parts: []*genai.Part{{
				Text: "You categorise recipes against a fixed taxonomy. Only return values from the supplied enums. " +
					"Be conservative: if a recipe isn't clearly tied to a cuisine, diet, or method, return an empty list rather than guessing. " +
					"For 'diet': only include a tag if the recipe genuinely satisfies it as written (no meat = vegetarian; no animal products at all = vegan; etc.).",
			}},
		},
	}
}

func callGemini(
	ctx context.Context,
	client *genai.Client,
	model string,
	cfg *genai.GenerateContentConfig,
	r recipeForTagging,
) (*geminiResponse, error) {
	prompt := fmt.Sprintf(
		"Recipe name: %s\n\nDescription: %s\n\nIngredients: %s\n\nTag this recipe with the appropriate taxonomy values.",
		r.Name,
		strings.TrimSpace(r.Description),
		strings.Join(r.Ingredients, ", "),
	)

	resp, err := client.Models.GenerateContent(ctx, model, []*genai.Content{
		{Role: "user", Parts: []*genai.Part{{Text: prompt}}},
	}, cfg)
	if err != nil {
		return nil, err
	}

	text := strings.TrimSpace(resp.Text())
	if text == "" {
		return nil, fmt.Errorf("empty response")
	}

	var out geminiResponse
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		return nil, fmt.Errorf("decode response %q: %w", text, err)
	}
	return &out, nil
}

// normaliseTags converts the model output into a flat list of (type, name)
// pairs and drops any value not in the canonical taxonomy.
func normaliseTags(g *geminiResponse) map[string][]string {
	out := map[string][]string{}
	add := func(typ, name string) {
		name = strings.ToLower(strings.TrimSpace(name))
		if name == "" {
			return
		}
		for _, allowed := range taxonomy[typ] {
			if allowed == name {
				out[typ] = append(out[typ], name)
				return
			}
		}
	}
	add("course", g.Course)
	for _, v := range g.Cuisine {
		add("cuisine", v)
	}
	for _, v := range g.Diet {
		add("diet", v)
	}
	for _, v := range g.Method {
		add("method", v)
	}
	return out
}

func flattenLabels(labels map[string][]string) []string {
	var out []string
	for typ, names := range labels {
		for _, n := range names {
			out = append(out, typ+":"+n)
		}
	}
	return out
}

func applyLabels(
	ctx context.Context,
	db *sql.DB,
	recipeID uuid.UUID,
	labels map[string][]string,
	labelIDs map[string]uuid.UUID,
	mu *sync.Mutex,
) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			tx.Rollback()
		}
	}()

	now := time.Now()
	for typ, names := range labels {
		for _, name := range names {
			key := typ + ":" + name
			mu.Lock()
			id, ok := labelIDs[key]
			mu.Unlock()
			if !ok {
				// Label row doesn't exist yet (shouldn't happen for taxonomy
				// rows since the migration seeded them, but be defensive for
				// any future additions). Insert it and cache the id.
				id = uuid.New()
				_, err := tx.ExecContext(ctx, `
					INSERT INTO labels (uuid, type, name, created_at, updated_at)
					VALUES ($1, $2, $3, $4, $4)
					ON CONFLICT (type, name) DO UPDATE SET updated_at = EXCLUDED.updated_at
				`, id, typ, name, now)
				if err != nil {
					return fmt.Errorf("insert label %s/%s: %w", typ, name, err)
				}
				// Re-read the canonical id in case of a conflict.
				if err := tx.QueryRowContext(ctx,
					`SELECT uuid FROM labels WHERE type = $1 AND name = $2`,
					typ, name,
				).Scan(&id); err != nil {
					return fmt.Errorf("lookup label %s/%s: %w", typ, name, err)
				}
				mu.Lock()
				labelIDs[key] = id
				mu.Unlock()
			}

			_, err := tx.ExecContext(ctx, `
				INSERT INTO recipe_label (recipe_id, label_id, created_at, updated_at)
				VALUES ($1, $2, $3, $3)
				ON CONFLICT (recipe_id, label_id) DO NOTHING
			`, recipeID, id, now)
			if err != nil {
				return fmt.Errorf("attach label %s/%s: %w", typ, name, err)
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return err
	}
	committed = true
	return nil
}
