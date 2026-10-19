package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestDiscoverLanguageMatchRanksFirst(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}
	ctx := context.Background()
	s, err := Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.Migrate(ctx); err != nil {
		t.Fatal(err)
	}

	skill := uuid.MustParse("11111111-1111-4111-8111-111111111101")
	learnOther := uuid.MustParse("11111111-1111-4111-8111-111111111104")
	slot := []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}

	viewer, err := s.CreateUser(ctx, fmt.Sprintf("viewer.%d@example.com", time.Now().UnixNano()), "hash", time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC), "UTC")
	if err != nil {
		t.Fatal(err)
	}
	vid, _ := uuid.Parse(viewer.ID)
	if err := s.UpdateProfile(ctx, vid, ProfilePatch{DisplayName: strPtr("Viewer"), Languages: []string{"en"}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, vid, []SkillLevel{{SkillID: learnOther, Proficiency: 3}}, []SkillLevel{{SkillID: skill, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, vid, slot); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, vid); err != nil {
		t.Fatal(err)
	}

	mkTeacher := func(email, lang string, teachProf int) uuid.UUID {
		u, err := s.CreateUser(ctx, email, "hash", time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC), "UTC")
		if err != nil {
			t.Fatal(err)
		}
		id, _ := uuid.Parse(u.ID)
		langs := []string{lang}
		name := lang
		if err := s.UpdateProfile(ctx, id, ProfilePatch{DisplayName: &name, Languages: langs}); err != nil {
			t.Fatal(err)
		}
		if err := s.ReplaceSkills(ctx, id, []SkillLevel{{SkillID: skill, Proficiency: teachProf}}, []SkillLevel{{SkillID: learnOther, Proficiency: 2}}); err != nil {
			t.Fatal(err)
		}
		if err := s.ReplaceAvailability(ctx, id, slot); err != nil {
			t.Fatal(err)
		}
		if err := s.MarkReady(ctx, id); err != nil {
			t.Fatal(err)
		}
		return id
	}

	esID := mkTeacher(fmt.Sprintf("teach.es.%d@example.com", time.Now().UnixNano()), "es", 2)
	enID := mkTeacher(fmt.Sprintf("teach.en.%d@example.com", time.Now().UnixNano()), "en", 4)

	var enRank, esRank = -1, -1
	var enScore, esScore int
	var cursor *DiscoverCursor
	for rank := 0; enRank < 0 || esRank < 0; {
		res, err := s.Discover(ctx, vid, DiscoverFilter{SkillID: skill}, cursor)
		if err != nil {
			t.Fatal(err)
		}
		if len(res.People) == 0 {
			break
		}
		for _, p := range res.People {
			if p.ID == enID {
				enRank, enScore = rank, p.Score
			}
			if p.ID == esID {
				esRank, esScore = rank, p.Score
			}
			rank++
		}
		if res.NextCursor == "" {
			break
		}
		cursor, err = DecodeDiscoverCursor(res.NextCursor)
		if err != nil {
			t.Fatal(err)
		}
	}
	if enRank < 0 || esRank < 0 {
		t.Fatalf("missing teachers en=%d es=%d", enRank, esRank)
	}
	if enScore <= esScore {
		t.Fatalf("en score %d want > es %d", enScore, esScore)
	}
	if enRank > esRank {
		t.Fatalf("en rank %d after es %d (scores %d vs %d)", enRank, esRank, enScore, esScore)
	}
}
