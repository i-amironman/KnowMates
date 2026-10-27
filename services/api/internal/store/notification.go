package store

import (
	"context"

	"github.com/google/uuid"
)

type Notification struct {
	ID        uuid.UUID `json:"id"`
	Kind      string    `json:"kind"`
	RefID     uuid.UUID `json:"refId"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	CreatedAt string    `json:"createdAt"`
}

func (s *Store) InsertNotification(ctx context.Context, userID uuid.UUID, kind string, refID uuid.UUID, title, body string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO notifications (user_id, kind, ref_id, title, body)
		VALUES ($1, $2, $3, $4, $5)`,
		userID, kind, refID, title, body)
	return err
}

func (s *Store) UnreadNotificationCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM notifications
		WHERE user_id = $1 AND read_at IS NULL`, userID).Scan(&n)
	return n, err
}

func (s *Store) MarkNotificationsRead(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notifications SET read_at = now()
		WHERE user_id = $1 AND read_at IS NULL`, userID)
	return err
}

func (s *Store) ListNotifications(ctx context.Context, userID uuid.UUID, limit int) ([]Notification, error) {
	if limit <= 0 || limit > 50 {
		limit = 30
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, kind, ref_id, title, body, created_at::text
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Notification
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.Kind, &n.RefID, &n.Title, &n.Body, &n.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func (s *Store) DisplayName(ctx context.Context, userID uuid.UUID) (string, error) {
	var name string
	err := s.pool.QueryRow(ctx, `SELECT display_name FROM users WHERE id = $1`, userID).Scan(&name)
	return name, err
}
