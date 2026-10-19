package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (s *Store) UpsertDeviceToken(ctx context.Context, userID uuid.UUID, token string) error {
	if token == "" {
		return ErrForbidden
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO device_tokens (user_id, token, updated_at)
		VALUES ($1, $2, now())
		ON CONFLICT (token) DO UPDATE
		SET user_id = EXCLUDED.user_id, updated_at = now()`,
		userID, token)
	return err
}

func (s *Store) LatestDeviceToken(ctx context.Context, userID uuid.UUID) (string, error) {
	var token string
	err := s.pool.QueryRow(ctx, `
		SELECT token FROM device_tokens
		WHERE user_id = $1
		ORDER BY updated_at DESC
		LIMIT 1`, userID).Scan(&token)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return token, err
}
