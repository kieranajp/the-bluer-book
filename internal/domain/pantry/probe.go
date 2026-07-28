package pantry

// Probe provides domain-oriented observability for pantry operations.
type Probe interface {
	PantryChanged(action string, ingredient string)
	PantryError(operation string, err error)
	// UnknownIngredient records an operation that named an ingredient the book
	// doesn't have. That's a caller mistake, not a fault, so it stays out of the
	// error counter — but it's worth counting on its own: LLM callers guess
	// ingredient names, and a spike here means the pantry tools are misfiring.
	UnknownIngredient(action string, ingredient string)
}
