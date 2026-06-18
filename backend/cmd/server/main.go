package main

import (
	"database/sql"
	"log"
	"net/http"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/S7245/mini_vpn_app/backend/internal/api"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("db ping: %v", err)
	}
	if err := store.Migrate(db); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	log.Printf("listening on :%s", cfg.Port)
	if err := http.ListenAndServe(":"+cfg.Port, api.NewServer(db, cfg)); err != nil {
		log.Fatal(err)
	}
}
