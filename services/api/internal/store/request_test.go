package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestOnlyTeacherCanAccept(t *testing.T) {
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
	birth := time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC)
	slot := []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}
	goal := "I want to learn this skill well."

	learnerU, err := s.CreateUser(ctx, fmt.Sprintf("learner.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	learner, _ := uuid.Parse(learnerU.ID)
	if err := s.ReplaceSkills(ctx, learner, nil, []SkillLevel{{SkillID: skill, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}

	teacherU, err := s.CreateUser(ctx, fmt.Sprintf("teacher.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	teacher, _ := uuid.Parse(teacherU.ID)
	if err := s.ReplaceSkills(ctx, teacher, []SkillLevel{{SkillID: skill, Proficiency: 4}}, []SkillLevel{{SkillID: learnOther, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	_ = slot

	req, err := s.CreateRequest(ctx, learner, teacher, skill, goal)
	if err != nil {
		t.Fatal(err)
	}

	if err := s.SetRequestStatus(ctx, req.ID, learner, "accepted"); err != ErrForbidden {
		t.Fatalf("learner accept: want ErrForbidden, got %v", err)
	}
	if err := s.SetRequestStatus(ctx, req.ID, teacher, "accepted"); err != nil {
		t.Fatalf("teacher accept: %v", err)
	}
	var status string
	if err := s.pool.QueryRow(ctx, `SELECT status FROM swap_requests WHERE id = $1`, req.ID).Scan(&status); err != nil {
		t.Fatal(err)
	}
	if status != "accepted" {
		t.Fatalf("status %q want accepted", status)
	}
}
