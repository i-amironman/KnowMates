package call

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"strconv"
	"time"

	"github.com/google/uuid"
)

func TurnCreds(secret string, userID uuid.UUID, now time.Time) (string, string, time.Time) {
	exp := now.UTC().Add(time.Hour).Truncate(time.Second)
	username := strconv.FormatInt(exp.Unix(), 10) + ":" + userID.String()
	mac := hmac.New(sha1.New, []byte(secret))
	mac.Write([]byte(username))
	return username, base64.StdEncoding.EncodeToString(mac.Sum(nil)), exp
}
