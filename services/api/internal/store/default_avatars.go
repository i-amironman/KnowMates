package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (s *Store) CountDefaultAvatars(ctx context.Context) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*)::int FROM default_avatars`).Scan(&n)
	return n, err
}

func (s *Store) InsertDefaultAvatar(ctx context.Context, id uuid.UUID, gender, avatarPath string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO default_avatars (id, gender, avatar_path) VALUES ($1, $2, $3)
		 ON CONFLICT (id) DO NOTHING`,
		id, gender, avatarPath)
	return err
}

func (s *Store) pickRandomDefaultAvatar(ctx context.Context, tx pgx.Tx, gender string) (string, error) {
	var path string
	err := tx.QueryRow(ctx,
		`SELECT avatar_path FROM default_avatars WHERE gender = $1 ORDER BY random() LIMIT 1`, gender).
		Scan(&path)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return path, err
}

func (s *Store) assignPoolAvatarIfEmpty(ctx context.Context, tx pgx.Tx, userID uuid.UUID, gender string) error {
	var current string
	if err := tx.QueryRow(ctx, `SELECT avatar_path FROM users WHERE id = $1`, userID).Scan(&current); err != nil {
		return err
	}
	if current != "" {
		return nil
	}
	path, err := s.pickRandomDefaultAvatar(ctx, tx, gender)
	if err != nil || path == "" {
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE users SET avatar_path = $2 WHERE id = $1`, userID, path)
	return err
}
