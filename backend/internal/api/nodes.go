package api

import (
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

func toNodeBody(n store.Node) map[string]any {
	if n.Kind == "dedicated" {
		var exp string
		if n.ExpiresAt.Valid {
			exp = n.ExpiresAt.Time.UTC().Format(time.RFC3339)
		}
		return map[string]any{
			"id": n.ID, "kind": "dedicated", "region": n.Region, "city": n.City,
			"label": n.Label.String, "static_ip": n.StaticIp.String, "expires_at": exp,
			"latency_ms": int(n.LatencyMs), "load": n.Load,
		}
	}
	return map[string]any{
		"id": n.ID, "kind": "shared", "region": n.Region, "city": n.City,
		"latency_ms": int(n.LatencyMs), "load": n.Load, "tier": n.Tier.String,
	}
}

func (s *Server) handleListNodes(w http.ResponseWriter, r *http.Request) {
	// owner_id is a nullable uuid; the JWT subject is the user's uuid string.
	// Parse it and pass Valid:true so the user's dedicated nodes are included.
	owner := uuid.NullUUID{}
	if uid, err := uuid.Parse(userID(r)); err == nil {
		owner = uuid.NullUUID{UUID: uid, Valid: true}
	}
	rows, err := s.q.ListNodesForUser(r.Context(), owner)
	if err != nil {
		writeError(w, 500, "internal", "list failed")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, n := range rows {
		out = append(out, toNodeBody(n))
	}
	writeJSON(w, 200, map[string]any{"nodes": out})
}

func (s *Server) handleSelectBest(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.ListSharedNodesByScore(r.Context())
	if err != nil || len(rows) == 0 {
		writeError(w, 503, "no_nodes", "no eligible node")
		return
	}
	writeJSON(w, 200, map[string]any{
		"node_id": rows[0].ID,
		"reason":  "lowest latency among eligible nodes",
	})
}
