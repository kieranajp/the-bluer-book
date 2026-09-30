package tag

import (
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
)

func labelTypeStrings() []string {
	out := make([]string, len(recipe.LabelTypes))
	for i, t := range recipe.LabelTypes {
		out[i] = string(t)
	}
	slices.Sort(out)
	return out
}

func sortedKeys[K ~string, V any](m map[K]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, string(k))
	}
	slices.Sort(out)
	return out
}

func TestEveryLabelTypeIsTaggable(t *testing.T) {
	want := labelTypeStrings()

	if got := sortedKeys(taxonomy); !slices.Equal(got, want) {
		t.Errorf("taxonomy covers %v, want %v", got, want)
	}

	schema := buildGenerateConfig().ResponseSchema
	if got := sortedKeys(schema.Properties); !slices.Equal(got, want) {
		t.Errorf("the response schema asks for %v, want %v", got, want)
	}
	if got := slices.Sorted(slices.Values(schema.Required)); !slices.Equal(got, want) {
		t.Errorf("the response schema requires %v, want %v", got, want)
	}

	var decoded []string
	rt := reflect.TypeFor[geminiResponse]()
	for i := range rt.NumField() {
		name, _, _ := strings.Cut(rt.Field(i).Tag.Get("json"), ",")
		decoded = append(decoded, name)
	}
	slices.Sort(decoded)
	if !slices.Equal(decoded, want) {
		t.Errorf("the response decodes %v, want %v", decoded, want)
	}
}
