package store

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"knowmates/services/api/internal/match"
)

const discoverPageSize = 20

type DiscoverFilter struct {
	SkillID  uuid.UUID
	Language string
	Weekday  *int
}

type DiscoverCursor struct {
	Score int       `json:"score"`
	ID    uuid.UUID `json:"id"`
}

type DiscoverPerson struct {
	ID             uuid.UUID   `json:"id"`
	DisplayName    string      `json:"displayName"`
	Bio            string      `json:"bio"`
	Languages      []string    `json:"languages"`
	Teach          []UserSkill `json:"teach"`
	SessionsTaught int         `json:"sessionsTaught"`
	RatingAvg      float64     `json:"ratingAvg"`
	RatingCount    int         `json:"ratingCount"`
	Score          int         `json:"score"`
	AvatarURL      string      `json:"avatarUrl"`
}

type DiscoverResult struct {
	People     []DiscoverPerson `json:"people"`
	NextCursor string           `json:"nextCursor"`
}

func EncodeDiscoverCursor(c DiscoverCursor) string {
	b, _ := json.Marshal(c)
	return base64.RawStdEncoding.EncodeToString(b)
}

func DecodeDiscoverCursor(s string) (*DiscoverCursor, error) {
	if s == "" {
		return nil, nil
	}
	raw, err := base64.RawStdEncoding.DecodeString(s)
	if err != nil {
		return nil, err
	}
	var c DiscoverCursor
	if err := json.Unmarshal(raw, &c); err != nil {
		return nil, err
	}
	return &c, nil
}

func (s *Store) Discover(ctx context.Context, viewerID uuid.UUID, f DiscoverFilter, cursor *DiscoverCursor) (DiscoverResult, error) {
	q := s.readQ()

	var viewerLangs []string
	var viewerTZ string
	var learnerProf int
	err := q.QueryRow(ctx, `SELECT languages, timezone FROM users WHERE id = $1`, viewerID).Scan(&viewerLangs, &viewerTZ)
	if err != nil {
		if err == pgx.ErrNoRows {
			return DiscoverResult{}, ErrNoSuchUser
		}
		return DiscoverResult{}, err
	}
	_ = q.QueryRow(ctx,
		`SELECT proficiency FROM user_skills WHERE user_id = $1 AND skill_id = $2 AND role = 'learn'`,
		viewerID, f.SkillID).Scan(&learnerProf)

	rows, err := q.Query(ctx, `
SELECT u.id, u.display_name, u.bio, u.languages, u.avatar_path, u.timezone,
       us.proficiency,
       COALESCE(r.avg, 0), COALESCE(r.n, 0),
       COALESCE(st.n, 0)
FROM user_skills us
JOIN users u ON u.id = us.user_id
LEFT JOIN (
  SELECT s.teacher_id, AVG(rev.rating)::float8 AS avg, COUNT(*) AS n
  FROM reviews rev
  JOIN sessions s ON s.id = rev.session_id AND rev.reviewer_id = s.learner_id
  GROUP BY s.teacher_id
) r ON r.teacher_id = u.id
LEFT JOIN (
  SELECT teacher_id, COUNT(*) AS n
  FROM sessions
  WHERE status = 'completed'
  GROUP BY teacher_id
) st ON st.teacher_id = u.id
WHERE us.skill_id = $2 AND us.role = 'teach' AND u.profile_ready
  AND u.id <> $1
  AND NOT EXISTS (
    SELECT 1 FROM blocks b
    WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
       OR (b.blocker_id = u.id AND b.blocked_id = $1)
  )
LIMIT 100`, viewerID, f.SkillID)
	if err != nil {
		return DiscoverResult{}, err
	}
	defer rows.Close()

	type cand struct {
		id             uuid.UUID
		displayName    string
		bio            string
		languages      []string
		avatarURL      string
		tz             string
		proficiency    int
		ratingAvg      float64
		ratingCount    int
		sessionsTaught int
	}
	var candidates []cand
	var ids []uuid.UUID
	for rows.Next() {
		var c cand
		if err := rows.Scan(&c.id, &c.displayName, &c.bio, &c.languages, &c.avatarURL, &c.tz,
			&c.proficiency, &c.ratingAvg, &c.ratingCount, &c.sessionsTaught); err != nil {
			return DiscoverResult{}, err
		}
		if f.Language != "" && !containsLang(c.languages, f.Language) {
			continue
		}
		candidates = append(candidates, c)
		ids = append(ids, c.id)
	}
	if err := rows.Err(); err != nil {
		return DiscoverResult{}, err
	}
	ids = append(ids, viewerID)
	slotsByUser, err := s.loadAvailabilityByUsers(ctx, q, ids)
	if err != nil {
		return DiscoverResult{}, err
	}
	viewerSlots := slotsByUser[viewerID]

	type scored struct {
		cand  cand
		score int
	}
	var ranked []scored
	for _, c := range candidates {
		overlap := overlapMinutes(viewerTZ, viewerSlots, c.tz, slotsByUser[c.id], f.Weekday)
		if f.Weekday != nil && overlap == 0 {
			continue
		}
		gap := c.proficiency - learnerProf
		sc := match.Score(match.Input{
			LanguageMatch:  langsIntersect(viewerLangs, c.languages),
			OverlapMinutes: overlap,
			ProficiencyGap: gap,
			RatingAvg:      c.ratingAvg,
			RatingCount:    c.ratingCount,
		})
		ranked = append(ranked, scored{cand: c, score: sc})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].score != ranked[j].score {
			return ranked[i].score > ranked[j].score
		}
		return ranked[i].cand.id.String() < ranked[j].cand.id.String()
	})

	if cursor != nil {
		i := 0
		for i < len(ranked) {
			r := ranked[i]
			if r.score < cursor.Score || (r.score == cursor.Score && r.cand.id.String() > cursor.ID.String()) {
				break
			}
			i++
		}
		ranked = ranked[i:]
	}

	page := ranked
	if len(page) > discoverPageSize {
		page = page[:discoverPageSize]
	}
	pageIDs := make([]uuid.UUID, len(page))
	for i, r := range page {
		pageIDs[i] = r.cand.id
	}
	teachByUser, err := s.loadTeachSkillsByUsers(ctx, q, pageIDs)
	if err != nil {
		return DiscoverResult{}, err
	}

	out := DiscoverResult{People: make([]DiscoverPerson, 0, len(page))}
	for _, r := range page {
		c := r.cand
		out.People = append(out.People, DiscoverPerson{
			ID:             c.id,
			DisplayName:    c.displayName,
			Bio:            c.bio,
			Languages:      c.languages,
			Teach:          teachByUser[c.id],
			SessionsTaught: c.sessionsTaught,
			RatingAvg:      c.ratingAvg,
			RatingCount:    c.ratingCount,
			Score:          r.score,
			AvatarURL:      c.avatarURL,
		})
	}
	if len(ranked) > discoverPageSize {
		last := page[len(page)-1]
		out.NextCursor = EncodeDiscoverCursor(DiscoverCursor{Score: last.score, ID: last.cand.id})
	}
	return out, nil
}

func containsLang(langs []string, code string) bool {
	for _, l := range langs {
		if l == code {
			return true
		}
	}
	return false
}

func langsIntersect(a, b []string) bool {
	for _, x := range a {
		for _, y := range b {
			if x == y {
				return true
			}
		}
	}
	return false
}

func (s *Store) loadAvailabilityByUsers(ctx context.Context, q *pgxpool.Pool, ids []uuid.UUID) (map[uuid.UUID][]Slot, error) {
	out := make(map[uuid.UUID][]Slot, len(ids))
	rows, err := q.Query(ctx,
		`SELECT user_id, weekday, start_min, end_min FROM availability WHERE user_id = ANY($1)`,
		ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var uid uuid.UUID
		var sl Slot
		if err := rows.Scan(&uid, &sl.Weekday, &sl.StartMin, &sl.EndMin); err != nil {
			return nil, err
		}
		out[uid] = append(out[uid], sl)
	}
	return out, rows.Err()
}

func (s *Store) loadTeachSkillsByUsers(ctx context.Context, q *pgxpool.Pool, ids []uuid.UUID) (map[uuid.UUID][]UserSkill, error) {
	out := make(map[uuid.UUID][]UserSkill)
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := q.Query(ctx, `
		SELECT us.user_id, us.skill_id, sk.name, us.proficiency
		FROM user_skills us
		JOIN skills sk ON sk.id = us.skill_id
		WHERE us.user_id = ANY($1) AND us.role = 'teach'
		ORDER BY sk.name`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var uid uuid.UUID
		var us UserSkill
		if err := rows.Scan(&uid, &us.SkillID, &us.Name, &us.Proficiency); err != nil {
			return nil, err
		}
		out[uid] = append(out[uid], us)
	}
	return out, rows.Err()
}

// ponytail: fixed anchor week for overlap; DST edges use location rules from Go.
func overlapMinutes(viewerTZ string, viewerSlots []Slot, candTZ string, candSlots []Slot, weekdayFilter *int) int {
	locV := loadLoc(viewerTZ)
	locC := loadLoc(candTZ)
	weekdays := []int{0, 1, 2, 3, 4, 5, 6}
	if weekdayFilter != nil {
		weekdays = []int{*weekdayFilter}
	}
	total := 0
	for _, wd := range weekdays {
		vRanges := slotRanges(wd, viewerSlots, locV)
		cRanges := slotRanges(wd, candSlots, locC)
		total += intervalOverlapMinutes(vRanges, cRanges)
	}
	return total
}

func loadLoc(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		return time.UTC
	}
	return loc
}

func schemaWeekdayGo(wd int) time.Weekday {
	return time.Weekday((wd + 1) % 7)
}

func weekdayAnchor(wd int, loc *time.Location) time.Time {
	d := time.Date(2024, 1, 1, 0, 0, 0, 0, loc)
	target := schemaWeekdayGo(wd)
	for d.Weekday() != target {
		d = d.AddDate(0, 0, 1)
	}
	return d
}

func slotRanges(wd int, slots []Slot, loc *time.Location) [][2]time.Time {
	day := weekdayAnchor(wd, loc)
	var out [][2]time.Time
	for _, sl := range slots {
		if sl.Weekday != wd {
			continue
		}
		y, m, d := day.Date()
		start := time.Date(y, m, d, 0, 0, 0, 0, loc).Add(time.Duration(sl.StartMin) * time.Minute)
		end := time.Date(y, m, d, 0, 0, 0, 0, loc).Add(time.Duration(sl.EndMin) * time.Minute)
		out = append(out, [2]time.Time{start, end})
	}
	return out
}

func intervalOverlapMinutes(a, b [][2]time.Time) int {
	total := 0
	for _, ar := range a {
		for _, br := range b {
			start := ar[0]
			if br[0].After(start) {
				start = br[0]
			}
			end := ar[1]
			if br[1].Before(end) {
				end = br[1]
			}
			if end.After(start) {
				total += int(end.Sub(start).Minutes())
			}
		}
	}
	return total
}
