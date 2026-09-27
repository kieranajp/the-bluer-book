package api

import (
	"bytes"
	"context"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
)

type stubUploader struct {
	uploads int
}

func (u *stubUploader) UploadRecipePhoto(_ context.Context, recipeID string, _ []byte, _ string, _ string) (string, error) {
	u.uploads++
	return "https://example.invalid/recipes/" + recipeID + "/photo.jpg", nil
}

func photoUploadRequest(t *testing.T, recipeID uuid.UUID) *http.Request {
	t.Helper()

	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	header := textproto.MIMEHeader{}
	header.Set("Content-Disposition", `form-data; name="photo"; filename="photo.jpg"`)
	header.Set("Content-Type", "image/jpeg")
	part, err := form.CreatePart(header)
	if err != nil {
		t.Fatalf("build form: %v", err)
	}
	part.Write([]byte("not really a jpeg"))
	form.Close()

	req := httptest.NewRequest(http.MethodPost, "/api/recipes/"+recipeID.String()+"/photo", &body)
	req.Header.Set("Content-Type", form.FormDataContentType())
	return req
}

func requireNotFoundEnvelope(t *testing.T, rec *httptest.ResponseRecorder) {
	t.Helper()

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status %d, want 404", rec.Code)
	}
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode error body: %v", err)
	}
	if body.Error.Code != "recipe_not_found" {
		t.Errorf("error code %q, want recipe_not_found", body.Error.Code)
	}
}

func TestUploadPhotoForARecipeTheCallerCannotSeeStoresNothing(t *testing.T) {
	svc := &stubRecipeService{requireErr: recipe.RecipeNotFoundError{}}
	uploader := &stubUploader{}
	h := NewPhotoHandler(uploader, svc, &noopLogger{})

	rec := httptest.NewRecorder()
	h.UploadRecipePhoto(rec, photoUploadRequest(t, uuid.New()))

	requireNotFoundEnvelope(t, rec)
	if uploader.uploads != 0 {
		t.Errorf("wrote %d objects to R2 for a recipe the caller cannot see", uploader.uploads)
	}
	if svc.setMainPhotos != 0 {
		t.Errorf("saved the photo against the recipe %d times", svc.setMainPhotos)
	}
}

func TestUploadPhotoIs404WhenTheRecipeGoesBeforeTheSave(t *testing.T) {
	svc := &stubRecipeService{setMainPhotoErr: recipe.RecipeNotFoundError{}}
	uploader := &stubUploader{}
	h := NewPhotoHandler(uploader, svc, &noopLogger{})

	rec := httptest.NewRecorder()
	h.UploadRecipePhoto(rec, photoUploadRequest(t, uuid.New()))

	requireNotFoundEnvelope(t, rec)
}

func TestUploadPhotoForAVisibleRecipeStoresIt(t *testing.T) {
	svc := &stubRecipeService{}
	uploader := &stubUploader{}
	h := NewPhotoHandler(uploader, svc, &noopLogger{})

	rec := httptest.NewRecorder()
	h.UploadRecipePhoto(rec, photoUploadRequest(t, uuid.New()))

	if rec.Code != http.StatusOK {
		t.Fatalf("status %d, want 200: %s", rec.Code, rec.Body.String())
	}
	if uploader.uploads != 1 || svc.setMainPhotos != 1 {
		t.Errorf("uploaded %d and saved %d, want 1 of each", uploader.uploads, svc.setMainPhotos)
	}
}
