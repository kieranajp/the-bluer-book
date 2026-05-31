package upload

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"mime"
	"path"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type R2Uploader struct {
	client    *s3.Client
	bucket    string
	publicURL string
	logger    logger.Logger
}

func NewR2Uploader(accountID, accessKeyID, secretAccessKey, bucket, publicURL string, log logger.Logger) *R2Uploader {
	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID)
	client := s3.New(s3.Options{
		Region:       "auto",
		BaseEndpoint: &endpoint,
		Credentials: credentials.NewStaticCredentialsProvider(
			accessKeyID,
			secretAccessKey,
			"",
		),
	})
	return &R2Uploader{
		client:    client,
		bucket:    bucket,
		publicURL: strings.TrimRight(publicURL, "/"),
		logger:    log,
	}
}

func (u *R2Uploader) UploadRecipePhoto(ctx context.Context, recipeID string, data []byte, contentType string, filename string) (string, error) {
	ext := extensionForContentType(contentType, filename)
	hash := sha256.Sum256(data)
	key := fmt.Sprintf("recipes/%s/%s%s", recipeID, hex.EncodeToString(hash[:8]), ext)

	_, err := u.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:       aws.String(u.bucket),
		Key:          aws.String(key),
		Body:         bytes.NewReader(data),
		ContentType:  aws.String(contentType),
		CacheControl: aws.String("public, max-age=31536000, immutable"),
	})
	if err != nil {
		return "", fmt.Errorf("upload to R2: %w", err)
	}

	url := u.publicURL + "/" + key
	u.logger.Info().Str("key", key).Str("url", url).Msg("Uploaded photo to R2")
	return url, nil
}

func extensionForContentType(contentType, fallbackFilename string) string {
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
	ext := path.Ext(strings.Split(fallbackFilename, "?")[0])
	if ext != "" {
		return ext
	}
	return ".jpg"
}
