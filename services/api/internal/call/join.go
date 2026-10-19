package call

import "time"

func CanJoin(now time.Time, status string, starts time.Time) bool {
	if status != "scheduled" {
		return false
	}
	return !now.Before(starts.Add(-10 * time.Minute))
}
