package store

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestReview(t *testing.T) {
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
	goal := "I want to learn this skill well."
	start := time.Now().UTC().Add(24 * time.Hour).Truncate(time.Minute)
	end := start.Add(time.Hour)

	learnerU, err := s.CreateUser(ctx, fmt.Sprintf("learner.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	learner, _ := uuid.Parse(learnerU.ID)
	nameL := "Learner"
	if err := s.UpdateProfile(ctx, learner, ProfilePatch{DisplayName: &nameL, Gender: strPtr("female")}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, learner,
		[]SkillLevel{{SkillID: learnOther, Proficiency: 1}},
		[]SkillLevel{{SkillID: skill, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, learner, []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, learner); err != nil {
		t.Fatal(err)
	}

	teacherU, err := s.CreateUser(ctx, fmt.Sprintf("teacher.%d@example.com", time.Now().UnixNano()), "hash", birth, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	teacher, _ := uuid.Parse(teacherU.ID)
	nameT := "Teacher"
	if err := s.UpdateProfile(ctx, teacher, ProfilePatch{DisplayName: &nameT, Gender: strPtr("male")}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceSkills(ctx, teacher, []SkillLevel{{SkillID: skill, Proficiency: 4}}, []SkillLevel{{SkillID: learnOther, Proficiency: 2}}); err != nil {
		t.Fatal(err)
	}
	if err := s.ReplaceAvailability(ctx, teacher, []Slot{{Weekday: 1, StartMin: 540, EndMin: 600}}); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReady(ctx, teacher); err != nil {
		t.Fatal(err)
	}

	req, err := s.CreateRequest(ctx, learner, teacher, skill, goal)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.SetRequestStatus(ctx, req.ID, teacher, "accepted"); err != nil {
		t.Fatal(err)
	}
	sess, err := s.Schedule(ctx, req.ID, learner, start, end, "")
	if err != nil {
		t.Fatal(err)
	}

	if err := s.CreateReview(ctx, sess.ID, learner, 5, "great"); err != ErrConflict {
		t.Fatalf("scheduled review: want ErrConflict, got %v", err)
	}

	if _, err := s.Complete(ctx, sess.ID, learner); err != nil {
		t.Fatal(err)
	}
	if st, err := s.Complete(ctx, sess.ID, teacher); err != nil || st != "completed" {
		t.Fatalf("complete: status %q err %v", st, err)
	}

	if err := s.CreateReview(ctx, sess.ID, learner, 4, "solid session"); err != nil {
		t.Fatalf("first review: %v", err)
	}
	if err := s.CreateReview(ctx, sess.ID, learner, 3, "again"); err != ErrConflict {
		t.Fatalf("duplicate review: want ErrConflict, got %v", err)
	}
}
