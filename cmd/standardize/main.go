package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

type Recipe struct {
	UUID        string
	Name        string
	Description string
	Timing      time.Duration
	ServingSize int16
	Steps       []Step
	Ingredients []RecipeIngredient
}

type Step struct {
	UUID        string
	RecipeID    string
	StepIndex   int16
	Description string
}

type Ingredient struct {
	UUID     string
	Name     string
	Quantity float64
	Unit     string
	Notes    string
}

type Unit struct {
	UUID         string
	Name         string
	Abbreviation string
}

type RecipeIngredient struct {
	RecipeID   string
	Ingredient Ingredient
	Unit       Unit
	Quantity   float64
}

// Common unit mappings
var unitMappings = map[string]string{
	"tbsp":        "tablespoon",
	"tbspn":       "tablespoon",
	"tbs":         "tablespoon",
	"tablespoon":  "tablespoon",
	"tablespoons": "tablespoon",
	"tsp":         "teaspoon",
	"teaspoon":    "teaspoon",
	"teaspoons":   "teaspoon",
	"g":           "gram",
	"gram":        "gram",
	"grams":       "gram",
	"kg":          "kilogram",
	"kilogram":    "kilogram",
	"kilograms":   "kilogram",
	"ml":          "milliliter",
	"milliliter":  "milliliter",
	"milliliters": "milliliter",
	"l":           "liter",
	"liter":       "liter",
	"liters":      "liter",
	"cup":         "cup",
	"cups":        "cup",
	"oz":          "ounce",
	"ounce":       "ounce",
	"ounces":      "ounce",
	"lb":          "pound",
	"pound":       "pound",
	"pounds":      "pound",
	"stalk":       "stalk",
	"stalks":      "stalk",
	"piece":       "piece",
	"pieces":      "piece",
	"packet":      "packet",
	"packets":     "packet",
}

// Unit abbreviations
var unitAbbreviations = map[string]string{
	"tablespoon": "tbsp",
	"teaspoon":   "tsp",
	"gram":       "g",
	"kilogram":   "kg",
	"milliliter": "ml",
	"liter":      "l",
	"ounce":      "oz",
	"pound":      "lb",
}

type TrelloRecipe struct {
	Name        string   `json:"name"`
	Description string   `json:"desc"`
	Ingredients []string `json:"ingredients"`
	Steps       []string `json:"steps"`
}

// Validation errors
var (
	ErrMissingName        = errors.New("recipe name is required")
	ErrMissingIngredients = errors.New("recipe must have at least one ingredient")
	ErrMissingSteps       = errors.New("recipe must have at least one step")
	ErrInvalidQuantity    = errors.New("invalid quantity format")
	ErrInvalidUnit        = errors.New("invalid unit")
)

// Common ingredient prefixes to remove
var ingredientPrefixes = []string{
	"of ", "a ", "an ", "some ", "about ", "approximately ",
}

// Common ingredient suffixes to remove
var ingredientSuffixes = []string{
	", chopped", ", diced", ", sliced", ", minced", ", grated",
	", fresh", ", dried", ", ground", ", whole",
}

// Common ingredient replacements
var ingredientReplacements = map[string]string{
	"bell pepper":   "pepper",
	"red pepper":    "pepper",
	"green pepper":  "pepper",
	"yellow pepper": "pepper",
	"orange pepper": "pepper",
	"chili pepper":  "chili",
	"chilli pepper": "chili",
	"chile pepper":  "chili",
	"chili":         "chili",
	"chilli":        "chili",
	"chile":         "chili",
	"tomato sauce":  "tomato sauce",
	"tomato paste":  "tomato paste",
	"tomato puree":  "tomato puree",
	"tomato":        "tomato",
	"tomatoes":      "tomato",
}

func main() {
	// Parse command line flags
	dryRun := flag.Bool("dry-run", false, "Preview changes without modifying the database")
	recipeName := flag.String("recipe", "", "Process only the specified recipe")
	verbose := flag.Bool("verbose", false, "Show detailed processing information")
	flag.Parse()

	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
	}

	// Read recipes.json
	recipesData, err := os.ReadFile("recipes.json")
	if err != nil {
		log.Fatalf("Failed to read recipes.json: %v", err)
	}

	var trelloRecipes []TrelloRecipe
	if err := json.Unmarshal(recipesData, &trelloRecipes); err != nil {
		log.Fatalf("Failed to parse recipes.json: %v", err)
	}

	log.Printf("Found %d recipes in recipes.json", len(trelloRecipes))

	// Filter recipes if name is specified
	if *recipeName != "" {
		var filteredRecipes []TrelloRecipe
		for _, r := range trelloRecipes {
			if strings.EqualFold(r.Name, *recipeName) {
				filteredRecipes = append(filteredRecipes, r)
			}
		}
		if len(filteredRecipes) == 0 {
			log.Fatalf("Recipe '%s' not found", *recipeName)
		}
		trelloRecipes = filteredRecipes
		log.Printf("Processing single recipe: %s", *recipeName)
	}

	// Get database connection string from environment
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	// Connect to database
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	// Create context
	ctx := context.Background()

	// Process each recipe
	successCount := 0
	errorCount := 0
	for _, trelloRecipe := range trelloRecipes {
		log.Printf("Processing recipe: %s", trelloRecipe.Name)

		// Validate recipe
		if err := validateRecipe(trelloRecipe); err != nil {
			log.Printf("Validation error for recipe %s: %v", trelloRecipe.Name, err)
			errorCount++
			continue
		}

		recipe := convertTrelloRecipe(trelloRecipe)
		if *verbose {
			log.Printf("Converted recipe details:")
			log.Printf("  Name: %s", recipe.Name)
			log.Printf("  Description: %s", recipe.Description)
			log.Printf("  Ingredients: %d", len(recipe.Ingredients))
			for _, ing := range recipe.Ingredients {
				log.Printf("    - %.2f %s %s", ing.Ingredient.Quantity, ing.Ingredient.Unit, ing.Ingredient.Name)
				if ing.Ingredient.Notes != "" {
					log.Printf("      Notes: %s", ing.Ingredient.Notes)
				}
			}
			log.Printf("  Steps: %d", len(recipe.Steps))
			for i, step := range recipe.Steps {
				log.Printf("    %d. %s", i+1, step.Description)
			}
		}

		if *dryRun {
			log.Printf("Dry run - would insert recipe: %s", recipe.Name)
			successCount++
			continue
		}

		if err := insertRecipe(ctx, db, recipe); err != nil {
			log.Printf("Failed to insert recipe %s: %v", recipe.Name, err)
			errorCount++
			continue
		}
		log.Printf("Successfully inserted recipe: %s", recipe.Name)
		successCount++
	}

	log.Printf("Processing complete. Success: %d, Errors: %d", successCount, errorCount)
}

func validateRecipe(recipe TrelloRecipe) error {
	if strings.TrimSpace(recipe.Name) == "" {
		return ErrMissingName
	}
	if len(recipe.Ingredients) == 0 {
		return ErrMissingIngredients
	}
	if len(recipe.Steps) == 0 {
		return ErrMissingSteps
	}
	return nil
}

func convertTrelloRecipe(trelloRecipe TrelloRecipe) Recipe {
	recipe := Recipe{
		Name:        standardizeRecipeName(trelloRecipe.Name),
		Description: standardizeDescription(trelloRecipe.Description),
	}

	// Convert ingredients
	for _, ingStr := range trelloRecipe.Ingredients {
		parsed := parseIngredient(ingStr)
		if parsed == nil {
			log.Printf("Could not parse ingredient: %s", ingStr)
			continue
		}

		recipe.Ingredients = append(recipe.Ingredients, RecipeIngredient{
			Ingredient: *parsed,
		})
	}

	// Convert steps
	for i, stepStr := range trelloRecipe.Steps {
		recipe.Steps = append(recipe.Steps, Step{
			StepIndex:   int16(i + 1),
			Description: standardizeStep(stepStr),
		})
	}

	return recipe
}

func insertRecipe(ctx context.Context, db *sql.DB, recipe Recipe) error {
	// Start transaction
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Insert recipe
	var recipeID string
	err = tx.QueryRowContext(ctx, `
		INSERT INTO recipes (name, description, servings)
		VALUES ($1, $2, $3)
		RETURNING uuid
	`, recipe.Name, recipe.Description, recipe.ServingSize).Scan(&recipeID)
	if err != nil {
		return fmt.Errorf("failed to insert recipe: %w", err)
	}

	// Insert ingredients
	for _, ing := range recipe.Ingredients {
		// Insert or get ingredient
		var ingredientID string
		err = tx.QueryRowContext(ctx, `
			INSERT INTO ingredients (name)
			VALUES ($1)
			ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
			RETURNING uuid
		`, ing.Ingredient.Name).Scan(&ingredientID)
		if err != nil {
			return fmt.Errorf("failed to insert ingredient: %w", err)
		}

		// Get or create unit
		var unitID sql.NullString
		if ing.Ingredient.Unit != "" {
			err = tx.QueryRowContext(ctx, `
				INSERT INTO units (name, abbreviation)
				VALUES ($1, $2)
				ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
				RETURNING uuid
			`, ing.Ingredient.Unit, unitAbbreviations[ing.Ingredient.Unit]).Scan(&unitID)
			if err != nil {
				return fmt.Errorf("failed to insert unit: %w", err)
			}
		}

		// Insert recipe_ingredient
		_, err = tx.ExecContext(ctx, `
			INSERT INTO recipe_ingredient (recipe_id, ingredient_id, unit_id, quantity)
			VALUES ($1, $2, $3, $4)
		`, recipeID, ingredientID, unitID, ing.Ingredient.Quantity)
		if err != nil {
			return fmt.Errorf("failed to insert recipe_ingredient: %w", err)
		}
	}

	// Insert steps
	for i, step := range recipe.Steps {
		_, err = tx.ExecContext(ctx, `
			INSERT INTO steps (recipe_id, step_order, description)
			VALUES ($1, $2, $3)
		`, recipeID, i+1, step.Description)
		if err != nil {
			return fmt.Errorf("failed to insert step: %w", err)
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

func standardizeRecipeName(name string) string {
	// Remove extra whitespace
	name = strings.TrimSpace(name)

	// Capitalize first letter
	if len(name) > 0 {
		name = strings.ToUpper(name[:1]) + name[1:]
	}

	return name
}

func standardizeDescription(desc string) string {
	// Remove extra whitespace
	desc = strings.TrimSpace(desc)

	// Capitalize first letter
	if len(desc) > 0 {
		desc = strings.ToUpper(desc[:1]) + desc[1:]
	}

	return desc
}

func standardizeStep(step string) string {
	// Remove extra whitespace
	step = strings.TrimSpace(step)

	// Capitalize first letter
	if len(step) > 0 {
		step = strings.ToUpper(step[:1]) + step[1:]
	}

	// Ensure step ends with a period
	if !strings.HasSuffix(step, ".") {
		step += "."
	}

	return step
}

func parseIngredient(input string) *Ingredient {
	// Remove any leading/trailing whitespace
	input = strings.TrimSpace(input)

	// Initialize result
	result := &Ingredient{
		Name:     input,
		Quantity: 1,  // Default quantity
		Unit:     "", // No unit by default
		Notes:    "", // No notes by default
	}

	// Extract quantity
	quantityRegex := regexp.MustCompile(`^(\d+(?:\.\d+)?|\d*\/\d+|\d+-\d+)\s*`)
	matches := quantityRegex.FindStringSubmatch(input)
	if len(matches) > 1 {
		// Handle fraction
		if strings.Contains(matches[1], "/") {
			parts := strings.Split(matches[1], "/")
			num, _ := strconv.ParseFloat(parts[0], 64)
			den, _ := strconv.ParseFloat(parts[1], 64)
			if den != 0 {
				result.Quantity = num / den
			}
		} else if strings.Contains(matches[1], "-") {
			// Handle range (take average)
			parts := strings.Split(matches[1], "-")
			start, _ := strconv.ParseFloat(parts[0], 64)
			end, _ := strconv.ParseFloat(parts[1], 64)
			result.Quantity = (start + end) / 2
		} else {
			result.Quantity, _ = strconv.ParseFloat(matches[1], 64)
		}
		input = input[len(matches[0]):]
	}

	// Extract unit
	for unit, standardUnit := range unitMappings {
		if strings.HasPrefix(strings.ToLower(input), unit+" ") {
			result.Unit = standardUnit
			input = input[len(unit)+1:]
			break
		}
	}

	// Extract notes (anything in parentheses or after comma)
	if idx := strings.Index(input, "("); idx != -1 {
		end := strings.Index(input[idx:], ")")
		if end != -1 {
			result.Notes = strings.TrimSpace(input[idx+1 : idx+end])
			input = input[:idx] + input[idx+end+1:]
		}
	}
	if idx := strings.Index(input, ","); idx != -1 {
		if result.Notes != "" {
			result.Notes += ", "
		}
		result.Notes += strings.TrimSpace(input[idx+1:])
		input = input[:idx]
	}

	// Clean up ingredient name
	result.Name = strings.TrimSpace(input)

	// Remove common prefixes
	for _, prefix := range ingredientPrefixes {
		if strings.HasPrefix(strings.ToLower(result.Name), prefix) {
			result.Name = strings.TrimPrefix(strings.ToLower(result.Name), prefix)
			break
		}
	}

	// Remove common suffixes
	for _, suffix := range ingredientSuffixes {
		if strings.HasSuffix(strings.ToLower(result.Name), suffix) {
			result.Name = strings.TrimSuffix(strings.ToLower(result.Name), suffix)
			if result.Notes != "" {
				result.Notes += ", "
			}
			result.Notes += strings.TrimPrefix(suffix, ", ")
			break
		}
	}

	// Apply common replacements
	for old, new := range ingredientReplacements {
		if strings.EqualFold(result.Name, old) {
			result.Name = new
			break
		}
	}

	// Handle special cases
	if strings.Contains(strings.ToLower(result.Name), "juice only") {
		result.Notes = "juice only"
		result.Name = strings.ReplaceAll(strings.ToLower(result.Name), "juice only", "")
	}
	if strings.Contains(strings.ToLower(result.Name), "zested") {
		result.Notes = "zested"
		result.Name = strings.ReplaceAll(strings.ToLower(result.Name), "zested", "")
	}

	// Final cleanup
	result.Name = strings.TrimSpace(result.Name)
	result.Notes = strings.TrimSpace(result.Notes)

	return result
}

func getOrCreateUnit(db *sql.DB, unitName string) (string, error) {
	var unitID string

	// Try to get existing unit
	err := db.QueryRow("SELECT uuid FROM units WHERE name = $1", unitName).Scan(&unitID)
	if err == nil {
		return unitID, nil
	}

	// Create new unit
	abbreviation := unitAbbreviations[unitName]
	_, err = db.Exec(`
		INSERT INTO units (name, abbreviation)
		VALUES ($1, $2)
		RETURNING uuid
	`, unitName, abbreviation)
	if err != nil {
		return "", err
	}

	// Get the new unit's ID
	err = db.QueryRow("SELECT uuid FROM units WHERE name = $1", unitName).Scan(&unitID)
	return unitID, err
}

func updateIngredient(db *sql.DB, ingredientID, newName string) error {
	_, err := db.Exec(`
		UPDATE ingredients
		SET name = $1, updated_at = NOW()
		WHERE uuid = $2
	`, newName, ingredientID)
	return err
}

func updateRecipeIngredient(db *sql.DB, recipeID, ingredientID, unitID string, quantity float64, notes string) error {
	_, err := db.Exec(`
		UPDATE recipe_ingredient
		SET unit_id = $1, quantity = $2, updated_at = NOW()
		WHERE recipe_id = $3 AND ingredient_id = $4
	`, unitID, quantity, recipeID, ingredientID)
	return err
}
