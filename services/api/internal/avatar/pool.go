package avatar

import (
	"context"
	"fmt"

	"github.com/google/uuid"
)

// DefaultAvatarRepo persists default avatar catalog rows.
type DefaultAvatarRepo interface {
	CountDefaultAvatars(ctx context.Context) (int, error)
	InsertDefaultAvatar(ctx context.Context, id uuid.UUID, gender, avatarPath string) error
}

// EnsureDefaultPool generates 10 male + 10 female avatars when the catalog is empty.
func EnsureDefaultPool(ctx context.Context, repo DefaultAvatarRepo, store AvatarStore) error {
	if repo == nil || store == nil {
		return nil
	}
	n, err := repo.CountDefaultAvatars(ctx)
	if err != nil {
		return err
	}
	if n >= 20 {
		return nil
	}
	for i := 1; i <= 10; i++ {
		if err := seedOne(ctx, repo, store, "male", fmt.Sprintf("a0000000-0000-4000-8000-%012d", i)); err != nil {
			return err
		}
	}
	for i := 1; i <= 10; i++ {
		if err := seedOne(ctx, repo, store, "female", fmt.Sprintf("b0000000-0000-4000-8000-%012d", i)); err != nil {
			return err
		}
	}
	return nil
}

func seedOne(ctx context.Context, repo DefaultAvatarRepo, store AvatarStore, gender, idStr string) error {
	id := uuid.MustParse(idStr)
	body, err := GeneratePortraitJPEG(id, gender)
	if err != nil {
		return err
	}
	url, err := store.PutPoolJPEG(ctx, id, body)
	if err != nil {
		return err
	}
	return repo.InsertDefaultAvatar(ctx, id, gender, url)
}
