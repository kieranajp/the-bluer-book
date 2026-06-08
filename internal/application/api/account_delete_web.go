package api

import (
	"html/template"
	"net/http"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/application/compliance"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// AccountDeleteWebHandler serves the public account-deletion page that
// Google Play requires to be reachable without installing the app. It
// sits behind the same Oathkeeper "ory-auth" rule that protects the
// rest of /account/* — Kratos issues a session cookie via Google
// login, Oathkeeper forwards X-User, this handler authenticates off
// that, asks the user to type DELETE, and on confirm calls the same
// compliance service the /api/account DELETE endpoint uses.
type AccountDeleteWebHandler struct {
	svc    compliance.Service
	logger logger.Logger
	tmpl   *template.Template
}

func NewAccountDeleteWebHandler(svc compliance.Service, log logger.Logger) *AccountDeleteWebHandler {
	return &AccountDeleteWebHandler{
		svc:    svc,
		logger: log,
		tmpl:   template.Must(template.New("delete").Parse(accountDeleteTemplate)),
	}
}

type accountDeletePageData struct {
	Error   string
	Success *compliance.DeletionResult
}

// GET /account/delete — shows the confirmation form.
func (h *AccountDeleteWebHandler) Show(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.UserID(r.Context()); !ok {
		http.Error(w, "unauthenticated", http.StatusUnauthorized)
		return
	}
	h.render(w, accountDeletePageData{})
}

// POST /account/delete — requires the user to type "DELETE" in the
// confirmation field. Cheap CSRF deterrent that also stops accidental
// clicks; the real protection is that the Oathkeeper session cookie
// + Google login already authenticated the user.
func (h *AccountDeleteWebHandler) Submit(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserID(r.Context())
	if !ok {
		http.Error(w, "unauthenticated", http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		h.render(w, accountDeletePageData{Error: "Could not read the form. Please try again."})
		return
	}

	if strings.TrimSpace(r.PostForm.Get("confirm")) != "DELETE" {
		h.render(w, accountDeletePageData{Error: `You must type DELETE (uppercase) to confirm.`})
		return
	}

	result, err := h.svc.DeleteAccount(r.Context(), userID)
	if err != nil {
		h.logger.Error().Err(err).Str("user_id", userID.String()).Msg("web delete failed")
		h.render(w, accountDeletePageData{Error: "Account deletion failed. Please try again later, or contact support."})
		return
	}

	h.render(w, accountDeletePageData{Success: result})
}

func (h *AccountDeleteWebHandler) render(w http.ResponseWriter, data accountDeletePageData) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := h.tmpl.Execute(w, data); err != nil {
		h.logger.Error().Err(err).Msg("render account-delete page")
	}
}

// Deliberately tiny. No CSS framework, no JS — just enough to be
// readable and discharge the Play-store "publicly reachable URL"
// requirement.
const accountDeleteTemplate = `<!doctype html>
<html lang="en-GB">
<head>
  <meta charset="utf-8">
  <title>Delete your Bluer Book account</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; max-width: 480px; margin: 3rem auto; padding: 0 1rem; line-height: 1.5; color: #222; }
    h1 { font-size: 1.5rem; }
    p { margin: 1rem 0; }
    .error { background: #ffe9e9; border-left: 4px solid #b00020; padding: 0.75rem 1rem; }
    .success { background: #e9ffe9; border-left: 4px solid #008000; padding: 0.75rem 1rem; }
    label { display: block; margin-top: 1.5rem; font-weight: 600; }
    input[type=text] { width: 100%; padding: 0.5rem; font-size: 1rem; border: 1px solid #999; border-radius: 4px; box-sizing: border-box; }
    button { margin-top: 1rem; padding: 0.6rem 1.2rem; font-size: 1rem; background: #b00020; color: white; border: 0; border-radius: 4px; cursor: pointer; }
    button:hover { background: #8a0019; }
    ul { padding-left: 1.5rem; }
    code { background: #f0f0f0; padding: 0.1rem 0.3rem; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Delete your account</h1>
  {{ if .Success }}
    <div class="success">
      <p>Your account has been deleted.</p>
      <p>
        {{ if .Success.HomesPurged }}
          {{ len .Success.HomesPurged }} household(s) were removed along with all their recipes,
          meal plans, pantry items and shopping lists.
        {{ else }}
          You were a member of households that have other owners; those households were left
          intact, just without your membership.
        {{ end }}
      </p>
      <p>You will be signed out the next time you visit. Goodbye.</p>
    </div>
  {{ else }}
    {{ if .Error }}<div class="error">{{ .Error }}</div>{{ end }}
    <p>
      Deleting your account here will:
    </p>
    <ul>
      <li>Remove your user record from The Bluer Book.</li>
      <li>For any household where you are the <strong>sole owner</strong>: permanently delete that
        household and everything in it — recipes, steps, ingredients, photos, the meal plan, the
        pantry, and the shopping list.</li>
      <li>For households with other owners: drop your membership only; the household keeps going
        without you.</li>
      <li>Remove your sign-in identity so this Google account no longer has access.</li>
    </ul>
    <p>This action cannot be undone.</p>
    <form method="POST" action="/account/delete">
      <label for="confirm">Type <code>DELETE</code> to confirm:</label>
      <input id="confirm" name="confirm" type="text" autocomplete="off" autocapitalize="off" required>
      <button type="submit">Delete my account</button>
    </form>
  {{ end }}
</body>
</html>
`
