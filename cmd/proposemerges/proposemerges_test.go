package proposemerges

import "testing"

func response(pairs ...[2]string) *geminiResponse {
	r := &geminiResponse{}
	for _, p := range pairs {
		r.Merges = append(r.Merges, struct {
			From        string `json:"from"`
			To          string `json:"to"`
			Preparation string `json:"preparation"`
			Reason      string `json:"reason"`
		}{From: p[0], To: p[1]})
	}
	return r
}

func known(names ...string) []ingredient {
	out := make([]ingredient, len(names))
	for i, n := range names {
		out[i] = ingredient{Canonical: n, Name: n}
	}
	return out
}

// The model is the proposer, not the authority. A wrong merge silently rewrites
// recipes, so everything it returns is re-checked here.
func TestValidateMergesRejectsUnsafeProposals(t *testing.T) {
	tests := []struct {
		name  string
		from  string
		to    string
		known []string
	}{
		{
			name:  "crosses a form boundary",
			from:  "ground cumin",
			to:    "cumin",
			known: []string{"ground cumin", "cumin"},
		},
		{
			name:  "herb is not the spice",
			from:  "fresh coriander",
			to:    "ground coriander",
			known: []string{"fresh coriander", "ground coriander"},
		},
		{
			name:  "unknown source",
			from:  "cilantro",
			to:    "coriander",
			known: []string{"coriander"},
		},
		{
			name:  "unknown target",
			from:  "onions",
			to:    "allium",
			known: []string{"onions"},
		},
		{
			name:  "merges onto itself",
			from:  "onion",
			to:    "onion",
			known: []string{"onion"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			accepted, rejected := validateMerges(response([2]string{tt.from, tt.to}), known(tt.known...))
			if len(accepted) != 0 {
				t.Fatalf("accepted = %v, want none", accepted)
			}
			if len(rejected) != 1 {
				t.Fatalf("rejected = %v, want one", rejected)
			}
		})
	}
}

func TestValidateMergesAcceptsPluralsAndQualifiers(t *testing.T) {
	raw := response(
		[2]string{"Onions", "onion"},
		[2]string{"garlic cloves", "garlic"},
	)
	accepted, rejected := validateMerges(raw, known("onions", "onion", "garlic cloves", "garlic"))

	if len(rejected) != 0 {
		t.Fatalf("rejected = %v, want none", rejected)
	}
	if len(accepted) != 2 {
		t.Fatalf("accepted %d merges, want 2", len(accepted))
	}
	// Sorted by source, and lowercased on the way in.
	if accepted[0].From != "garlic cloves" || accepted[0].To != "garlic" {
		t.Errorf("accepted[0] = %+v", accepted[0])
	}
	if accepted[1].From != "onions" || accepted[1].To != "onion" {
		t.Errorf("accepted[1] = %+v", accepted[1])
	}
}

// The migration applies the mapping in one pass, so A→B→C would leave A
// pointing at a row that no longer exists. Both links are dropped rather than
// one arbitrarily kept: a chain means the model contradicted itself about which
// name is canonical, and that is a judgement for the reviewer, not for whichever
// link happened to come first.
func TestValidateMergesRejectsWholeChains(t *testing.T) {
	raw := response(
		[2]string{"onions", "onion"},
		[2]string{"onion", "brown onion"},
	)
	accepted, rejected := validateMerges(raw, known("onions", "onion", "brown onion"))

	if len(accepted) != 0 {
		t.Fatalf("accepted = %+v, want none — the chain is ambiguous", accepted)
	}
	if len(rejected) != 2 {
		t.Fatalf("rejected %d proposals, want both links of the chain", len(rejected))
	}
}

func TestCrossesForm(t *testing.T) {
	tests := []struct {
		from, to string
		want     bool
	}{
		{"ground cumin", "cumin", true},
		{"cumin seeds", "cumin", true},
		{"fresh ginger", "ginger", true},
		{"olive oil", "olive", true},
		{"garlic cloves", "garlic", false},
		{"onions", "onion", false},
		{"medium curry powder", "curry powder", false},
	}

	for _, tt := range tests {
		if got := crossesForm(tt.from, tt.to); got != tt.want {
			t.Errorf("crossesForm(%q, %q) = %v, want %v", tt.from, tt.to, got, tt.want)
		}
	}
}

func TestValidateUnitFixesDropsUnknownAndMalformed(t *testing.T) {
	raw := &geminiResponse{}
	raw.UnitFixes = append(raw.UnitFixes,
		struct {
			Unit string `json:"unit"`
			Kind string `json:"kind"`
		}{Unit: "large", Kind: "size"},
		struct {
			Unit string `json:"unit"`
			Kind string `json:"kind"`
		}{Unit: "furlong", Kind: "size"}, // not a unit we have
		struct {
			Unit string `json:"unit"`
			Kind string `json:"kind"`
		}{Unit: "tbsp", Kind: "nonsense"}, // not a kind we accept
	)

	got := validateUnitFixes(raw, []string{"large", "tbsp", "to taste"})
	if len(got) != 1 || got[0].Unit != "large" || got[0].Kind != "size" {
		t.Fatalf("got %+v, want just large/size", got)
	}
}
