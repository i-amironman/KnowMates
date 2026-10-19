package match

type Input struct {
	LanguageMatch  bool
	OverlapMinutes int
	ProficiencyGap int // teacher proficiency minus learner proficiency
	RatingAvg      float64
	RatingCount    int
}

func Score(in Input) int {
	s := 50 // skill already matched
	if in.LanguageMatch {
		s += 20
	}
	hours := in.OverlapMinutes / 60
	if hours > 15 {
		hours = 15
	}
	s += hours
	if in.ProficiencyGap >= 1 && in.ProficiencyGap <= 3 {
		s += 10
	}
	if in.RatingCount >= 3 {
		s += int(in.RatingAvg) // 1..5
	}
	return s
}
