package api_test

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/S7245/mini_vpn_app/backend/internal/api"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/store"
	"github.com/S7245/mini_vpn_app/backend/internal/testutil"
)

func TestListNodesAndSelectBest(t *testing.T) {
	db := testutil.NewPostgres(t)
	cfg := config.Config{JWTSecret: "test-secret", AccessTTL: 3600_000_000_000, RefreshTTL: 3600_000_000_000}
	srv := httptest.NewServer(api.NewServer(db, cfg))
	t.Cleanup(srv.Close)

	q := store.New(db)
	ctx := context.Background()
	// two shared nodes
	if err := q.SeedNode(ctx, store.SeedNodeParams{Kind: "shared", Region: "US", City: "LA", LatencyMs: 142, Load: 0.37, Tier: sql.NullString{String: "standard", Valid: true}}); err != nil {
		t.Fatal(err)
	}
	if err := q.SeedNode(ctx, store.SeedNodeParams{Kind: "shared", Region: "JP", City: "Tokyo", LatencyMs: 58, Load: 0.61, Tier: sql.NullString{String: "premium", Valid: true}}); err != nil {
		t.Fatal(err)
	}

	tok := registerAndToken(t, srv.URL, "node@b.com")

	// seed a DEDICATED node owned by this user — must appear in THEIR list only
	u, err := q.GetUserByEmail(ctx, "node@b.com")
	if err != nil {
		t.Fatal(err)
	}
	owner, err := uuid.Parse(u.ID)
	if err != nil {
		t.Fatalf("user id not a uuid: %v", err)
	}
	if err := q.SeedNode(ctx, store.SeedNodeParams{
		Kind: "dedicated", Region: "EU", City: "Frankfurt", LatencyMs: 30, Load: 0.10,
		Label: sql.NullString{String: "my-ip", Valid: true}, StaticIp: sql.NullString{String: "203.0.113.7", Valid: true},
		OwnerID: uuid.NullUUID{UUID: owner, Valid: true},
	}); err != nil {
		t.Fatal(err)
	}

	resp := getJSON(t, srv.URL+"/nodes", tok)
	if resp.StatusCode != 200 {
		t.Fatalf("nodes status %d", resp.StatusCode)
	}
	var nl struct {
		Nodes []map[string]any `json:"nodes"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&nl)
	// 2 shared + 1 owned dedicated
	if len(nl.Nodes) != 3 {
		t.Fatalf("expected 3 nodes (2 shared + 1 owned dedicated), got %d: %+v", len(nl.Nodes), nl.Nodes)
	}
	var sawDedicated, sawShared bool
	for _, n := range nl.Nodes {
		switch n["kind"] {
		case "dedicated":
			sawDedicated = true
			if n["static_ip"] == nil || n["static_ip"] == "" {
				t.Fatalf("dedicated node missing static_ip: %+v", n)
			}
		case "shared":
			sawShared = true
			if n["tier"] == nil {
				t.Fatalf("shared node missing tier: %+v", n)
			}
		}
	}
	if !sawDedicated || !sawShared {
		t.Fatalf("expected both shared and dedicated nodes; sawShared=%v sawDedicated=%v", sawShared, sawDedicated)
	}

	resp = postJSON(t, srv.URL+"/nodes/select-best", nil, tok)
	if resp.StatusCode != 200 {
		t.Fatalf("select-best status %d", resp.StatusCode)
	}
	var best struct {
		NodeID string `json:"node_id"`
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&best)
	if best.NodeID == "" || best.Reason == "" {
		t.Fatalf("bad select-best: %+v", best)
	}
}

// A second user must NOT see the first user's dedicated node.
func TestDedicatedNodeIsOwnerScoped(t *testing.T) {
	db := testutil.NewPostgres(t)
	cfg := config.Config{JWTSecret: "test-secret", AccessTTL: 3600_000_000_000, RefreshTTL: 3600_000_000_000}
	srv := httptest.NewServer(api.NewServer(db, cfg))
	t.Cleanup(srv.Close)

	q := store.New(db)
	ctx := context.Background()
	if err := q.SeedNode(ctx, store.SeedNodeParams{Kind: "shared", Region: "US", City: "LA", LatencyMs: 142, Load: 0.37, Tier: sql.NullString{String: "standard", Valid: true}}); err != nil {
		t.Fatal(err)
	}

	ownerTok := registerAndToken(t, srv.URL, "owner@b.com")
	_ = ownerTok
	u, err := q.GetUserByEmail(ctx, "owner@b.com")
	if err != nil {
		t.Fatal(err)
	}
	owner, _ := uuid.Parse(u.ID)
	if err := q.SeedNode(ctx, store.SeedNodeParams{
		Kind: "dedicated", Region: "EU", City: "Frankfurt", LatencyMs: 30, Load: 0.10,
		Label: sql.NullString{String: "my-ip", Valid: true}, StaticIp: sql.NullString{String: "203.0.113.7", Valid: true},
		OwnerID: uuid.NullUUID{UUID: owner, Valid: true},
	}); err != nil {
		t.Fatal(err)
	}

	// a DIFFERENT user should see only the shared node, not the dedicated one
	otherTok := registerAndToken(t, srv.URL, "other@b.com")
	resp := getJSON(t, srv.URL+"/nodes", otherTok)
	var nl struct {
		Nodes []map[string]any `json:"nodes"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&nl)
	if len(nl.Nodes) != 1 {
		t.Fatalf("other user should see only 1 shared node, got %d: %+v", len(nl.Nodes), nl.Nodes)
	}
	if nl.Nodes[0]["kind"] != "shared" {
		t.Fatalf("other user should not see dedicated node: %+v", nl.Nodes)
	}
}
