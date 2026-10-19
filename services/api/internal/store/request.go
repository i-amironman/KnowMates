package store

import (
	"context"
	"errors"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type Request struct {
	ID        uuid.UUID `json:"id"`
	LearnerID uuid.UUID `json:"learnerId"`
	TeacherID uuid.UUID `json:"teacherId"`
	SkillID   uuid.UUID `json:"skillId"`
	Goal      string    `json:"goal"`
	Status    string    `json:"status"`
}

func validGoal(goal string) bool {
	n := utf8.RuneCountInString(goal)
	return n >= 8 && n <= 280
}

func (s *Store) blockedPair(ctx context.Context, a, b uuid.UUID) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM blocks
			WHERE (blocker_id = $1 AND blocked_id = $2)
			   OR (blocker_id = $2 AND blocked_id = $1)
		)`, a, b).Scan(&exists)
	return exists, err
}

func (s *Store) teacherHasSkill(ctx context.Context, teacher, skill uuid.UUID) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM user_skills
			WHERE user_id = $1 AND skill_id = $2 AND role = 'teach'
		)`, teacher, skill).Scan(&exists)
	return exists, err
}

func (s *Store) pendingRequestExists(ctx context.Context, learner, teacher, skill uuid.UUID) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM swap_requests
			WHERE learner_id = $1 AND teacher_id = $2 AND skill_id = $3 AND status = 'pending'
		)`, learner, teacher, skill).Scan(&exists)
	return exists, err
}

func (s *Store) CreateRequest(ctx context.Context, learner, teacher, skill uuid.UUID, goal string) (Request, error) {
	if learner == teacher {
		return Request{}, ErrForbidden
	}
	if !validGoal(goal) {
		return Request{}, ErrForbidden
	}
	blocked, err := s.blockedPair(ctx, learner, teacher)
	if err != nil {
		return Request{}, err
	}
	if blocked {
		return Request{}, ErrForbidden
	}
	teaches, err := s.teacherHasSkill(ctx, teacher, skill)
	if err != nil {
		return Request{}, err
	}
	if !teaches {
		return Request{}, ErrForbidden
	}
	dup, err := s.pendingRequestExists(ctx, learner, teacher, skill)
	if err != nil {
		return Request{}, err
	}
	if dup {
		return Request{}, ErrConflict
	}

	var req Request
	err = s.pool.QueryRow(ctx, `
		INSERT INTO swap_requests (id, learner_id, teacher_id, skill_id, goal, status)
		VALUES (gen_random_uuid(), $1, $2, $3, $4, 'pending')
		RETURNING id, learner_id, teacher_id, skill_id, goal, status`,
		learner, teacher, skill, goal).
		Scan(&req.ID, &req.LearnerID, &req.TeacherID, &req.SkillID, &req.Goal, &req.Status)
	return req, err
}

func (s *Store) loadRequest(ctx context.Context, id uuid.UUID) (Request, error) {
	var req Request
	err := s.pool.QueryRow(ctx, `
		SELECT id, learner_id, teacher_id, skill_id, goal, status
		FROM swap_requests WHERE id = $1`, id).
		Scan(&req.ID, &req.LearnerID, &req.TeacherID, &req.SkillID, &req.Goal, &req.Status)
	if errors.Is(err, pgx.ErrNoRows) {
		return Request{}, ErrNoSuchRequest
	}
	return req, err
}

func (s *Store) SetRequestStatus(ctx context.Context, id, actor uuid.UUID, to string) error {
	req, err := s.loadRequest(ctx, id)
	if err != nil {
		return err
	}

	var q string
	switch to {
	case "accepted", "declined":
		if actor != req.TeacherID {
			return ErrForbidden
		}
		q = `UPDATE swap_requests SET status = $3
			WHERE id = $1 AND status = 'pending' AND teacher_id = $2`
	case "cancelled":
		if actor != req.LearnerID {
			return ErrForbidden
		}
		q = `UPDATE swap_requests SET status = 'cancelled'
			WHERE id = $1 AND status = 'pending' AND learner_id = $2`
	default:
		return ErrForbidden
	}

	var tag pgconn.CommandTag
	if to == "cancelled" {
		tag, err = s.pool.Exec(ctx, q, id, actor)
	} else {
		tag, err = s.pool.Exec(ctx, q, id, actor, to)
	}
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrConflict
	}
	return nil
}
