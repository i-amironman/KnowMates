package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrBadVerifyToken = errors.New("store: invalid or expired verify token")

func (s *Store) UserEmail(ctx context.Context, userID uuid.UUID) (string, error) {
	var email string
	err := s.pool.QueryRow(ctx, `SELECT email::text FROM users WHERE id = $1`, userID).Scan(&email)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNoSuchUser
	}
	return email, err
}

func (s *Store) EmailVerified(ctx context.Context, userID uuid.UUID) (bool, error) {
	var ok bool
	err := s.pool.QueryRow(ctx, `SELECT email_verified FROM users WHERE id = $1`, userID).Scan(&ok)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, ErrNoSuchUser
	}
	return ok, err
}

func (s *Store) ReplaceEmailToken(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	if _, err := tx.Exec(ctx, `DELETE FROM email_tokens WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO email_tokens (token_hash, user_id, expires_at) VALUES ($1, $2, $3)`,
		tokenHash, userID, expiresAt); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ConsumeEmailToken(ctx context.Context, tokenHash string) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	var uid uuid.UUID
	var expires time.Time
	err = tx.QueryRow(ctx,
		`SELECT user_id, expires_at FROM email_tokens WHERE token_hash = $1 FOR UPDATE`,
		tokenHash).Scan(&uid, &expires)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrBadVerifyToken
	}
	if err != nil {
		return err
	}
	if time.Now().After(expires) {
		return ErrBadVerifyToken
	}
	if _, err := tx.Exec(ctx, `UPDATE users SET email_verified = true WHERE id = $1`, uid); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM email_tokens WHERE token_hash = $1`, tokenHash); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
