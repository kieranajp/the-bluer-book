package main

import (
	"strings"
	"testing"
)

func rules(t *testing.T, comments []Comment) []string {
	t.Helper()
	var names []string
	for _, v := range Check(comments, 2) {
		names = append(names, v.Rule)
	}
	return names
}

func goRules(t *testing.T, src string) []string {
	t.Helper()
	comments, err := GoComments("x.go", []byte(src))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	return rules(t, comments)
}

func dartRules(t *testing.T, src string) []string {
	t.Helper()
	comments, err := DartComments("x.dart", []byte(src))
	if err != nil {
		t.Fatalf("scan: %v", err)
	}
	return rules(t, comments)
}

func want(t *testing.T, got []string, expected ...string) {
	t.Helper()
	if strings.Join(got, ",") != strings.Join(expected, ",") {
		t.Errorf("got %v, want %v", got, expected)
	}
}

func TestMaxCommentRun(t *testing.T) {
	want(t, goRules(t, "package p\n\n// one\n// two\nvar a = 1\n"))
	want(t, goRules(t, "package p\n\n// one\n// two\n// three\nvar a = 1\n"), "max-comment-run")

	// A blank line ends a run, so two pairs are two runs.
	want(t, goRules(t, "package p\n\n// one\n// two\n\n// three\n// four\nvar a = 1\n"))

	// A block comment contributes every line it spans.
	want(t, goRules(t, "package p\n\n/* one\ntwo\nthree */\nvar a = 1\n"), "max-comment-run")
}

func TestTrailingCommentNeverJoinsARun(t *testing.T) {
	want(t, goRules(t, "package p\n\n// one\n// two\nvar a = 1 // three\n"))
	want(t, goRules(t, "package p\n\nvar a = 1 // one\nvar b = 2 // two\nvar c = 3 // three\n"))
}

func TestDirectivesAreNotProse(t *testing.T) {
	want(t, goRules(t, "//go:build linux\n\npackage p\n\n// one\n//go:generate stringer\n// two\nvar a = 1\n"))
	want(t, goRules(t, "package p\n\n//nolint:gocyclo // originally a mess\nvar a = 1\n"))
	want(t, dartRules(t, "// ignore_for_file: one\n// ignore_for_file: two\n// ignore_for_file: three\nvar a = 1;\n"))
}

func TestNarration(t *testing.T) {
	want(t, goRules(t, "package p\n\n// Turns out the API lies.\nvar a = 1\n"), "no-narration")
	want(t, goRules(t, "package p\n\nvar a = 1 // we used to round here\n"), "no-narration")
	want(t, goRules(t, "package p\n\n// The API omits the field for archived rows.\nvar a = 1\n"))
}

func TestPathPointer(t *testing.T) {
	want(t, goRules(t, "package p\n\n// Mirrors internal/domain/recipe/recipe.go.\nvar a = 1\n"), "no-path-pointer")
	want(t, goRules(t, "package p\n\n// Mirrors recipe.go:42.\nvar a = 1\n"), "no-path-pointer")

	// A bare filename is not a pointer, and a URL is stable enough to name.
	want(t, goRules(t, "package p\n\n// Mirrors recipe.go.\nvar a = 1\n"))
	want(t, goRules(t, "package p\n\n// See https://example.com/a/b/c.go for the shape.\nvar a = 1\n"))
}

func TestGoStringsAreNotComments(t *testing.T) {
	want(t, goRules(t, "package p\n\nvar a = \"https://example.com // turns out\"\n"))
	want(t, goRules(t, "package p\n\nvar a = `//one\n//two\n//three`\n"))
}

func TestDartStringsAreNotComments(t *testing.T) {
	want(t, dartRules(t, "var a = 'https://example.com // turns out';\n"))
	want(t, dartRules(t, "var a = '''\n// one\n// two\n// three\n''';\n"))
	want(t, dartRules(t, `var a = r'C:\path // turns out';`+"\n"))
	want(t, dartRules(t, "var a = 'it\\'s // turns out';\n"))
}

func TestDartDocCommentsCount(t *testing.T) {
	want(t, dartRules(t, "/// one\n/// two\n/// three\nclass A {}\n"), "max-comment-run")
	want(t, dartRules(t, "/// Turns out the plugin caches.\nclass A {}\n"), "no-narration")
}

func TestDartNestedBlockComment(t *testing.T) {
	want(t, dartRules(t, "/* outer /* inner */ still outer */\nvar a = 1;\n// turns out\n"), "no-narration")
}

func TestSkipsGeneratedAndVendoredPaths(t *testing.T) {
	for _, path := range []string{
		"app/lib/domain/recipe.g.dart",
		"app/lib/domain/recipe.freezed.dart",
		"internal/infrastructure/storage/db/models.go",
		"app/build/x.dart",
	} {
		if !skipped(path) {
			t.Errorf("%s should be skipped", path)
		}
	}
	for _, path := range []string{"app/lib/domain/recipe.dart", "internal/domain/recipe/recipe.go"} {
		if skipped(path) {
			t.Errorf("%s should be linted", path)
		}
	}
}
