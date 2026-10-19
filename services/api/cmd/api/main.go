package main

import (
	"context"
	"log"
	"net/http"
	"os"

	apihttp "knowmates/services/api/internal/http"
	"knowmates/services/api/internal/store"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	var users apihttp.Users // stays a nil interface when there is no database
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		ctx := context.Background()
		st, err := store.Open(ctx, dsn)
		if err != nil {
			log.Fatal(err)
		}
		if err := st.Migrate(ctx); err != nil {
			log.Fatal(err)
		}
		users = st
	}
	srv := apihttp.NewServer(users)
	log.Fatal(http.ListenAndServe(addr, srv.Handler()))
}
