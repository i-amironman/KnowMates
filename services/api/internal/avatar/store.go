package avatar

import (
	"context"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

// AvatarStore persists recompressed avatar JPEGs.
type AvatarStore interface {
	PutJPEG(ctx context.Context, userID uuid.UUID, body []byte) (url string, err error)
}

// DiskStore writes under Dir and returns PublicBase URLs.
// ponytail: single local volume; upgrade path is a larger disk on the same Compose file.
type DiskStore struct {
	Dir        string
	PublicBase string
}

func (d *DiskStore) PutJPEG(ctx context.Context, userID uuid.UUID, body []byte) (string, error) {
	_ = ctx
	fitted, err := FitJPEG(body, 512, 75)
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(d.Dir, 0o755); err != nil {
		return "", err
	}
	path := filepath.Join(d.Dir, userID.String()+".jpg")
	if err := os.WriteFile(path, fitted, 0o644); err != nil {
		return "", err
	}
	base := strings.TrimRight(d.PublicBase, "/")
	return base + "/avatars/" + userID.String() + ".jpg", nil
}
