package trello

import (
	"os"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

func TestLoadAllCards(t *testing.T) {
	// Arrange
	tempFile, err := os.CreateTemp("", "cards_*.json")
	if err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())

	sample := `[{
		"id": "card1",
		"name": "Test Recipe",
		"desc": "A test description.",
		"attachments": [{"id": "att1", "url": "http://example.com/photo.jpg", "name": "photo.jpg"}],
		"idChecklists": ["chk1"],
		"labels": [{"id": "lbl1", "name": "Vegan", "color": "green"}],
		"cover": {"idAttachment": "att1", "color": "green"}
	}]
`
	if _, err := tempFile.Write([]byte(sample)); err != nil {
		t.Fatalf("failed to write sample JSON: %v", err)
	}
	tempFile.Close()

	loader := NewTrelloLoader(logger.New(logger.LogLevelDebug), tempFile.Name())

	// Act
	cards, err := loader.LoadAllCards()

	// Assert
	if err != nil {
		t.Fatalf("LoadAllCards failed: %v", err)
	}
	if len(cards) != 1 {
		t.Fatalf("expected 1 card, got %d", len(cards))
	}
	card := cards[0]
	if card.ID != "card1" || card.Name != "Test Recipe" {
		t.Errorf("unexpected card data: %+v", card)
	}
	if len(card.Attachments) != 1 || card.Attachments[0].URL != "http://example.com/photo.jpg" {
		t.Errorf("unexpected attachments: %+v", card.Attachments)
	}
	if len(card.Labels) != 1 || card.Labels[0].Name != "Vegan" {
		t.Errorf("unexpected labels: %+v", card.Labels)
	}
	if card.Cover.IDAttachment != "att1" {
		t.Errorf("unexpected cover: %+v", card.Cover)
	}
}

func TestLoadAllCards_SkipsArchived(t *testing.T) {
	tempFile, err := os.CreateTemp("", "cards_*.json")
	if err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())

	sample := `{"cards": [
		{
			"id": "card1",
			"name": "Open Recipe",
			"desc": "A test description.",
			"closed": false
		},
		{
			"id": "card2",
			"name": "Archived Recipe",
			"desc": "Should be skipped.",
			"closed": true
		}
	]}`

	if _, err := tempFile.WriteString(sample); err != nil {
		t.Fatalf("failed to write sample JSON: %v", err)
	}
	if err := tempFile.Close(); err != nil {
		t.Fatalf("failed to close temp file: %v", err)
	}

	loader := &TrelloLoader{path: tempFile.Name()}
	cards, err := loader.LoadAllCards()
	if err != nil {
		t.Fatalf("LoadAllCards failed: %v", err)
	}
	if len(cards) != 1 {
		t.Fatalf("expected 1 open card, got %d", len(cards))
	}
	if cards[0].ID != "card1" {
		t.Errorf("expected card1, got %s", cards[0].ID)
	}
}
