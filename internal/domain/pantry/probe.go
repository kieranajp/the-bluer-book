package pantry

// Probe provides domain-oriented observability for pantry operations.
type Probe interface {
	PantryChanged(action string, ingredient string)
	PantryError(operation string, err error)
	// UnknownIngredient is a caller mistake, kept out of the error counter; a
	// spike means LLM callers are guessing ingredient names.
	UnknownIngredient(action string, ingredient string)
}
