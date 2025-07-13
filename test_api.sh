#!/bin/bash

# Test the recipe import API endpoint

API_URL="http://localhost:8080/api/recipes/import"

# Test recipe data
cat > test_recipe.json << 'EOF'
{
  "name": "Simple Pasta",
  "description": "A quick and easy pasta dish",
  "cookTime": 15,
  "prepTime": 10,
  "servings": 4,
  "url": "https://example.com/simple-pasta",
  "steps": [
    {
      "order": 1,
      "description": "Boil water in a large pot"
    },
    {
      "order": 2,
      "description": "Add pasta and cook for 10-12 minutes"
    },
    {
      "order": 3,
      "description": "Drain and serve with sauce"
    }
  ],
  "ingredients": [
    {
      "name": "Pasta",
      "quantity": 400,
      "unit": "grams",
      "preparation": "any shape"
    },
    {
      "name": "Salt",
      "quantity": 1,
      "unit": "tablespoon",
      "preparation": ""
    },
    {
      "name": "Olive oil",
      "quantity": 2,
      "unit": "tablespoons",
      "preparation": "extra virgin"
    }
  ],
  "labels": ["quick", "easy", "pasta"]
}
EOF

echo "Testing recipe import API..."
echo "POST $API_URL"
echo

# Make the API call
curl -X POST \
  -H "Content-Type: application/json" \
  -d @test_recipe.json \
  "$API_URL"

echo
echo
echo "Cleaning up..."
rm -f test_recipe.json
