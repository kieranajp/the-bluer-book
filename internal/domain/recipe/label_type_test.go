package recipe

import (
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"
)

func labelTypeStrings() []string {
	out := make([]string, len(LabelTypes))
	for i, t := range LabelTypes {
		out[i] = string(t)
	}
	return out
}

var labelTypeCheck = regexp.MustCompile(`(?s)ADD CONSTRAINT labels_type_check\s+CHECK \(type IN \(([^)]*)\)\)`)

func TestLabelTypesMatchTheSchemaConstraint(t *testing.T) {
	migrations, err := filepath.Glob("../../../migrations/*.sql")
	if err != nil || len(migrations) == 0 {
		t.Fatalf("no migrations found: %v", err)
	}
	slices.Sort(migrations)

	var latest []string
	for _, path := range migrations {
		raw, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		up, _, _ := strings.Cut(string(raw), "-- +goose Down")
		for _, m := range labelTypeCheck.FindAllStringSubmatch(up, -1) {
			latest = latest[:0]
			for _, v := range strings.Split(m[1], ",") {
				latest = append(latest, strings.Trim(strings.TrimSpace(v), "'"))
			}
		}
	}
	if latest == nil {
		t.Fatal("no migration adds labels_type_check")
	}

	want := labelTypeStrings()
	slices.Sort(latest)
	slices.Sort(want)
	if !slices.Equal(latest, want) {
		t.Errorf("labels_type_check admits %v, LabelTypes holds %v", latest, want)
	}
}

var dartLabelTypeEnum = regexp.MustCompile(`enum LabelType \{([^;}]*)`)

func TestLabelTypesMatchTheApp(t *testing.T) {
	raw, err := os.ReadFile("../../../app/lib/domain/label.dart")
	if err != nil {
		t.Fatal(err)
	}
	m := dartLabelTypeEnum.FindStringSubmatch(string(raw))
	if m == nil {
		t.Fatal("the app declares no LabelType enum")
	}
	var app []string
	for _, v := range strings.Split(m[1], ",") {
		if v = strings.TrimSpace(v); v != "" {
			app = append(app, v)
		}
	}

	if want := labelTypeStrings(); !slices.Equal(app, want) {
		t.Errorf("the app's LabelType is %v, LabelTypes is %v; order is display order on both", app, want)
	}
}

func TestValidateLabelsRejectsATypeOutsideTheTaxonomy(t *testing.T) {
	if err := ValidateLabels([]Label{{Type: LabelDiet, Name: "vegan"}}); err != nil {
		t.Errorf("a known type was rejected: %v", err)
	}

	err := ValidateLabels([]Label{{Type: LabelCourse, Name: "main"}, {Type: "occasion", Name: "christmas"}})
	var typed InvalidLabelTypeError
	if !errors.Is(err, ErrInvalidLabelType) || !errors.As(err, &typed) || typed.Type != "occasion" {
		t.Errorf("got %v, want an InvalidLabelTypeError for occasion", err)
	}
}
