package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/joho/godotenv"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	_ "github.com/lib/pq"
)

type Recipe struct {
	UUID        string
	Name        string
	Description sql.NullString
	Timing      sql.NullString // This is an INTERVAL in Postgres
	Servings    sql.NullInt16
}

type ScrapedRecipe struct {
	Description string
	Timing      time.Duration
	Servings    int16
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

	// Get all recipes with null fields
	rows, err := db.Query(`
		SELECT uuid, name, description, timing, servings 
		FROM recipes 
		WHERE description IS NULL 
		OR timing IS NULL 
		OR servings IS NULL
	`)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	// Process each recipe
	for rows.Next() {
		var recipe Recipe
		if err := rows.Scan(
			&recipe.UUID,
			&recipe.Name,
			&recipe.Description,
			&recipe.Timing,
			&recipe.Servings,
		); err != nil {
			logger.Error().Err(err).Msg("Error scanning recipe row")
			continue
		}

		// Extract URL from recipe name if it exists
		url := extractURL(recipe.Name)
		if url == "" {
			logger.Info().Str("recipe", recipe.Name).Msg("No URL found in recipe name")
			continue
		}

		// Fetch and parse recipe data
		scrapedData, err := scrapeRecipe(url)
		if err != nil {
			logger.Error().Err(err).Str("url", url).Msg("Error scraping recipe")
			continue
		}

		// Update recipe in database
		if err := updateRecipe(db, recipe.UUID, scrapedData); err != nil {
			logger.Error().Err(err).Str("recipe", recipe.Name).Msg("Error updating recipe")
			continue
		}

		logger.Info().
			Str("recipe", recipe.Name).
			Str("url", url).
			Msg("Successfully updated recipe")
	}
}

func extractURL(name string) string {
	// Look for URLs in the recipe name
	if strings.Contains(name, "http") {
		parts := strings.Split(name, " ")
		for _, part := range parts {
			if strings.HasPrefix(part, "http") {
				return part
			}
		}
	}
	return ""
}

func scrapeRecipe(url string) (*ScrapedRecipe, error) {
	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Fetch the page
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("error fetching URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad status code: %d", resp.StatusCode)
	}

	// Load the HTML document
	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("error parsing HTML: %w", err)
	}

	// Extract recipe data
	recipe := &ScrapedRecipe{}

	// Description
	recipe.Description = strings.TrimSpace(doc.Find("meta[name='description']").AttrOr("content", ""))

	// Timing (Gesamtzeit)
	timingText := doc.Find("div:contains('Gesamtzeit')").Next().Text()
	if timingText != "" {
		// Extract minutes from text like "30 Minuten"
		re := regexp.MustCompile(`(\d+)\s*Min`)
		matches := re.FindStringSubmatch(timingText)
		if len(matches) > 1 {
			minutes, _ := strconv.Atoi(matches[1])
			recipe.Timing = time.Duration(minutes) * time.Minute
		}
	}

	// Servings (Portionsgröße)
	servingsText := doc.Find("div:contains('Portionsgröße')").Next().Text()
	if servingsText != "" {
		// Extract number from text like "234" or "2"
		re := regexp.MustCompile(`(\d+)`)
		matches := re.FindStringSubmatch(servingsText)
		if len(matches) > 1 {
			servings, _ := strconv.Atoi(matches[1])
			recipe.Servings = int16(servings)
		}
	}

	return recipe, nil
}

func updateRecipe(db *sql.DB, uuid string, data *ScrapedRecipe) error {
	query := `
		UPDATE recipes 
		SET 
			description = COALESCE($1, description),
			timing = COALESCE($2, timing),
			servings = COALESCE($3, servings),
			updated_at = NOW()
		WHERE uuid = $4
	`

	_, err := db.Exec(query,
		sql.NullString{String: data.Description, Valid: data.Description != ""},
		sql.NullString{String: data.Timing.String(), Valid: data.Timing > 0},
		sql.NullInt16{Int16: data.Servings, Valid: data.Servings > 0},
		uuid,
	)
	return err
}
