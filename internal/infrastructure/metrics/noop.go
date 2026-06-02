package metrics

import "time"

// NoopRecipeProbe is a no-op implementation of recipe.Probe for tests.
type NoopRecipeProbe struct{}

func (NoopRecipeProbe) RecipeCreated(string)              {}
func (NoopRecipeProbe) RecipeUpdated(string)              {}
func (NoopRecipeProbe) RecipeArchived(string)             {}
func (NoopRecipeProbe) RecipeRestored(string)             {}
func (NoopRecipeProbe) MealPlanChanged(string, string)    {}
func (NoopRecipeProbe) RecipeSearched(int)                {}
func (NoopRecipeProbe) RecipeError(string, error)         {}

// NoopPantryProbe is a no-op implementation of pantry.Probe for tests.
type NoopPantryProbe struct{}

func (NoopPantryProbe) PantryChanged(string, string) {}
func (NoopPantryProbe) PantryError(string, error)    {}

// NoopChatProbe is a no-op implementation of chat.Probe for tests.
type NoopChatProbe struct{}

func (NoopChatProbe) SessionCreated(string)                          {}
func (NoopChatProbe) MessageReceived(string)                         {}
func (NoopChatProbe) ResponseCompleted(string, time.Duration, int)   {}
func (NoopChatProbe) ChatError(error)                                {}
