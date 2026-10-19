package store

import (
	"context"

	"github.com/google/uuid"
)

type RequestView struct {
	ID              uuid.UUID `json:"id"`
	Goal            string    `json:"goal"`
	Status          string    `json:"status"`
	SkillID         uuid.UUID `json:"skillId"`
	SkillName       string    `json:"skillName"`
	CounterpartID   uuid.UUID `json:"counterpartId"`
	CounterpartName string    `json:"counterpartName"`
}

func (s *Store) ListRequests(ctx context.Context, userID uuid.UUID) (incoming, sent []RequestView, err error) {
	rows, err := s.pool.Query(ctx, `
		SELECT r.id, r.goal, r.status, r.skill_id, sk.name,
			CASE WHEN r.teacher_id = $1 THEN r.learner_id ELSE r.teacher_id END,
			CASE WHEN r.teacher_id = $1 THEN ul.display_name ELSE ut.display_name END,
			r.teacher_id = $1
		FROM swap_requests r
		JOIN skills sk ON sk.id = r.skill_id
		JOIN users ul ON ul.id = r.learner_id
		JOIN users ut ON ut.id = r.teacher_id
		WHERE r.teacher_id = $1 OR r.learner_id = $1
		ORDER BY r.created_at DESC`, userID)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var v RequestView
		var isIncoming bool
		if err := rows.Scan(&v.ID, &v.Goal, &v.Status, &v.SkillID, &v.SkillName,
			&v.CounterpartID, &v.CounterpartName, &isIncoming); err != nil {
			return nil, nil, err
		}
		if isIncoming {
			incoming = append(incoming, v)
		} else {
			sent = append(sent, v)
		}
	}
	return incoming, sent, rows.Err()
}
