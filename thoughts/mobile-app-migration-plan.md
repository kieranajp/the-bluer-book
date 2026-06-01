# Mobile App Migration Plan

## Backend API Endpoints

All endpoints documented in `internal/application/api/router.go`.

**Recipe Management:**
- `GET /api/recipes` - List recipes (supports `?limit`, `?offset`, `?search`, `?labels`)
- `GET /api/recipes/{id}` - Get single recipe
- `POST /api/recipes` - Create recipe
- `PUT /api/recipes/{id}` - Update recipe
- `DELETE /api/recipes/{id}` - Archive recipe
- `POST /api/recipes/{id}/restore` - Restore archived recipe
- `GET /api/recipes/archived` - List archived recipes

**Meal Planning:**
- `GET /api/recipes/meal-plan` - List meal plan recipes
- `POST /api/recipes/{id}/meal-plan` - Add to meal plan
- `DELETE /api/recipes/{id}/meal-plan` - Remove from meal plan

All responses return JSON. List endpoints return `{recipes: [], total: int}` format.

## Flutter App Structure

### Initial Setup
```
flutter_recipe_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── config/api_config.dart
│   │   └── network/dio_client.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── recipe.dart
│   │   │   ├── ingredient.dart
│   │   │   ├── step.dart
│   │   │   └── label.dart
│   │   └── repositories/
│   │       └── recipe_repository.dart
│   ├── data/
│   │   ├── models/
│   │   │   └── recipe_dto.dart
│   │   └── repositories/
│   │       └── recipe_repository_impl.dart
│   └── presentation/
│       ├── providers/
│       │   ├── recipe_list_provider.dart
│       │   └── meal_plan_provider.dart
│       ├── screens/
│       │   ├── recipe_list_screen.dart
│       │   ├── recipe_detail_screen.dart
│       │   ├── recipe_form_screen.dart
│       │   └── meal_plan_screen.dart
│       └── widgets/
│           ├── recipe_card.dart
│           └── ingredient_list_item.dart
└── pubspec.yaml
```

### Core Dependencies
- `flutter_riverpod` - state management
- `freezed` + `json_serializable` - immutable models
- `dio` - HTTP client
- `go_router` - navigation

### Design Requirements
Build according to designs provided by the design team. Match styling, layout, and interactions precisely.

### Implementation Stages

**Stage 1: Recipe List**
- Recipe list screen with search
- Basic recipe card display
- Meal plan recipes are shown at the top
- Pull-to-refresh

**Stage 2: Recipe Detail**
- Recipe detail screen
- Display ingredients with quantities/units
- Display steps in order
- Show photos, cook/prep times
- Back navigation

**Stage 3: Meal Planning**
- Hook up add/remove from meal plan buttons
- Visual indication of meal plan status

**Stage 4: Recipe Management**
- Create recipe form
- Edit recipe form
- Form validation
- Photo handling

**Stage 5: Polish**
- Error handling and loading states
- Empty states
- Offline indicators
- Performance optimisation

### Initial Setup Steps
1. Create Flutter project and add dependencies
2. Set up domain entities (Recipe, Ingredient, etc.)
3. Create data models with JSON serialisation
4. Build repository pattern with dio
5. Set up Riverpod providers for state
6. Implement navigation with go_router

## Out of Scope (Future)
- Authentication/users
- Photo uploads
- Offline support
- Archive/restore functionality
- Label filtering in UI (API supports it)
