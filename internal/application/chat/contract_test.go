package chat

import (
	"encoding/json"
	"flag"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

var updateContract = flag.Bool("update-contract", false, "rewrite the Go-owned contract fixtures")

const contractDir = "../../../testdata/contract"

type contractExchange struct {
	Method string          `json:"method"`
	Path   string          `json:"path"`
	Status int             `json:"status,omitempty"`
	Body   json.RawMessage `json:"body"`
}

func TestContractChatStreamMatchesTheFixture(t *testing.T) {
	rec := httptest.NewRecorder()
	writeSSE(rec, rec, chatEvent{Content: "Try the lasagne.", SessionID: "sess-1"})
	writeSSE(rec, rec, chatEvent{Done: true, SessionID: "sess-1"})

	stream, err := json.Marshal(rec.Body.String())
	if err != nil {
		t.Fatal(err)
	}
	got := contractExchange{Method: http.MethodPost, Path: "/api/chat", Status: http.StatusOK, Body: stream}
	path := filepath.Join(contractDir, "responses", "chat_stream.json")

	if *updateContract {
		out, _ := json.MarshalIndent(got, "", "  ")
		if err := os.WriteFile(path, append(out, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}

	want := readContract(t, path)
	var wantStream string
	json.Unmarshal(want.Body, &wantStream)
	if want.Method != got.Method || want.Path != got.Path || want.Status != got.Status || wantStream != rec.Body.String() {
		t.Errorf("%s is stale: the chat stream is now %q\nrerun with -update-contract, then run the app's contract test", path, rec.Body.String())
	}
}

func TestContractChatRequestFromTheAppIsUnderstood(t *testing.T) {
	ex := readContract(t, filepath.Join(contractDir, "requests", "chat.json"))
	if ex.Method != http.MethodPost || ex.Path != "/api/chat" {
		t.Errorf("the app sends %s %s, want POST /api/chat", ex.Method, ex.Path)
	}

	var req chatRequest
	if err := json.Unmarshal(ex.Body, &req); err != nil {
		t.Fatal(err)
	}
	decoded, _ := json.Marshal(req)

	var sent, got map[string]any
	json.Unmarshal(ex.Body, &sent)
	json.Unmarshal(decoded, &got)
	if !reflect.DeepEqual(sent, got) {
		t.Errorf("the app sends %v, Go decodes %v", sent, got)
	}
}

func readContract(t *testing.T, path string) contractExchange {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var ex contractExchange
	if err := json.Unmarshal(raw, &ex); err != nil {
		t.Fatalf("decode %s: %v", path, err)
	}
	return ex
}
