package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var validReportReasons = map[string]bool{
	"harassment": true,
	"spam":       true,
	"safety":     true,
	"other":      true,
}

func (s *Store) BlockUser(ctx context.Context, blocker, blocked uuid.UUID) error {
	if blocker == blocked {
		return ErrForbidden
	}
	_, err := s.pool.Exec(ctx,
		`INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		blocker, blocked)
	return err
}

func (s *Store) UnblockUser(ctx context.Context, blocker, blocked uuid.UUID) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2`, blocker, blocked)
	return err
}

func (s *Store) CreateReport(ctx context.Context, reporter, target uuid.UUID, sessionID *uuid.UUID, reason, details string) error {
	if !validReportReasons[reason] {
		return ErrForbidden
	}
	if reporter == target {
		return ErrForbidden
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	reportID := uuid.New()
	if _, err := tx.Exec(ctx, `
		INSERT INTO reports (id, reporter_id, target_user_id, session_id, reason, details)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		reportID, reporter, target, sessionID, reason, details); err != nil {
		return err
	}

	if sessionID != nil {
		var learnerID, teacherID uuid.UUID
		var status string
		err := tx.QueryRow(ctx, `
			SELECT learner_id, teacher_id, status FROM sessions WHERE id = $1 FOR UPDATE`, *sessionID).
			Scan(&learnerID, &teacherID, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNoSuchSession
		}
		if err != nil {
			return err
		}
		if reporter != learnerID && reporter != teacherID {
			return ErrForbidden
		}
		if status == "scheduled" {
			if _, err := tx.Exec(ctx, `
				INSERT INTO credit_ledger (id, user_id, session_id, delta, reason)
				VALUES (gen_random_uuid(), $1, $2, 1, 'session_release')
				ON CONFLICT (session_id, user_id, reason) DO NOTHING`,
				learnerID, *sessionID); err != nil {
				return err
			}
			tag, err := tx.Exec(ctx, `
				UPDATE sessions SET status = 'disputed' WHERE id = $1 AND status = 'scheduled'`, *sessionID)
			if err != nil {
				return err
			}
			if tag.RowsAffected() == 0 {
				return ErrConflict
			}
		}
	}

	return tx.Commit(ctx)
}

// DeleteUser anonymizes the account and removes personal data; session rows stay for the other party.
func (s *Store) DeleteUser(ctx context.Context, userID uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx, `DELETE FROM session_messages WHERE sender_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM refresh_tokens WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM credit_ledger WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM reviews WHERE reviewer_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM blocks WHERE blocker_id = $1 OR blocked_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM reports WHERE reporter_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM availability WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM user_skills WHERE user_id = $1`, userID); err != nil {
		return err
	}

	deletedEmail := fmt.Sprintf("deleted-%s@invalid", userID.String())
	tag, err := tx.Exec(ctx, `
		UPDATE users SET
			email = $2,
			password_hash = '!',
			display_name = 'Deleted member',
			bio = '',
			languages = '{}',
			avatar_path = '',
			profile_ready = false
		WHERE id = $1`, userID, deletedEmail)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoSuchUser
	}
	return tx.Commit(ctx)
}
