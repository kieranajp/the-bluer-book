// Package proposemerges is a development-only utility. It asks Gemini which
// ingredient names in the book refer to the same thing and writes the answer to
// a JSON file for a human to review, so the reviewed mapping can be baked into
// a migration as a literal table (the shape 00007 used for labels).
//
// Deliberately NOT wired into the Helm initContainer chain the way tag-recipes
// is: merging ingredients is one-way and destructive, so it must never run
// unattended against production data. The migration it feeds is deterministic;
// this command is not.
package proposemerges

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/urfave/cli/v2"
	"google.golang.org/genai"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// formWords distinguish genuinely different shopping items that share a head
// noun. "ground coriander" is a spice and "fresh coriander" is a herb; "cumin
// seeds" and "ground cumin" are not interchangeable. The model is told this,
// and validateMerges enforces it regardless of what comes back — a wrong merge
// here silently rewrites recipes.
var formWords = []string{
	"ground", "whole", "fresh", "dried", "frozen", "tinned", "canned",
	"smoked", "raw", "cooked", "roasted", "toasted",
	"seeds", "powder", "flakes", "leaves", "paste", "puree", "purée",
	"juice", "zest", "extract", "sauce", "stock", "oil", "butter", "milk",
}

var Command = &cli.Command{
	Name:  "propose-ingredient-merges",
	Usage: "Dev-only: ask Gemini which ingredient names duplicate each other, for review before baking into a migration",
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
			Name:    "model",
			Usage:   "Gemini model to use",
			EnvVars: []string{"GEMINI_MODEL"},
			Value:   "gemini-3.5-flash",
		},
		&cli.StringFlag{
			Name:  "out",
			Usage: "Where to write the proposed mapping",
			Value: "migrations/data/ingredient_merges.json",
		},
		&cli.BoolFlag{
			Name:  "dry-run",
			Usage: "Print the proposals instead of writing the file",
		},
		&cli.StringFlag{
			Name:  "home",
			Usage: "Home UUID to propose merges for. Required: ingredients are per home (00012), and as the superuser there is no default app.home_id to fall back to — without this the prompt mixes every household's book.",
		},
	},
	Action: run,
}

type ingredient struct {
	Canonical string `json:"canonical"`
	Name      string `json:"name"`
	Uses      int    `json:"uses"`
}

// Merge proposes that `From` is the same shopping item as `To`. A count
// qualifier on the name ("garlic cloves") is not part of the proposal: it
// becomes the recipe line's unit at write time, so the migration retires the
// name alone. Only preparation-like qualifiers ("medium onion" → preparation
// "medium") come through here.
type Merge struct {
	From        string `json:"from"`
	To          string `json:"to"`
	Preparation string `json:"preparation,omitempty"`
	Reason      string `json:"reason,omitempty"`
}

// UnitFix flags a `units` row that is really a size or an instruction —
// "large", "to taste" — rather than a measure. 00008 consolidated unit spelling
// but never questioned whether the values were units at all.
type UnitFix struct {
	Unit string `json:"unit"`
	Kind string `json:"kind"`
}

type proposal struct {
	Merges    []Merge   `json:"merges"`
	UnitFixes []UnitFix `json:"unitFixes"`
}

type geminiResponse struct {
	Merges []struct {
		From        string `json:"from"`
		To          string `json:"to"`
		Preparation string `json:"preparation"`
		Reason      string `json:"reason"`
	} `json:"merges"`
	UnitFixes []struct {
		Unit string `json:"unit"`
		Kind string `json:"kind"`
	} `json:"unitFixes"`
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
	home := c.String("home")
	if home == "" {
		return fmt.Errorf("--home is required: ingredients are per home, and the migration the output feeds is per home too")
	}
	if _, err := uuid.Parse(home); err != nil {
		return fmt.Errorf("--home must be a UUID: %w", err)
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := db.PingContext(ctx); err != nil {
		return err
	}

	// The proposal feeds a migration whose merges resolve per home, so the
	// candidate list is scoped the same way: publish the home for RLS and
	// filter by the column for anything (like a superuser) the policy cannot.
	if _, err := db.ExecContext(ctx, `SELECT set_config('app.home_id', $1, true)`, home); err != nil {
		return fmt.Errorf("set app.home_id: %w", err)
	}

	ingredients, err := loadIngredients(ctx, db, home)
	if err != nil {
		return fmt.Errorf("load ingredients: %w", err)
	}
	if len(ingredients) == 0 {
		return fmt.Errorf("no ingredients in home %s — check the id against the homes table", home)
	}
	units, err := loadUnits(ctx, db)
	if err != nil {
		return fmt.Errorf("load units: %w", err)
	}
	log.Info().Str("home", home).Int("ingredients", len(ingredients)).Int("units", len(units)).Msg("Loaded")

	client, err := genai.NewClient(ctx, &genai.ClientConfig{APIKey: apiKey})
	if err != nil {
		return err
	}

	// One call with the whole list: duplicates can only be spotted by seeing
	// every name at once, so chunking would miss cross-chunk pairs.
	raw, err := callGemini(ctx, client, c.String("model"), ingredients, units)
	if err != nil {
		return fmt.Errorf("gemini: %w", err)
	}

	merges, rejected := validateMerges(raw, ingredients)
	for _, r := range rejected {
		log.Warn().Str("reason", r.why).Msgf("Rejected %q -> %q", r.merge.From, r.merge.To)
	}

	out := proposal{Merges: merges, UnitFixes: validateUnitFixes(raw, units)}
	log.Info().
		Int("merges", len(out.Merges)).
		Int("rejected", len(rejected)).
		Int("unit_fixes", len(out.UnitFixes)).
		Msg("Proposed")

	encoded, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return err
	}
	if c.Bool("dry-run") {
		fmt.Println(string(encoded))
		return nil
	}

	path := c.String("out")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(path, append(encoded, '\n'), 0o644); err != nil {
		return err
	}
	log.Info().Str("path", path).Msg("Wrote proposals — review and edit before baking into a migration")
	return nil
}

func loadIngredients(ctx context.Context, db *sql.DB, home string) ([]ingredient, error) {
	rows, err := db.QueryContext(ctx, `
		SELECT i.canonical_name, i.name, count(ri.recipe_id)::int AS uses
		FROM ingredients i
		LEFT JOIN recipe_ingredient ri ON ri.ingredient_id = i.uuid
		WHERE i.home_id = $1::uuid
		GROUP BY i.uuid, i.canonical_name, i.name
		ORDER BY i.canonical_name
	`, home)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []ingredient
	for rows.Next() {
		var i ingredient
		if err := rows.Scan(&i.Canonical, &i.Name, &i.Uses); err != nil {
			return nil, err
		}
		out = append(out, i)
	}
	return out, rows.Err()
}

func loadUnits(ctx context.Context, db *sql.DB) ([]string, error) {
	rows, err := db.QueryContext(ctx, `SELECT name FROM units ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func buildGenerateConfig() *genai.GenerateContentConfig {
	temp := float32(0.0)
	return &genai.GenerateContentConfig{
		Temperature:      &temp,
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{
			Type:     genai.TypeObject,
			Required: []string{"merges", "unitFixes"},
			Properties: map[string]*genai.Schema{
				"merges": {
					Type:        genai.TypeArray,
					Description: "Pairs of names that are the same shopping item. Empty if none are.",
					Items: &genai.Schema{
						Type:     genai.TypeObject,
						Required: []string{"from", "to", "preparation", "reason"},
						Properties: map[string]*genai.Schema{
							"from": {Type: genai.TypeString, Description: "The name to retire. Must be one of the supplied canonical names."},
							"to":   {Type: genai.TypeString, Description: "The name to keep. Must be one of the supplied canonical names."},
							"preparation": {
								Type:        genai.TypeString,
								Description: "State qualifier on 'from' that belongs on the recipe line instead, e.g. 'medium' for medium onion. Empty string if nothing was stripped. Count qualifiers ('cloves', 'sprigs') never go here — they become the line's unit, so leave them out of the proposal entirely.",
							},
							"reason": {Type: genai.TypeString, Description: "A few words on why these are the same item."},
						},
					},
				},
				"unitFixes": {
					Type:        genai.TypeArray,
					Description: "Units that are not really units of measure.",
					Items: &genai.Schema{
						Type:     genai.TypeObject,
						Required: []string{"unit", "kind"},
						Properties: map[string]*genai.Schema{
							"unit": {Type: genai.TypeString, Description: "Must be one of the supplied unit names."},
							"kind": {
								Type:        genai.TypeString,
								Enum:        []string{"size", "instruction"},
								Description: "'size' for large/medium/small; 'instruction' for to taste, for serving, etc.",
							},
						},
					},
				},
			},
		},
		SystemInstruction: &genai.Content{
			Role: "system",
			Parts: []*genai.Part{{
				Text: strings.Join([]string{
					"You are de-duplicating the ingredient list of a personal recipe book. Two names should merge only if they are unambiguously the same thing you would buy in a shop.",
					"",
					"NEVER merge across form or state. These are all genuinely different items and must stay separate:",
					"  ground cumin / cumin seeds / cumin — different forms.",
					"  fresh coriander (a herb) / ground coriander (a spice) / coriander seeds.",
					"  garlic / garlic powder / garlic paste. onion / spring onion / red onion / onion powder.",
					"  fresh ginger / ground ginger. tomatoes / chopped tomatoes / tomato purée / sun-dried tomatoes.",
					"When in doubt, do not merge. A missed merge is harmless; a wrong one silently rewrites recipes.",
					"",
					"DO merge:",
					"  Plurals of the same item: 'onions' into 'onion', 'carrots' into 'carrot'. But keep names that are naturally plural as they are — 'green beans', 'cumin seeds', 'curry leaves' are not plurals of a thing you buy singly.",
					"  Size qualifiers welded onto the name: 'medium onion' into 'onion' with preparation 'medium'. Count qualifiers ('garlic cloves', '2 springs of thyme') do NOT belong here — the book stores the qualifier as the line's unit, so just propose 'garlic cloves' into 'garlic' and nothing else.",
					"Prefer the simpler, more general name as 'to', and prefer one that already appears in the list with more uses.",
					"",
					"Never chain merges: if you merge A into B, B must not itself be merged into anything.",
					"Only ever use names exactly as supplied.",
				}, "\n"),
			}},
		},
	}
}

func callGemini(ctx context.Context, client *genai.Client, model string, ingredients []ingredient, units []string) (*geminiResponse, error) {
	var b strings.Builder
	b.WriteString("Ingredient names (canonical form, with how many recipes use each):\n")
	for _, i := range ingredients {
		fmt.Fprintf(&b, "- %s (%d)\n", i.Canonical, i.Uses)
	}
	b.WriteString("\nUnit names currently in use:\n")
	for _, u := range units {
		fmt.Fprintf(&b, "- %s\n", u)
	}
	b.WriteString("\nPropose the merges, and flag any units that are not units of measure.")

	resp, err := client.Models.GenerateContent(ctx, model, []*genai.Content{
		{Role: "user", Parts: []*genai.Part{{Text: b.String()}}},
	}, buildGenerateConfig())
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

type rejection struct {
	merge Merge
	why   string
}

// validateMerges enforces mechanically what the prompt asks for politely. The
// model is the proposer, not the authority: anything it returns that names an
// unknown ingredient, chains, or crosses a form-word boundary is dropped here
// rather than left for the reviewer to catch.
func validateMerges(raw *geminiResponse, ingredients []ingredient) ([]Merge, []rejection) {
	known := make(map[string]bool, len(ingredients))
	for _, i := range ingredients {
		known[i.Canonical] = true
	}

	var accepted []Merge
	var rejected []rejection
	targets := make(map[string]bool)
	sources := make(map[string]bool)

	for _, m := range raw.Merges {
		merge := Merge{
			From:        strings.ToLower(strings.TrimSpace(m.From)),
			To:          strings.ToLower(strings.TrimSpace(m.To)),
			Preparation: strings.TrimSpace(m.Preparation),
			Reason:      strings.TrimSpace(m.Reason),
		}
		switch {
		case merge.From == "" || merge.To == "":
			rejected = append(rejected, rejection{merge, "blank name"})
		case merge.From == merge.To:
			rejected = append(rejected, rejection{merge, "merges onto itself"})
		case !known[merge.From]:
			rejected = append(rejected, rejection{merge, "'from' is not a known ingredient"})
		case !known[merge.To]:
			rejected = append(rejected, rejection{merge, "'to' is not a known ingredient"})
		case sources[merge.From]:
			rejected = append(rejected, rejection{merge, "duplicate proposal for this name"})
		case crossesForm(merge.From, merge.To):
			rejected = append(rejected, rejection{merge, "crosses a form boundary (ground/fresh/seeds/…)"})
		default:
			sources[merge.From] = true
			targets[merge.To] = true
			accepted = append(accepted, merge)
		}
	}

	// Chain check has to run once every source is known: A→B is invalid if B is
	// itself being retired, since the migration applies the mapping in one pass.
	var final []Merge
	for _, m := range accepted {
		if sources[m.To] {
			rejected = append(rejected, rejection{m, "'to' is itself being merged away"})
			continue
		}
		if targets[m.From] {
			rejected = append(rejected, rejection{m, "'from' is the target of another merge"})
			continue
		}
		final = append(final, m)
	}

	sort.Slice(final, func(i, j int) bool { return final[i].From < final[j].From })
	return final, rejected
}

// crossesForm reports whether exactly one of the two names carries a form word.
// "garlic cloves" → "garlic" is fine (cloves is not a form word), but
// "ground cumin" → "cumin" is not: they are different things on a shelf.
func crossesForm(from, to string) bool {
	for _, w := range formWords {
		if hasWord(from, w) != hasWord(to, w) {
			return true
		}
	}
	return false
}

func hasWord(name, word string) bool {
	for _, f := range strings.Fields(name) {
		if strings.Trim(f, ",()") == word {
			return true
		}
	}
	return false
}

func validateUnitFixes(raw *geminiResponse, units []string) []UnitFix {
	known := make(map[string]bool, len(units))
	for _, u := range units {
		known[u] = true
	}

	var out []UnitFix
	seen := make(map[string]bool)
	for _, f := range raw.UnitFixes {
		unit := strings.ToLower(strings.TrimSpace(f.Unit))
		if unit == "" || !known[unit] || seen[unit] {
			continue
		}
		if f.Kind != "size" && f.Kind != "instruction" {
			continue
		}
		seen[unit] = true
		out = append(out, UnitFix{Unit: unit, Kind: f.Kind})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Unit < out[j].Unit })
	return out
}
