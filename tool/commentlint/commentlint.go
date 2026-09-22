// Command commentlint enforces the three always-wrong comment shapes from the
// comment-discipline skill across the Go backend and the Flutter app.
package main

import (
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var defaultRoots = []string{"main.go", "cmd", "internal", "migrations", "tool", "app/lib"}

// Generated output is not prose anyone wrote, and sqlc's package is git-ignored.
var skipSuffixes = []string{".g.dart", ".freezed.dart", ".gen.dart", ".pb.go", "_templ.go"}
var skipDirs = []string{"internal/infrastructure/storage/db", ".dart_tool", "build", "node_modules"}

func main() {
	max := flag.Int("max", 2, "maximum lines in a run of standalone comments")
	flag.Parse()

	roots := flag.Args()
	if len(roots) == 0 {
		roots = defaultRoots
	}

	violations, err := run(roots, *max)
	if err != nil {
		fmt.Fprintf(os.Stderr, "commentlint: %v\n", err)
		os.Exit(2)
	}
	if len(violations) == 0 {
		fmt.Println("commentlint: ok — no violations.")
		return
	}

	for _, v := range violations {
		fmt.Println(v)
	}
	fmt.Printf("\ncommentlint: %d violation(s) in %d file(s).\n", len(violations), countFiles(violations))
	os.Exit(1)
}

func run(roots []string, max int) ([]Violation, error) {
	var violations []Violation

	for _, root := range roots {
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				if skipped(path) {
					return fs.SkipDir
				}
				return nil
			}
			if skipped(path) {
				return nil
			}

			var extract func(string, []byte) ([]Comment, error)
			switch filepath.Ext(path) {
			case ".go":
				extract = GoComments
			case ".dart":
				extract = DartComments
			default:
				return nil
			}

			src, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			comments, err := extract(path, src)
			if err != nil {
				return fmt.Errorf("parsing %s: %w", path, err)
			}
			violations = append(violations, Check(comments, max)...)
			return nil
		})
		if err != nil && !os.IsNotExist(err) {
			return nil, err
		}
	}

	sort.Slice(violations, func(i, j int) bool {
		if violations[i].File != violations[j].File {
			return violations[i].File < violations[j].File
		}
		return violations[i].Line < violations[j].Line
	})
	return violations, nil
}

func skipped(path string) bool {
	path = filepath.ToSlash(path)
	for _, suffix := range skipSuffixes {
		if strings.HasSuffix(path, suffix) {
			return true
		}
	}
	for _, dir := range skipDirs {
		if path == dir || strings.HasPrefix(path, dir+"/") ||
			strings.HasSuffix(path, "/"+dir) || strings.Contains(path, "/"+dir+"/") {
			return true
		}
	}
	return false
}

func countFiles(violations []Violation) int {
	seen := map[string]bool{}
	for _, v := range violations {
		seen[v.File] = true
	}
	return len(seen)
}
