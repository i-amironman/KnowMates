package credits

import (
	"errors"
	"net/url"
)

var ErrBadMeetingURL = errors.New("bad_meeting_url")

// ValidMeetingURL accepts empty input or an https URL (8–300 chars, no userinfo).
func ValidMeetingURL(raw string) (string, error) {
	if raw == "" {
		return "", nil
	}
	if len(raw) < 8 || len(raw) > 300 {
		return "", ErrBadMeetingURL
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Host == "" {
		return "", ErrBadMeetingURL
	}
	return raw, nil
}
