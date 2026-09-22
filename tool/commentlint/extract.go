package main

import (
	"go/parser"
	"go/token"
	"regexp"
	"strings"
)

// Comment is one comment, in either language, with the facts the rules need.
type Comment struct {
	File      string
	StartLine int
	EndLine   int
	Text      string
	// Standalone is false for a comment sharing its line with code.
	Standalone bool
	Directive  bool
}

var (
	goDirective   = regexp.MustCompile(`^//(?:go|lint|nolint|export|sys|line|counterfeiter|sqlc|mockgen)\b`)
	dartDirective = regexp.MustCompile(`^//+\s*(?:ignore|ignore_for_file|coverage|dart format|@dart|GENERATED CODE|\*{4})`)
)

// GoComments parses with go/parser so string literals holding "//" are never
// mistaken for comments.
func GoComments(path string, src []byte) ([]Comment, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, path, src, parser.ParseComments|parser.SkipObjectResolution)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(src), "\n")

	var out []Comment
	for _, group := range file.Comments {
		for _, c := range group.List {
			start := fset.Position(c.Slash)
			end := fset.Position(c.End())
			out = append(out, Comment{
				File:       path,
				StartLine:  start.Line,
				EndLine:    end.Line,
				Text:       c.Text,
				Standalone: blankBefore(lines, start.Line, start.Column),
				Directive:  goDirective.MatchString(c.Text),
			})
		}
	}
	return out, nil
}

// DartComments scans source directly: the rules are lexical, so a tokeniser that
// knows Dart's string forms is enough, and it needs no Dart SDK to run.
func DartComments(path string, src []byte) ([]Comment, error) {
	s := string(src)
	lines := strings.Split(s, "\n")
	line, col := 1, 1

	var out []Comment
	add := func(text string, startLine, startCol, endLine int) {
		out = append(out, Comment{
			File:       path,
			StartLine:  startLine,
			EndLine:    endLine,
			Text:       text,
			Standalone: blankBefore(lines, startLine, startCol),
			Directive:  dartDirective.MatchString(text),
		})
	}

	advance := func(r byte) {
		if r == '\n' {
			line, col = line+1, 1
			return
		}
		col++
	}

	for i := 0; i < len(s); {
		switch {
		case strings.HasPrefix(s[i:], "//"):
			end := strings.IndexByte(s[i:], '\n')
			if end < 0 {
				end = len(s) - i
			}
			add(s[i:i+end], line, col, line)
			i += end

		case strings.HasPrefix(s[i:], "/*"):
			startLine, startCol := line, col
			depth, j := 0, i
			for j < len(s) {
				if strings.HasPrefix(s[j:], "/*") {
					depth++
					advance(s[j])
					advance(s[j+1])
					j += 2
					continue
				}
				if strings.HasPrefix(s[j:], "*/") {
					depth--
					advance(s[j])
					advance(s[j+1])
					j += 2
					if depth == 0 {
						break
					}
					continue
				}
				advance(s[j])
				j++
			}
			add(s[i:j], startLine, startCol, line)
			i = j
			continue

		case s[i] == '\'' || s[i] == '"':
			j := skipString(s, i, &line, &col, advance)
			i = j
			continue

		case s[i] == 'r' && i+1 < len(s) && (s[i+1] == '\'' || s[i+1] == '"'):
			advance(s[i])
			j := skipString(s, i+1, &line, &col, advance)
			i = j
			continue

		default:
			advance(s[i])
			i++
		}
	}
	return out, nil
}

// skipString consumes the literal starting at i and returns the index after it.
func skipString(s string, i int, line, col *int, advance func(byte)) int {
	quote := s[i]
	delim := string(quote)
	if strings.HasPrefix(s[i:], strings.Repeat(delim, 3)) {
		delim = strings.Repeat(delim, 3)
	}
	for k := 0; k < len(delim); k++ {
		advance(s[i+k])
	}
	j := i + len(delim)
	for j < len(s) {
		if s[j] == '\\' && j+1 < len(s) {
			advance(s[j])
			advance(s[j+1])
			j += 2
			continue
		}
		if strings.HasPrefix(s[j:], delim) {
			for k := 0; k < len(delim); k++ {
				advance(s[j+k])
			}
			return j + len(delim)
		}
		// A single-quote literal never spans a line; an unterminated one is a
		// syntax error, so stopping here keeps the scanner in step with the code.
		if s[j] == '\n' && len(delim) == 1 {
			return j
		}
		advance(s[j])
		j++
	}
	return j
}

func blankBefore(lines []string, line, col int) bool {
	if line-1 >= len(lines) {
		return true
	}
	text := lines[line-1]
	if col-1 > len(text) {
		return true
	}
	return strings.TrimSpace(text[:col-1]) == ""
}
