package store

import (
	"testing"
	"time"
)

func TestUnder18Rejected(t *testing.T) {
	birth := time.Date(2010, 1, 1, 0, 0, 0, 0, time.UTC)
	today := time.Date(2026, 10, 19, 0, 0, 0, 0, time.UTC)
	if AgeYears(birth, today) >= 18 {
		t.Fatal("expected under 18")
	}
}

func TestAgeYearsBirthdayBoundary(t *testing.T) {
	birth := time.Date(2008, 10, 19, 0, 0, 0, 0, time.UTC)
	if got := AgeYears(birth, time.Date(2026, 10, 18, 0, 0, 0, 0, time.UTC)); got != 17 {
		t.Fatalf("day before 18th birthday: got %d", got)
	}
	if got := AgeYears(birth, time.Date(2026, 10, 19, 0, 0, 0, 0, time.UTC)); got != 18 {
		t.Fatalf("on 18th birthday: got %d", got)
	}
}
