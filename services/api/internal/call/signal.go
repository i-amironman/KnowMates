package call

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"knowmates/services/api/internal/store"
)

const chatRateLimit = 30

// CallMessages persists and loads in-call chat rows.
type CallMessages interface {
	InsertCallMessage(ctx context.Context, sessionID, sender uuid.UUID, body string) (id uuid.UUID, created time.Time, err error)
	CallHistory(ctx context.Context, sessionID uuid.UUID) ([]store.CallMessage, error)
}

type ChatLimiter interface {
	Incr(ctx context.Context, key string) *redis.IntCmd
	Expire(ctx context.Context, key string, expiration time.Duration) *redis.BoolCmd
}

type SignalRedis interface {
	ChatLimiter
	Publish(ctx context.Context, channel string, message interface{}) *redis.IntCmd
	Subscribe(ctx context.Context, channels ...string) *redis.PubSub
}

func channelName(sessionID uuid.UUID) string {
	return "call:" + sessionID.String()
}

func chatKey(sessionID, userID uuid.UUID) string {
	return "chat:" + sessionID.String() + ":" + userID.String()
}

// RunSignal handles one WebSocket after admission; closes the connection on return.
func RunSignal(ctx context.Context, conn *websocket.Conn, redis SignalRedis, msgs CallMessages, sessionID, userID, peerID uuid.UUID) {
	defer conn.Close(websocket.StatusNormalClosure, "")

	pubsub := redis.Subscribe(ctx, channelName(sessionID))
	defer pubsub.Close()

	peerJoined, _ := json.Marshal(map[string]any{
		"type": "peer", "from": userID.String(), "joined": true,
	})
	_, _ = redis.Publish(ctx, channelName(sessionID), peerJoined).Result()

	history, err := msgs.CallHistory(ctx, sessionID)
	if err != nil {
		return
	}
	if history == nil {
		history = []store.CallMessage{}
	}
	histPayload, _ := json.Marshal(map[string]any{"type": "history", "messages": history})
	ctxWS := ctx
	if err := conn.Write(ctxWS, websocket.MessageText, histPayload); err != nil {
		return
	}

	go func() {
		for msg := range pubsub.Channel() {
			var frame struct {
				Type string `json:"type"`
				From string `json:"from"`
			}
			if err := json.Unmarshal([]byte(msg.Payload), &frame); err != nil {
				continue
			}
			if frame.From != peerID.String() {
				continue
			}
			_ = conn.Write(ctxWS, websocket.MessageText, []byte(msg.Payload))
		}
	}()

	defer func() {
		left, _ := json.Marshal(map[string]any{
			"type": "peer", "from": userID.String(), "joined": false,
		})
		_, _ = redis.Publish(context.Background(), channelName(sessionID), left).Result()
	}()

	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			return
		}
		var in struct {
			Type string          `json:"type"`
			Body string          `json:"body"`
			SDP  string          `json:"sdp"`
			On   *bool           `json:"on"`
			Raw  json.RawMessage `json:"-"`
		}
		if err := json.Unmarshal(data, &in); err != nil {
			conn.Close(websocket.StatusPolicyViolation, "bad json")
			return
		}

		switch in.Type {
		case "offer", "answer", "ice", "share", "hangup":
			out, err := addFrom(data, userID)
			if err != nil {
				conn.Close(websocket.StatusPolicyViolation, "bad frame")
				return
			}
			_, _ = redis.Publish(ctx, channelName(sessionID), out).Result()
		case "chat":
			n := len(strings.TrimSpace(in.Body))
			if n < 1 || n > 500 {
				conn.Close(websocket.StatusPolicyViolation, "bad chat body")
				return
			}
			key := chatKey(sessionID, userID)
			cnt, err := redis.Incr(ctx, key).Result()
			if err != nil {
				return
			}
			if cnt == 1 {
				_ = redis.Expire(ctx, key, 60*time.Second).Err()
			}
			if cnt > chatRateLimit {
				errPayload, _ := json.Marshal(map[string]string{"type": "error", "error": "chat_limited"})
				_ = conn.Write(ctx, websocket.MessageText, errPayload)
				conn.Close(websocket.StatusPolicyViolation, "chat_limited")
				return
			}
			id, created, err := msgs.InsertCallMessage(ctx, sessionID, userID, in.Body)
			if err != nil {
				return
			}
			out, _ := json.Marshal(map[string]any{
				"type": "chat", "id": id, "from": userID, "body": in.Body, "createdAt": created,
			})
			_, _ = redis.Publish(ctx, channelName(sessionID), out).Result()
		default:
			conn.Close(websocket.StatusPolicyViolation, "unknown type")
			return
		}
	}
}

func addFrom(raw []byte, userID uuid.UUID) ([]byte, error) {
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}
	m["from"] = userID.String()
	return json.Marshal(m)
}

// SplitTURNURLs splits a comma-separated TURN_URLS env value.
func SplitTURNURLs(urls string) []string {
	if urls == "" {
		return []string{}
	}
	parts := strings.Split(urls, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func TicketJSON(secret, turnURLs string, userID uuid.UUID, now time.Time) map[string]any {
	stun := []string{"stun:stun.cloudflare.com:3478"}
	out := map[string]any{
		"stun": stun, "turn": []string{}, "username": "", "password": "", "ttlSeconds": 3600,
	}
	if secret == "" {
		return out
	}
	user, pass, _ := TurnCreds(secret, userID, now)
	out["turn"] = SplitTURNURLs(turnURLs)
	out["username"] = user
	out["password"] = pass
	return out
}

// AdmissionError classifies call entry for HTTP/WebSocket responses.
func AdmissionError(participant, canJoin bool) string {
	if !participant {
		return "forbidden"
	}
	if !canJoin {
		return "call_closed"
	}
	return ""
}

func PeerID(sessLearner, sessTeacher, userID uuid.UUID) (uuid.UUID, error) {
	switch userID {
	case sessLearner:
		return sessTeacher, nil
	case sessTeacher:
		return sessLearner, nil
	default:
		return uuid.Nil, fmt.Errorf("not participant")
	}
}
