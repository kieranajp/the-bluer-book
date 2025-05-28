package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	_ "github.com/lib/pq"
)

type TrelloCard struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"desc"`
	URL         string `json:"url"`
	Checklists  []struct {
		Name  string `json:"name"`
		Items []struct {
			Name    string `json:"name"`
			Checked bool   `json:"checked"`
		} `json:"checkItems"`
	} `json:"checklists"`
}

type StandardizedRecipe struct {
	Name        string
	Description string
	URL         string
	Ingredients []StandardizedIngredient
	Steps       []string
}

type StandardizedIngredient struct {
	Quantity float64
	Unit     string
	Name     string
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
	"cup":        "cup",
	"piece":      "pc",
	"packet":     "pkt",
	"stalk":      "stalk",
}

type Ingredient struct {
	UUID string
	Name string
}

type Unit struct {
	UUID         string
	Name         string
	Abbreviation string
}

type RecipeIngredient struct {
	RecipeID     string
	IngredientID string
	UnitID       string
	Quantity     float64
}

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
	}

	// Initialize logger
	logger := logger.New("info")

	// Connect to database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is not set")
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Test the connection
	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	// Read recipes.json
	data, err := os.ReadFile("recipes.json")
	if err != nil {
		log.Fatal("Error reading recipes.json:", err)
	}

	// Parse JSON
	var cards []TrelloCard
	if err := json.Unmarshal(data, &cards); err != nil {
		log.Fatal("Error parsing JSON:", err)
	}

	// Maps to track unique ingredients and units
	ingredients := make(map[string]string) // name -> uuid
	units := make(map[string]string)       // name -> uuid

	// Process each recipe
	for _, card := range cards {
		recipe := standardizeRecipe(card)

		// Create recipe
		recipeID := uuid.New().String()
		_, err := db.Exec(`
			INSERT INTO recipes (uuid, name, description, url)
			VALUES ($1, $2, $3, $4)
		`, recipeID, recipe.Name, recipe.Description, recipe.URL)
		if err != nil {
			logger.Error().Err(err).Str("recipe", recipe.Name).Msg("Error creating recipe")
			continue
		}

		// Process ingredients
		for _, ing := range recipe.Ingredients {
			// Get or create ingredient
			ingredientID, exists := ingredients[ing.Name]
			if !exists {
				ingredientID = uuid.New().String()
				_, err := db.Exec(`
					INSERT INTO ingredients (uuid, name)
					VALUES ($1, $2)
				`, ingredientID, ing.Name)
				if err != nil {
					logger.Error().Err(err).Str("ingredient", ing.Name).Msg("Error creating ingredient")
					continue
				}
				ingredients[ing.Name] = ingredientID
			}

			// Get or create unit
			var unitID string
			if ing.Unit != "" {
				unitID, exists = units[ing.Unit]
				if !exists {
					unitID = uuid.New().String()
					abbreviation := unitAbbreviations[ing.Unit]
					_, err := db.Exec(`
						INSERT INTO units (uuid, name, abbreviation)
						VALUES ($1, $2, $3)
					`, unitID, ing.Unit, abbreviation)
					if err != nil {
						logger.Error().Err(err).Str("unit", ing.Unit).Msg("Error creating unit")
						continue
					}
					units[ing.Unit] = unitID
				}
			}

			// Create recipe_ingredient relationship
			_, err := db.Exec(`
				INSERT INTO recipe_ingredient (recipe_id, ingredient_id, unit_id, quantity)
				VALUES ($1, $2, $3, $4)
			`, recipeID, ingredientID, unitID, ing.Quantity)
			if err != nil {
				logger.Error().Err(err).
					Str("recipe", recipe.Name).
					Str("ingredient", ing.Name).
					Msg("Error creating recipe ingredient relationship")
				continue
			}
		}

		// Create steps
		for i, step := range recipe.Steps {
			_, err := db.Exec(`
				INSERT INTO steps (uuid, recipe_id, step_order, description)
				VALUES ($1, $2, $3, $4)
			`, uuid.New().String(), recipeID, i+1, step)
			if err != nil {
				logger.Error().Err(err).
					Str("recipe", recipe.Name).
					Int("step", i+1).
					Msg("Error creating step")
				continue
			}
		}

		logger.Info().
			Str("recipe", recipe.Name).
			Int("ingredients", len(recipe.Ingredients)).
			Int("steps", len(recipe.Steps)).
			Msg("Successfully imported recipe")
	}

	// Log summary
	logger.Info().
		Int("total_recipes", len(cards)).
		Int("unique_ingredients", len(ingredients)).
		Int("unique_units", len(units)).
		Msg("Import completed")
}

func standardizeRecipe(card TrelloCard) StandardizedRecipe {
	recipe := StandardizedRecipe{
		Name:        card.Name,
		Description: card.Description,
		URL:         card.URL,
	}

	// Process ingredients from checklists
	for _, checklist := range card.Checklists {
		if strings.Contains(strings.ToLower(checklist.Name), "ingredient") {
			for _, item := range checklist.Items {
				if parsed := parseIngredient(item.Name); parsed != nil {
					recipe.Ingredients = append(recipe.Ingredients, *parsed)
				}
			}
		}
	}

	// Extract steps from description
	recipe.Steps = extractSteps(card.Description)

	// If no ingredients found in checklists, try to extract from description
	if len(recipe.Ingredients) == 0 {
		recipe.Ingredients = extractIngredientsFromDescription(card.Description)
	}

	return recipe
}

func parseIngredient(input string) *StandardizedIngredient {
	// Remove any leading/trailing whitespace
	input = strings.TrimSpace(input)

	// Initialize result
	result := &StandardizedIngredient{
		Name:     input,
		Quantity: 1,  // Default quantity
		Unit:     "", // No unit by default
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
			result.Quantity = num / den
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

	// Clean up ingredient name
	result.Name = strings.TrimSpace(input)

	return result
}

func extractSteps(description string) []string {
	// Split by newlines and filter out empty lines
	lines := strings.Split(description, "\n")
	var steps []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			steps = append(steps, line)
		}
	}
	return steps
}

func extractIngredientsFromDescription(description string) []StandardizedIngredient {
	// Look for common ingredient list patterns
	lines := strings.Split(description, "\n")
	var ingredients []StandardizedIngredient

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Skip lines that look like steps
		if strings.HasPrefix(line, "1.") || strings.HasPrefix(line, "Step") {
			continue
		}

		// Try to parse as ingredient
		if parsed := parseIngredient(line); parsed != nil {
			ingredients = append(ingredients, *parsed)
		}
	}

	return ingredients
}
