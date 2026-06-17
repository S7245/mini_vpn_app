package testutil

import (
	"database/sql"
	"fmt"
	"testing"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/ory/dockertest/v3"
	"github.com/ory/dockertest/v3/docker"

	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

// NewPostgres spins up an ephemeral Postgres container, runs migrations, and
// returns an open *sql.DB. It registers cleanup on t. If Docker is not
// available the test is skipped (not failed).
func NewPostgres(t *testing.T) *sql.DB {
	t.Helper()
	pool, err := dockertest.NewPool("")
	if err != nil {
		t.Skipf("docker not available: %v", err)
	}
	if err := pool.Client.Ping(); err != nil {
		t.Skipf("docker daemon not reachable: %v", err)
	}
	res, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "postgres",
		Tag:        "16-alpine",
		Env: []string{
			"POSTGRES_PASSWORD=postgres",
			"POSTGRES_USER=postgres",
			"POSTGRES_DB=mini_vpn",
		},
	}, func(c *docker.HostConfig) {
		c.AutoRemove = true
		c.RestartPolicy = docker.RestartPolicy{Name: "no"}
	})
	if err != nil {
		t.Fatalf("could not start postgres: %v", err)
	}
	t.Cleanup(func() { _ = pool.Purge(res) })

	dsn := fmt.Sprintf("postgres://postgres:postgres@localhost:%s/mini_vpn?sslmode=disable", res.GetPort("5432/tcp"))
	var db *sql.DB
	pool.MaxWait = 60 * time.Second
	if err := pool.Retry(func() error {
		var e error
		db, e = sql.Open("pgx", dsn)
		if e != nil {
			return e
		}
		return db.Ping()
	}); err != nil {
		t.Fatalf("could not connect to postgres: %v", err)
	}
	if err := store.Migrate(db); err != nil {
		t.Fatalf("migrate failed: %v", err)
	}
	return db
}
