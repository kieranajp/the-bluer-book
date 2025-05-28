package main

import (
	"fmt"
	"log"

	"github.com/kieranajp/the-bluer-book/cmd/import-recipes/fetcher"
)

func main() {
	url := "https://mangiawithnonna.com/cheesy-baked-gnocchi-alla-sorrentina-easy-delicious/"
	recipe, err := fetcher.FetchRecipe(url)
	if err != nil {
		log.Fatalf("Error fetching recipe: %v", err)
	}

	fmt.Printf("Recipe Name: %s\n", recipe.Name)
	fmt.Printf("Description: %s\n", recipe.Description)
	fmt.Printf("Yield: %s\n", recipe.RecipeYield)
	fmt.Printf("Prep Time: %s\n", recipe.PrepTime)
	fmt.Printf("Cook Time: %s\n", recipe.CookTime)
	fmt.Printf("Total Time: %s\n", recipe.TotalTime)
	fmt.Printf("Category: %s\n", recipe.RecipeCategory)
	fmt.Printf("Cuisine: %s\n", recipe.RecipeCuisine)
	fmt.Printf("Keywords: %s\n", recipe.Keywords)

	fmt.Println("\nIngredients:")
	for _, ing := range recipe.RecipeIngredient {
		fmt.Printf("- %s\n", ing)
	}

	fmt.Println("\nInstructions:")
	switch instr := recipe.RecipeInstructions.(type) {
	case string:
		fmt.Println(instr)
	case []interface{}:
		for i, step := range instr {
			if stepMap, ok := step.(map[string]interface{}); ok {
				if text, ok := stepMap["text"].(string); ok {
					fmt.Printf("%d. %s\n", i+1, text)
				}
			}
		}
	}
}
