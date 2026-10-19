package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

func (s *Store) CreateReview(ctx context.Context, sessionID, reviewerID uuid.UUID, rating int, body string) error {
	if rating < 1 || rating > 5 {
		return ErrForbidden
	}
	var learnerID, teacherID uuid.UUID
	var status string
	err := s.pool.QueryRow(ctx, `
		SELECT learner_id, teacher_id, status FROM sessions WHERE id = $1`, sessionID).
		Scan(&learnerID, &teacherID, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNoSuchSession
	}
	if err != nil {
		return err
	}
	if reviewerID != learnerID && reviewerID != teacherID {
		return ErrForbidden
	}
	if status != "completed" {
		return ErrConflict
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO reviews (id, session_id, reviewer_id, rating, body)
		VALUES (gen_random_uuid(), $1, $2, $3, $4)`,
		sessionID, reviewerID, rating, body)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ErrConflict
	}
	return err
}
