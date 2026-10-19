package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"knowmates/services/api/internal/credits"
)

type Session struct {
	ID          uuid.UUID  `json:"id"`
	RequestID   uuid.UUID  `json:"requestId"`
	LearnerID   uuid.UUID  `json:"learnerId"`
	TeacherID   uuid.UUID  `json:"teacherId"`
	SkillID     uuid.UUID  `json:"skillId"`
	StartsAt    time.Time  `json:"startsAt"`
	EndsAt      time.Time  `json:"endsAt"`
	MeetingURL  *string    `json:"meetingUrl,omitempty"`
	Status      string     `json:"status"`
	LearnerDone bool       `json:"learnerDone"`
	TeacherDone bool       `json:"teacherDone"`
}

type LedgerEntry struct {
	Reason    string     `json:"reason"`
	Delta     int        `json:"delta"`
	CreatedAt time.Time  `json:"createdAt"`
	SessionID *uuid.UUID `json:"sessionId,omitempty"`
}

type Wallet struct {
	Balance int           `json:"balance"`
	Entries []LedgerEntry `json:"entries"`
}

func (s *Store) balanceInTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID) (int, error) {
	var bal int
	err := tx.QueryRow(ctx,
		`SELECT COALESCE(SUM(delta), 0)::int FROM credit_ledger WHERE user_id = $1`, userID).Scan(&bal)
	return bal, err
}

func scanSession(row pgx.Row) (Session, error) {
	var sess Session
	err := row.Scan(
		&sess.ID, &sess.RequestID, &sess.LearnerID, &sess.TeacherID, &sess.SkillID,
		&sess.StartsAt, &sess.EndsAt, &sess.MeetingURL, &sess.Status, &sess.LearnerDone, &sess.TeacherDone)
	return sess, err
}

func (s *Store) Schedule(ctx context.Context, requestID, actor uuid.UUID, start, end time.Time, meetingURL string) (Session, error) {
	if !end.After(start) {
		return Session{}, ErrForbidden
	}
	storedURL, err := credits.ValidMeetingURL(meetingURL)
	if err != nil {
		return Session{}, ErrBadMeetingURL
	}
	var urlArg *string
	if storedURL != "" {
		urlArg = &storedURL
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Session{}, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var learnerID, teacherID, skillID uuid.UUID
	var status string
	err = tx.QueryRow(ctx, `
		SELECT learner_id, teacher_id, skill_id, status
		FROM swap_requests WHERE id = $1 FOR UPDATE`, requestID).
		Scan(&learnerID, &teacherID, &skillID, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNoSuchRequest
	}
	if err != nil {
		return Session{}, err
	}
	if status != "accepted" {
		return Session{}, ErrConflict
	}
	if actor != learnerID && actor != teacherID {
		return Session{}, ErrForbidden
	}

	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM sessions WHERE request_id = $1)`, requestID).Scan(&exists); err != nil {
		return Session{}, err
	}
	if exists {
		return Session{}, ErrConflict
	}

	if _, err := tx.Exec(ctx, `SELECT id FROM users WHERE id = $1 FOR UPDATE`, learnerID); err != nil {
		return Session{}, err
	}
	bal, err := s.balanceInTx(ctx, tx, learnerID)
	if err != nil {
		return Session{}, err
	}
	if bal < 1 {
		return Session{}, ErrInsufficientCredits
	}

	sessID := uuid.New()
	if _, err := tx.Exec(ctx, `
		INSERT INTO sessions (id, request_id, learner_id, teacher_id, skill_id, starts_at, ends_at, meeting_url, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'scheduled')`,
		sessID, requestID, learnerID, teacherID, skillID, start, end, urlArg); err != nil {
		return Session{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO credit_ledger (id, user_id, session_id, delta, reason)
		VALUES (gen_random_uuid(), $1, $2, -1, 'session_hold')`,
		learnerID, sessID); err != nil {
		return Session{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Session{}, err
	}
	return s.loadSession(ctx, sessID)
}

func (s *Store) GetSession(ctx context.Context, id uuid.UUID) (Session, error) {
	return s.loadSession(ctx, id)
}

func (s *Store) loadSession(ctx context.Context, id uuid.UUID) (Session, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, request_id, learner_id, teacher_id, skill_id, starts_at, ends_at, meeting_url, status, learner_done, teacher_done
		FROM sessions WHERE id = $1`, id)
	sess, err := scanSession(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNoSuchSession
	}
	return sess, err
}

func (s *Store) Complete(ctx context.Context, sessionID, actor uuid.UUID) (string, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var sess Session
	row := tx.QueryRow(ctx, `
		SELECT id, request_id, learner_id, teacher_id, skill_id, starts_at, ends_at, meeting_url, status, learner_done, teacher_done
		FROM sessions WHERE id = $1 FOR UPDATE`, sessionID)
	sess, err = scanSession(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNoSuchSession
	}
	if err != nil {
		return "", err
	}
	if actor != sess.LearnerID && actor != sess.TeacherID {
		return "", ErrForbidden
	}
	if sess.Status == "completed" {
		if err := tx.Commit(ctx); err != nil {
			return "", err
		}
		return "completed", nil
	}
	if sess.Status != "scheduled" {
		return "", ErrConflict
	}

	switch actor {
	case sess.LearnerID:
		sess.LearnerDone = true
		if _, err := tx.Exec(ctx, `UPDATE sessions SET learner_done = true WHERE id = $1`, sessionID); err != nil {
			return "", err
		}
	case sess.TeacherID:
		sess.TeacherDone = true
		if _, err := tx.Exec(ctx, `UPDATE sessions SET teacher_done = true WHERE id = $1`, sessionID); err != nil {
			return "", err
		}
	}

	if sess.LearnerDone && sess.TeacherDone {
		tag, err := tx.Exec(ctx, `
			UPDATE sessions SET status = 'completed' WHERE id = $1 AND status = 'scheduled'`, sessionID)
		if err != nil {
			return "", err
		}
		if tag.RowsAffected() == 0 {
			return "", ErrConflict
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO credit_ledger (id, user_id, session_id, delta, reason)
			VALUES (gen_random_uuid(), $1, $2, 1, 'teach_completed')
			ON CONFLICT (session_id, user_id, reason) DO NOTHING`,
			sess.TeacherID, sessionID); err != nil {
			return "", err
		}
		if err := tx.Commit(ctx); err != nil {
			return "", err
		}
		return "completed", nil
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return "scheduled", nil
}

func (s *Store) CancelSession(ctx context.Context, sessionID, actor uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var learnerID, teacherID uuid.UUID
	var status string
	err = tx.QueryRow(ctx, `
		SELECT learner_id, teacher_id, status FROM sessions WHERE id = $1 FOR UPDATE`, sessionID).
		Scan(&learnerID, &teacherID, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNoSuchSession
	}
	if err != nil {
		return err
	}
	if actor != learnerID && actor != teacherID {
		return ErrForbidden
	}
	if status == "cancelled" {
		return tx.Commit(ctx)
	}
	if status != "scheduled" {
		return ErrConflict
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO credit_ledger (id, user_id, session_id, delta, reason)
		VALUES (gen_random_uuid(), $1, $2, 1, 'session_release')
		ON CONFLICT (session_id, user_id, reason) DO NOTHING`,
		learnerID, sessionID); err != nil {
		return err
	}
	tag, err := tx.Exec(ctx, `
		UPDATE sessions SET status = 'cancelled' WHERE id = $1 AND status = 'scheduled'`, sessionID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrConflict
	}
	return tx.Commit(ctx)
}

func (s *Store) Wallet(ctx context.Context, userID uuid.UUID) (Wallet, error) {
	bal, err := s.Balance(ctx, userID)
	if err != nil {
		return Wallet{}, err
	}
	rows, err := s.pool.Query(ctx, `
		SELECT reason, delta, created_at, session_id
		FROM credit_ledger WHERE user_id = $1
		ORDER BY created_at DESC LIMIT 50`, userID)
	if err != nil {
		return Wallet{}, err
	}
	defer rows.Close()
	var entries []LedgerEntry
	for rows.Next() {
		var e LedgerEntry
		if err := rows.Scan(&e.Reason, &e.Delta, &e.CreatedAt, &e.SessionID); err != nil {
			return Wallet{}, err
		}
		entries = append(entries, e)
	}
	if entries == nil {
		entries = []LedgerEntry{}
	}
	return Wallet{Balance: bal, Entries: entries}, rows.Err()
}
