package fetchimages

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"io"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/urfave/cli/v2"
	"golang.org/x/net/html"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

var Command = &cli.Command{
	Name:  "fetch-images",
	Usage: "Scrape og:image from each recipe's source URL, upload to R2, and set as main photo",
	Flags: []cli.Flag{
		&cli.StringFlag{Name: "db-user", EnvVars: []string{"DB_USER"}},
		&cli.StringFlag{Name: "db-pass", EnvVars: []string{"DB_PASS"}},
		&cli.StringFlag{Name: "db-name", EnvVars: []string{"DB_NAME"}},
		&cli.StringFlag{Name: "db-host", EnvVars: []string{"DB_HOST"}},
		&cli.StringFlag{Name: "db-port", EnvVars: []string{"DB_PORT"}},
		&cli.StringFlag{
			Name:    "r2-account-id",
			Usage:   "Cloudflare account ID",
			EnvVars: []string{"R2_ACCOUNT_ID"},
		},
		&cli.StringFlag{
			Name:    "r2-access-key-id",
			Usage:   "R2 access key ID",
			EnvVars: []string{"R2_ACCESS_KEY_ID"},
		},
		&cli.StringFlag{
			Name:    "r2-secret-access-key",
			Usage:   "R2 secret access key",
			EnvVars: []string{"R2_SECRET_ACCESS_KEY"},
		},
		&cli.StringFlag{
			Name:    "r2-bucket",
			Usage:   "R2 bucket name",
			EnvVars: []string{"R2_BUCKET"},
		},
		&cli.StringFlag{
			Name:    "r2-public-url",
			Usage:   "Public URL prefix for the R2 bucket (e.g. https://images.example.com)",
			EnvVars: []string{"R2_PUBLIC_URL"},
		},
		&cli.BoolFlag{
			Name:  "all",
			Usage: "Re-fetch images for recipes that already have a main photo",
		},
		&cli.IntFlag{
			Name:  "concurrency",
			Usage: "Number of recipes to process in parallel",
			Value: 3,
		},
		&cli.IntFlag{
			Name:  "limit",
			Usage: "Stop after processing this many recipes (0 = no limit)",
			Value: 0,
		},
		&cli.BoolFlag{
			Name:  "dry-run",
			Usage: "Print what would be done without writing to R2 or the database",
		},
		&cli.BoolFlag{
			Name:  "continue-on-error",
			Usage: "Exit 0 even if some recipes failed",
		},
	},
	Action: run,
}

type recipeRow struct {
	UUID uuid.UUID
	Name string
	URL  string
}

func run(c *cli.Context) error {
	log := logger.New(logger.LogLevelInfo)
	ctx := c.Context

	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		c.String("db-user"), c.String("db-pass"),
		c.String("db-host"), c.String("db-port"),
		c.String("db-name"),
	)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		return fmt.Errorf("ping db: %w", err)
	}

	var s3Client *s3.Client
	bucket := c.String("r2-bucket")
	publicURL := strings.TrimRight(c.String("r2-public-url"), "/")

	if !c.Bool("dry-run") {
		accountID := c.String("r2-account-id")
		if accountID == "" || c.String("r2-access-key-id") == "" || bucket == "" || publicURL == "" {
			return fmt.Errorf("R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, and R2_PUBLIC_URL are required (or use --dry-run)")
		}
		endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID)
		s3Client = s3.New(s3.Options{
			Region:       "auto",
			BaseEndpoint: &endpoint,
			Credentials: credentials.NewStaticCredentialsProvider(
				c.String("r2-access-key-id"),
				c.String("r2-secret-access-key"),
				"",
			),
		})
	}

	recipes, err := loadRecipesNeedingImages(ctx, db, !c.Bool("all"))
	if err != nil {
		return fmt.Errorf("load recipes: %w", err)
	}
	if limit := c.Int("limit"); limit > 0 && len(recipes) > limit {
		recipes = recipes[:limit]
	}
	log.Info().Int("count", len(recipes)).Msg("Recipes to process")
	if len(recipes) == 0 {
		return nil
	}

	httpClient := &http.Client{Timeout: 15 * time.Second}

	sem := make(chan struct{}, c.Int("concurrency"))
	var wg sync.WaitGroup
	var mu sync.Mutex
	fetched, skipped, failed := 0, 0, 0

	for _, r := range recipes {
		sem <- struct{}{}
		wg.Add(1)
		go func(r recipeRow) {
			defer wg.Done()
			defer func() { <-sem }()

			imageURL, err := extractOGImage(ctx, httpClient, r.URL)
			if err != nil {
				log.Warn().Err(err).Str("recipe", r.Name).Str("url", r.URL).Msg("Failed to extract og:image")
				mu.Lock()
				failed++
				mu.Unlock()
				return
			}
			if imageURL == "" {
				log.Warn().Str("recipe", r.Name).Str("url", r.URL).Msg("No og:image found")
				mu.Lock()
				skipped++
				mu.Unlock()
				return
			}

			log.Info().Str("recipe", r.Name).Str("og:image", imageURL).Msg("Found image")

			if c.Bool("dry-run") {
				mu.Lock()
				fetched++
				mu.Unlock()
				return
			}

			r2URL, err := downloadAndUpload(ctx, httpClient, s3Client, bucket, publicURL, r.UUID, imageURL)
			if err != nil {
				log.Error().Err(err).Str("recipe", r.Name).Msg("Failed to upload image")
				mu.Lock()
				failed++
				mu.Unlock()
				return
			}

			if err := setMainPhoto(ctx, db, r.UUID, r2URL); err != nil {
				log.Error().Err(err).Str("recipe", r.Name).Msg("Failed to set main photo in DB")
				mu.Lock()
				failed++
				mu.Unlock()
				return
			}

			log.Info().Str("recipe", r.Name).Str("r2_url", r2URL).Msg("Image uploaded and linked")
			mu.Lock()
			fetched++
			mu.Unlock()
		}(r)
	}
	wg.Wait()

	log.Info().
		Int("fetched", fetched).
		Int("skipped", skipped).
		Int("failed", failed).
		Msg("Done")

	if failed > 0 && !c.Bool("continue-on-error") {
		os.Exit(1)
	}
	return nil
}

func loadRecipesNeedingImages(ctx context.Context, db *sql.DB, onlyMissing bool) ([]recipeRow, error) {
	query := `
		SELECT r.uuid, r.name, r.url
		FROM recipes r
		WHERE r.archived_at IS NULL
		  AND r.url IS NOT NULL AND r.url != ''
	`
	if onlyMissing {
		query += ` AND r.main_photo_id IS NULL`
	}
	query += ` ORDER BY r.created_at`

	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []recipeRow
	for rows.Next() {
		var r recipeRow
		if err := rows.Scan(&r.UUID, &r.Name, &r.URL); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func extractOGImage(ctx context.Context, client *http.Client, pageURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", pageURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; BluerBook/1.0)")
	req.Header.Set("Accept", "text/html")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	tokenizer := html.NewTokenizer(io.LimitReader(resp.Body, 512*1024))
	for {
		tt := tokenizer.Next()
		switch tt {
		case html.ErrorToken:
			return "", nil
		case html.StartTagToken, html.SelfClosingTagToken:
			t := tokenizer.Token()
			if t.Data != "meta" {
				if t.Data == "body" {
					return "", nil
				}
				continue
			}
			var property, content string
			for _, a := range t.Attr {
				switch a.Key {
				case "property", "name":
					property = a.Val
				case "content":
					content = a.Val
				}
			}
			if property == "og:image" && content != "" {
				return resolveURL(pageURL, content)
			}
		}
	}
}

func resolveURL(base, ref string) (string, error) {
	if strings.HasPrefix(ref, "http://") || strings.HasPrefix(ref, "https://") {
		return ref, nil
	}
	baseURL, err := url.Parse(base)
	if err != nil {
		return "", err
	}
	refURL, err := url.Parse(ref)
	if err != nil {
		return "", err
	}
	return baseURL.ResolveReference(refURL).String(), nil
}

func downloadAndUpload(
	ctx context.Context,
	httpClient *http.Client,
	s3Client *s3.Client,
	bucket, publicURL string,
	recipeID uuid.UUID,
	imageURL string,
) (string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", imageURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; BluerBook/1.0)")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("download image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download image: HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024))
	if err != nil {
		return "", fmt.Errorf("read image body: %w", err)
	}

	contentType := resp.Header.Get("Content-Type")
	if contentType == "" {
		contentType = http.DetectContentType(body)
	}

	ext := extensionForContentType(contentType, imageURL)
	hash := sha256.Sum256(body)
	key := fmt.Sprintf("recipes/%s/%s%s", recipeID.String(), hex.EncodeToString(hash[:8]), ext)

	_, err = s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:       aws.String(bucket),
		Key:          aws.String(key),
		Body:         bytes.NewReader(body),
		ContentType:  aws.String(contentType),
		CacheControl: aws.String("public, max-age=31536000, immutable"),
	})
	if err != nil {
		return "", fmt.Errorf("upload to R2: %w", err)
	}

	return publicURL + "/" + key, nil
}

func extensionForContentType(contentType, fallbackURL string) string {
	ct := strings.Split(contentType, ";")[0]
	exts, _ := mime.ExtensionsByType(ct)
	if len(exts) > 0 {
		for _, e := range exts {
			if e == ".jpg" || e == ".jpeg" || e == ".png" || e == ".webp" || e == ".avif" {
				return e
			}
		}
		return exts[0]
	}
	ext := path.Ext(strings.Split(fallbackURL, "?")[0])
	if ext != "" {
		return ext
	}
	return ".jpg"
}

func setMainPhoto(ctx context.Context, db *sql.DB, recipeID uuid.UUID, photoURL string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			tx.Rollback()
		}
	}()

	now := time.Now()
	photoUUID := uuid.New()

	_, err = tx.ExecContext(ctx, `
		INSERT INTO photos (uuid, url, entity_type, entity_id, created_at, updated_at)
		VALUES ($1, $2, 'recipe', $3, $4, $4)
	`, photoUUID, photoURL, recipeID, now)
	if err != nil {
		return fmt.Errorf("insert photo: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE recipes SET main_photo_id = $1, updated_at = $2 WHERE uuid = $3
	`, photoUUID, now, recipeID)
	if err != nil {
		return fmt.Errorf("update recipe main_photo_id: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return err
	}
	committed = true
	return nil
}
