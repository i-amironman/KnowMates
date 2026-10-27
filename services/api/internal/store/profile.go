package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrProfileIncomplete = errors.New("store: profile incomplete for ready")

var ErrInvalidGender = errors.New("store: invalid gender")

type SkillLevel struct {
	SkillID     uuid.UUID
	Proficiency int
}

type Slot struct {
	Weekday  int
	StartMin int
	EndMin   int
}

type ProfilePatch struct {
	DisplayName *string
	Bio         *string
	Languages   []string
	Timezone    *string
	Gender      *string
}

type UserSkill struct {
	SkillID     uuid.UUID `json:"skillId"`
	Name        string    `json:"name"`
	Proficiency int       `json:"proficiency"`
}

type AvailSlot struct {
	Weekday  int `json:"weekday"`
	StartMin int `json:"startMin"`
	EndMin   int `json:"endMin"`
}

type Me struct {
	ID                 uuid.UUID   `json:"id"`
	Email              string      `json:"email"`
	DisplayName        string      `json:"displayName"`
	Bio                string      `json:"bio"`
	Languages          []string    `json:"languages"`
	Timezone           string      `json:"timezone"`
	AvatarURL          string      `json:"avatarUrl"`
	Teach              []UserSkill `json:"teach"`
	Learn              []UserSkill `json:"learn"`
	Availability       []AvailSlot `json:"availability"`
	Balance            int         `json:"balance"`
	Gender             string      `json:"gender"`
	ProfileReady       bool        `json:"profileReady"`
	SessionsCompleted  int         `json:"sessionsCompleted"`
	RatingAvg          float64     `json:"ratingAvg"`
	RatingCount        int         `json:"ratingCount"`
	TeachCount         int         `json:"teachCount"`
	LearnCount         int         `json:"learnCount"`
}

func (s *Store) UpdateProfile(ctx context.Context, userID uuid.UUID, p ProfilePatch) error {
	if p.DisplayName == nil && p.Bio == nil && p.Languages == nil && p.Timezone == nil && p.Gender == nil {
		return nil
	}
	if p.Gender != nil {
		g := *p.Gender
		if g != "male" && g != "female" {
			return ErrInvalidGender
		}
	}
	_, err := s.pool.Exec(ctx, `
		UPDATE users SET
			display_name = COALESCE($2, display_name),
			bio = COALESCE($3, bio),
			languages = COALESCE($4, languages),
			timezone = COALESCE($5, timezone),
			gender = COALESCE($6, gender)
		WHERE id = $1`,
		userID, p.DisplayName, p.Bio, p.Languages, p.Timezone, p.Gender)
	return err
}

func (s *Store) SetAvatarURL(ctx context.Context, userID uuid.UUID, url string) error {
	tag, err := s.pool.Exec(ctx, `UPDATE users SET avatar_path = $2 WHERE id = $1`, userID, url)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoSuchUser
	}
	return nil
}

func (s *Store) ReplaceSkills(ctx context.Context, userID uuid.UUID, teach, learn []SkillLevel) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx, `DELETE FROM user_skills WHERE user_id = $1`, userID); err != nil {
		return err
	}
	insert := func(role string, levels []SkillLevel) error {
		for _, lv := range levels {
			if _, err := tx.Exec(ctx,
				`INSERT INTO user_skills (user_id, skill_id, role, proficiency) VALUES ($1, $2, $3, $4)`,
				userID, lv.SkillID, role, lv.Proficiency); err != nil {
				return err
			}
		}
		return nil
	}
	if err := insert("teach", teach); err != nil {
		return err
	}
	if err := insert("learn", learn); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ReplaceAvailability(ctx context.Context, userID uuid.UUID, slots []Slot) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx, `DELETE FROM availability WHERE user_id = $1`, userID); err != nil {
		return err
	}
	for _, sl := range slots {
		if _, err := tx.Exec(ctx,
			`INSERT INTO availability (id, user_id, weekday, start_min, end_min)
			 VALUES (gen_random_uuid(), $1, $2, $3, $4)`,
			userID, sl.Weekday, sl.StartMin, sl.EndMin); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func (s *Store) Balance(ctx context.Context, userID uuid.UUID) (int, error) {
	var bal int
	err := s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(delta), 0)::int FROM credit_ledger WHERE user_id = $1`, userID).Scan(&bal)
	return bal, err
}

func (s *Store) MarkReady(ctx context.Context, userID uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var displayName, gender string
	if err := tx.QueryRow(ctx, `SELECT display_name, gender FROM users WHERE id = $1`, userID).Scan(&displayName, &gender); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNoSuchUser
		}
		return err
	}
	if displayName == "" || gender == "" {
		return ErrProfileIncomplete
	}
	var teachN, learnN, slotN int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM user_skills WHERE user_id = $1 AND role = 'teach'`, userID).Scan(&teachN); err != nil {
		return err
	}
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM user_skills WHERE user_id = $1 AND role = 'learn'`, userID).Scan(&learnN); err != nil {
		return err
	}
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM availability WHERE user_id = $1`, userID).Scan(&slotN); err != nil {
		return err
	}
	if teachN < 1 || learnN < 1 || slotN < 1 {
		return ErrProfileIncomplete
	}
	if err := s.assignPoolAvatarIfEmpty(ctx, tx, userID, gender); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE users SET profile_ready = true WHERE id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO credit_ledger (id, user_id, delta, reason)
		 VALUES (gen_random_uuid(), $1, 2, 'starter_grant')
		 ON CONFLICT (user_id) WHERE (reason = 'starter_grant') DO NOTHING`,
		userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) loadSkills(ctx context.Context, userID uuid.UUID, role string) ([]UserSkill, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT us.skill_id, sk.name, us.proficiency
		FROM user_skills us
		JOIN skills sk ON sk.id = us.skill_id
		WHERE us.user_id = $1 AND us.role = $2
		ORDER BY sk.name`, userID, role)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []UserSkill
	for rows.Next() {
		var us UserSkill
		if err := rows.Scan(&us.SkillID, &us.Name, &us.Proficiency); err != nil {
			return nil, err
		}
		out = append(out, us)
	}
	return out, rows.Err()
}

func (s *Store) Me(ctx context.Context, userID uuid.UUID) (Me, error) {
	var m Me
	m.ID = userID
	err := s.pool.QueryRow(ctx, `
		SELECT email::text, display_name, bio, languages, timezone, avatar_path, gender, profile_ready
		FROM users WHERE id = $1`, userID).Scan(
		&m.Email, &m.DisplayName, &m.Bio, &m.Languages, &m.Timezone, &m.AvatarURL, &m.Gender, &m.ProfileReady)
	if errors.Is(err, pgx.ErrNoRows) {
		return Me{}, ErrNoSuchUser
	}
	if err != nil {
		return Me{}, err
	}
	m.Teach, err = s.loadSkills(ctx, userID, "teach")
	if err != nil {
		return Me{}, err
	}
	m.Learn, err = s.loadSkills(ctx, userID, "learn")
	if err != nil {
		return Me{}, err
	}
	rows, err := s.pool.Query(ctx,
		`SELECT weekday, start_min, end_min FROM availability WHERE user_id = $1 ORDER BY weekday, start_min`, userID)
	if err != nil {
		return Me{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var sl AvailSlot
		if err := rows.Scan(&sl.Weekday, &sl.StartMin, &sl.EndMin); err != nil {
			return Me{}, err
		}
		m.Availability = append(m.Availability, sl)
	}
	if err := rows.Err(); err != nil {
		return Me{}, err
	}
	m.Balance, err = s.Balance(ctx, userID)
	if err != nil {
		return Me{}, err
	}
	err = s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM sessions
		WHERE status = 'completed' AND (learner_id = $1 OR teacher_id = $1)`, userID).Scan(&m.SessionsCompleted)
	if err != nil {
		return Me{}, err
	}
	err = s.pool.QueryRow(ctx, `
		SELECT COALESCE(AVG(rev.rating), 0), COUNT(*)::int
		FROM reviews rev
		JOIN sessions sess ON sess.id = rev.session_id
		WHERE sess.teacher_id = $1 AND rev.reviewer_id = sess.learner_id`, userID).Scan(&m.RatingAvg, &m.RatingCount)
	if err != nil {
		return Me{}, err
	}
	m.TeachCount = len(m.Teach)
	m.LearnCount = len(m.Learn)
	return m, nil
}
