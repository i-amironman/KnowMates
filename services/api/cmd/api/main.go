package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/redis/go-redis/v9"

	apihttp "knowmates/services/api/internal/http"
	"knowmates/services/api/internal/store"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	var deps apihttp.Deps
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		ctx := context.Background()
		st, err := store.Open(ctx, dsn)
		if err != nil {
			log.Fatal(err)
		}
		if err := st.Migrate(ctx); err != nil {
			log.Fatal(err)
		}
		deps.Users = st
		deps.SignIn = st
		deps.Sessions = st
	}
	if sec := os.Getenv("AUTH_SECRET"); sec != "" {
		deps.Secret = []byte(sec)
	}
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
