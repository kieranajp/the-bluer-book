package pantry

// Probe provides domain-oriented observability for pantry operations.
type Probe interface {
	PantryChanged(action string, ingredient string)
	PantryError(operation string, err error)
}
