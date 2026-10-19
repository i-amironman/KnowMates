package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"golang.org/x/oauth2/google"
)

// Pusher delivers a notification to one device token.
type Pusher interface {
	Send(ctx context.Context, token, title, body string) error
}

// LogPusher records pushes when FCM is not configured.
type LogPusher struct{}

func (LogPusher) Send(_ context.Context, token, title, body string) error {
	log.Printf("push: token=%q title=%q body=%q", token, title, body)
	return nil
}

type fcmPusher struct {
	projectID string
	client    *http.Client
	src       syncTokenSource
}

type syncTokenSource struct {
	mu sync.Mutex
	f  func() (string, error)
}

func (s *syncTokenSource) token() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.f()
}

// PusherFromEnv returns LogPusher when FCM_CREDENTIALS_FILE is empty or invalid.
func PusherFromEnv() Pusher {
	path := os.Getenv("FCM_CREDENTIALS_FILE")
	if path == "" {
		return LogPusher{}
	}
	p, err := newFCMPusher(path)
	if err != nil {
		log.Printf("push: FCM disabled: %v", err)
		return LogPusher{}
	}
	return p
}

func newFCMPusher(path string) (Pusher, error) {
	ctx := context.Background()
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	creds, err := google.CredentialsFromJSON(ctx, raw, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil {
		return nil, err
	}
	projectID := creds.ProjectID
	if projectID == "" {
		var meta struct {
			ProjectID string `json:"project_id"`
		}
		if err := json.Unmarshal(raw, &meta); err != nil {
			return nil, err
		}
		projectID = meta.ProjectID
	}
	if projectID == "" {
		return nil, fmt.Errorf("push: missing project_id in credentials")
	}
	ts := creds.TokenSource
	return &fcmPusher{
		projectID: projectID,
		client:    &http.Client{Timeout: 15 * time.Second},
		src: syncTokenSource{f: func() (string, error) {
			tok, err := ts.Token()
			if err != nil {
				return "", err
			}
			return tok.AccessToken, nil
		}},
	}, nil
}

func (p *fcmPusher) Send(ctx context.Context, token, title, body string) error {
	access, err := p.src.token()
	if err != nil {
		return err
	}
	payload, err := json.Marshal(map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
		},
	})
	if err != nil {
		return err
	}
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", p.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+access)
	req.Header.Set("Content-Type", "application/json")
	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	return fmt.Errorf("push: fcm status %d: %s", resp.StatusCode, bytes.TrimSpace(b))
}
