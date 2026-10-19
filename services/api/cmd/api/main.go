package main

import (
	"log"
	"net/http"
	"os"

	apihttp "knowmates/services/api/internal/http"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	srv := apihttp.NewServer(nil)
	log.Fatal(http.ListenAndServe(addr, srv.Handler()))
}
