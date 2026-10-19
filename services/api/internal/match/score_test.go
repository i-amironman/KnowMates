package match

import "testing"

func TestScoreLanguageAndGap(t *testing.T) {
	got := Score(Input{LanguageMatch: true, OverlapMinutes: 120, ProficiencyGap: 2, RatingAvg: 5, RatingCount: 3})
	// 50 + 20 + 2 + 10 + 5
	if got != 87 {
		t.Fatalf("score %d", got)
	}
}
