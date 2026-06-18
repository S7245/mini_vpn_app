package main

import (
	"context"
	"database/sql"
	"log"

	_ "github.com/jackc/pgx/v5/stdlib"

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
	if err := store.Migrate(db); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	ctx := context.Background()

	// Idempotent: clear existing shared nodes, then re-insert the dev set.
	if _, err := db.ExecContext(ctx, `DELETE FROM nodes WHERE owner_id IS NULL`); err != nil {
		log.Fatalf("clear shared nodes: %v", err)
	}
	q := store.New(db)
	seeds := []store.SeedNodeParams{
		{Kind: "shared", Region: "US", City: "Los Angeles", LatencyMs: 142, Load: 0.37, Tier: sql.NullString{String: "standard", Valid: true}},
		{Kind: "shared", Region: "JP", City: "Tokyo", LatencyMs: 58, Load: 0.61, Tier: sql.NullString{String: "premium", Valid: true}},
		{Kind: "shared", Region: "SG", City: "Singapore", LatencyMs: 73, Load: 0.45, Tier: sql.NullString{String: "standard", Valid: true}},
	}
	for _, sd := range seeds {
		if err := q.SeedNode(ctx, sd); err != nil {
			log.Fatalf("seed node %s: %v", sd.City, err)
		}
	}
	log.Printf("seeded %d shared nodes", len(seeds))
}
