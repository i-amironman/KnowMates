package main

import (
	"context"
	"log"
	"net/http"
	"os"
	_ "time/tzdata" // ponytail: Alpine API image has no zoneinfo; LoadLocation needs embedded IANA data

	"github.com/redis/go-redis/v9"

	"knowmates/services/api/internal/avatar"
	apihttp "knowmates/services/api/internal/http"
	"knowmates/services/api/internal/mail"
	"knowmates/services/api/internal/push"
	"knowmates/services/api/internal/store"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	var deps apihttp.Deps
	ctx := context.Background()
	var st *store.Store
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		var err error
		st, err = store.Open(ctx, dsn)
		if err != nil {
			log.Fatal(err)
		}
		if err := st.Migrate(ctx); err != nil {
			log.Fatal(err)
		}
		deps.Users = st
		deps.SignIn = st
		deps.Sessions = st
		deps.Profiles = st
		deps.Skills = st
		deps.Discover = st
		deps.Requests = st
		deps.Bookings = st
		deps.Calls = st
		deps.Safety = st
		deps.EmailVerified = st
		deps.VerifyTokens = st
		deps.UserEmail = st
		deps.Devices = st
		deps.Notifications = st
		deps.Chats = st
		if readDSN := os.Getenv("DATABASE_READ_URL"); readDSN != "" {
			if err := st.AttachReadPool(ctx, readDSN); err != nil {
				log.Fatal(err)
			}
		}
	}
	if dir := os.Getenv("ASSET_DIR"); dir != "" {
		publicBase := os.Getenv("PUBLIC_BASE")
		if publicBase == "" {
			publicBase = "http://localhost:8080"
		}
		disk := &avatar.DiskStore{Dir: dir, PublicBase: publicBase}
		deps.Avatars = disk
		if st != nil {
			if err := avatar.EnsureDefaultPool(ctx, st, disk); err != nil {
				log.Fatal("default avatars: ", err)
			}
		}
	}
	if sec := os.Getenv("AUTH_SECRET"); sec != "" {
		deps.Secret = []byte(sec)
	}
	deps.Mail = mail.SenderFromEnv()
	deps.Push = push.PusherFromEnv()
	deps.PublicHost = os.Getenv("PUBLIC_HOST")
	if redisURL := os.Getenv("REDIS_URL"); redisURL != "" {
		opts, err := redis.ParseURL(redisURL)
		if err != nil {
			log.Fatal(err)
		}
		deps.Redis = redis.NewClient(opts)
	}
	srv := apihttp.NewServer(deps)
	log.Fatal(http.ListenAndServe(addr, srv.Handler()))
}
