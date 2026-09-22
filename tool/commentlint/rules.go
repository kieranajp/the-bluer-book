package main

import (
	"fmt"
	"regexp"
	"strings"
)

const guidance = "See the comment-discipline skill: a comment states what IS, defaults to none, one line where earned, two for a real trap."

// Phrases that narrate how the code arrived instead of stating its invariant.
var narration = []string{
	"we used to",
	"it used to",
	"used to be",
	"turns out",
	"i tried",
	"we tried",
	"first attempt",
	"originally",
	"the problem was",
	"the bug was",
	"the issue was",
	"this was actually",
	"in hindsight",
}

var (
	pointer = regexp.MustCompile("(?:^|[\\s(`'\"])(?:[\\w.-]+/)+[\\w.-]+\\.(?:go|dart|sql|ya?ml|json|tmpl|sh)\\b" +
		"|\\b[\\w.-]+\\.(?:go|dart|sql|ya?ml|json|tmpl|sh):\\d+")
	url          = regexp.MustCompile(`https?://`)
	leadingNoise = regexp.MustCompile(`(?m)^[\s*]+`)
)

// Violation is one comment failing one rule.
type Violation struct {
	File   string
	Line   int
	Rule   string
	Detail string
}

func (v Violation) String() string {
	return fmt.Sprintf("%s:%d  [%s]  %s", v.File, v.Line, v.Rule, v.Detail)
}

// Check runs every rule over one file's comments, in source order.
func Check(comments []Comment, max int) []Violation {
	var found []Violation
	var run []Comment

	flush := func() {
		lines := 0
		for _, c := range run {
			lines += c.EndLine - c.StartLine + 1
		}
		if lines > max {
			found = append(found, Violation{
				File: run[0].File,
				Line: run[0].StartLine,
				Rule: "max-comment-run",
				Detail: fmt.Sprintf("comment runs %d lines; the cap is %d. Say the one thing not already in the code, or delete it. %s",
					lines, max, guidance),
			})
		}
		run = nil
	}

	for _, c := range comments {
		found = append(found, checkText(c)...)

		// A directive is machine-readable, not prose, and a trailing comment sits
		// beside code. Neither joins a standalone run; both end the one they land in.
		if c.Directive || !c.Standalone {
			if len(run) > 0 {
				flush()
			}
			continue
		}
		if len(run) > 0 && c.StartLine != run[len(run)-1].EndLine+1 {
			flush()
		}
		run = append(run, c)
	}
	if len(run) > 0 {
		flush()
	}
	return found
}

func checkText(c Comment) []Violation {
	if c.Directive {
		return nil
	}
	body := leadingNoise.ReplaceAllString(c.Text, " ")
	var found []Violation

	for _, phrase := range narration {
		if strings.Contains(strings.ToLower(body), phrase) {
			found = append(found, Violation{
				File: c.File, Line: c.StartLine, Rule: "no-narration",
				Detail: fmt.Sprintf("%q describes the journey, not what the code is. %s", phrase, guidance),
			})
			break
		}
	}

	if !url.MatchString(body) && pointer.MatchString(body) {
		found = append(found, Violation{
			File: c.File, Line: c.StartLine, Rule: "no-path-pointer",
			Detail: "a file or line pointer goes stale the moment either moves. Name the thing, not where it lives. " + guidance,
		})
	}
	return found
}
