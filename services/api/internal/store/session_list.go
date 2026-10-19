package store

import (
	"context"

	"github.com/google/uuid"
)

type SessionView struct {
	Session
	SkillName       string `json:"skillName"`
	CounterpartName string `json:"counterpartName"`
}

func (s *Store) ListSessions(ctx context.Context, userID uuid.UUID) ([]SessionView, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT s.id, s.request_id, s.learner_id, s.teacher_id, s.skill_id,
			s.starts_at, s.ends_at, s.meeting_url, s.status, s.learner_done, s.teacher_done,
			sk.name,
			CASE WHEN s.learner_id = $1 THEN ut.display_name ELSE ul.display_name END
		FROM sessions s
		JOIN skills sk ON sk.id = s.skill_id
		JOIN users ul ON ul.id = s.learner_id
		JOIN users ut ON ut.id = s.teacher_id
		WHERE s.learner_id = $1 OR s.teacher_id = $1
		ORDER BY s.starts_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SessionView
	for rows.Next() {
		var v SessionView
		if err := rows.Scan(
			&v.ID, &v.RequestID, &v.LearnerID, &v.TeacherID, &v.SkillID,
			&v.StartsAt, &v.EndsAt, &v.MeetingURL, &v.Status, &v.LearnerDone, &v.TeacherDone,
			&v.SkillName, &v.CounterpartName,
		); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}
