package trello

import (
	"encoding/json"
	"os"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type TrelloExport struct {
	Cards []Card `json:"cards"`
}

type Card struct {
	ID           string       `json:"id"`
	Name         string       `json:"name"`
	Desc         string       `json:"desc"`
	Attachments  []Attachment `json:"attachments"`
	IDChecklists []string     `json:"idChecklists"`
	Labels       []Label      `json:"labels"`
	Cover        Cover        `json:"cover"`
	Closed       bool         `json:"closed"`
}

type Attachment struct {
	ID   string `json:"id"`
	URL  string `json:"url"`
	Name string `json:"name"`
}

type Label struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Color string `json:"color"`
}

type Cover struct {
	IDAttachment string `json:"idAttachment"`
	Color        string `json:"color"`
}

type TrelloLoader struct {
	logger logger.Logger
	path   string
}

func NewTrelloLoader(logger logger.Logger, path string) *TrelloLoader {
	return &TrelloLoader{
		logger: logger,
		path:   path,
	}
}

// LoadAllCards loads and returns all cards (recipes) from the Trello export JSON file.
func (l *TrelloLoader) LoadAllCards() ([]Card, error) {
	f, err := os.Open(l.path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var export TrelloExport
	dec := json.NewDecoder(f)
	err = dec.Decode(&export)
	if err != nil {
		return nil, err
	}

	var filtered []Card
	for _, c := range export.Cards {
		if !c.Closed {
			filtered = append(filtered, c)
		}
	}
	return filtered, nil
}
