package repository

import (
	"context"
	"slices"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// Guards against a label filter dropping the requested sort.
func TestListRecipesSortsTheSameWithOrWithoutALabelFilter(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := NewRecipeRepository(sqlDB, logger.New(logger.LogLevelError))
	dropTestVocabulary(t, sqlDB)
	ctx := auth.WithHome(context.Background(), makeHome(t, sqlDB, "sorting"))

	for _, r := range []struct {
		name string
		prep int32
	}{{"Carrot cake", 50}, {"Apple pie", 10}, {"Banana bread", 30}} {
		rec := testRecipe(r.name, "sorting flour")
		rec.PrepTime = r.prep
		if _, err := repo.SaveRecipe(ctx, rec); err != nil {
			t.Fatalf("save %s: %v", r.name, err)
		}
	}

	byLabel := []string{testLabelType + ":" + testLabelName}
	for _, tc := range []struct {
		sort string
		want []string
	}{
		{"", []string{"Banana bread", "Apple pie", "Carrot cake"}},
		{"name", []string{"Apple pie", "Banana bread", "Carrot cake"}},
		{"time", []string{"Apple pie", "Banana bread", "Carrot cake"}},
	} {
		for _, labels := range [][]string{nil, byLabel} {
			got, _, err := repo.ListRecipes(ctx, 10, 0, "", labels, tc.sort)
			if err != nil {
				t.Fatalf("list sort=%q labels=%v: %v", tc.sort, labels, err)
			}
			names := make([]string, len(got))
			for i, r := range got {
				names[i] = r.Name
			}
			if !slices.Equal(names, tc.want) {
				t.Errorf("sort=%q labels=%v: got %v, want %v", tc.sort, labels, names, tc.want)
			}
		}
	}
}
