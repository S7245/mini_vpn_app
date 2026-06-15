package api

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

type deviceBody struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Platform   string `json:"platform"`
	LastSeenAt string `json:"last_seen_at"`
	CreatedAt  string `json:"created_at"`
}

func toDeviceBody(d store.Device) deviceBody {
	return deviceBody{
		ID:         d.ID,
		Name:       d.Name,
		Platform:   d.Platform,
		LastSeenAt: d.LastSeenAt.UTC().Format(time.RFC3339),
		CreatedAt:  d.CreatedAt.UTC().Format(time.RFC3339),
	}
}

func (s *Server) handleListDevices(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	rows, err := s.q.ListDevices(r.Context(), uid)
	if err != nil {
		writeError(w, 500, "internal", "list failed")
		return
	}
	sub, err := s.q.GetSubscription(r.Context(), uid)
	if err != nil {
		writeError(w, 500, "internal", "subscription read failed")
		return
	}
	out := make([]deviceBody, 0, len(rows))
	for _, d := range rows {
		out = append(out, toDeviceBody(d))
	}
	writeJSON(w, 200, map[string]any{"devices": out, "device_limit": int(sub.DeviceLimit)})
}

type deviceRegistration struct {
	Name     string `json:"name"`
	Platform string `json:"platform"`
}

// Amendment B: register inside a tx, locking the subscription row first
// (GetSubscriptionForUpdate => SELECT … FOR UPDATE) so two concurrent registers
// for the same user are serialized and cannot both pass the count check (TOCTOU).
func (s *Server) handleRegisterDevice(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	var req deviceRegistration
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" || req.Platform == "" {
		writeError(w, 400, "invalid_request", "name and platform required")
		return
	}

	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, 500, "internal", "tx begin failed")
		return
	}
	defer func() { _ = tx.Rollback() }() // no-op after a successful Commit
	qtx := s.q.WithTx(tx)

	// Lock the subscription row; concurrent registers for this user block here.
	sub, err := qtx.GetSubscriptionForUpdate(r.Context(), uid)
	if err != nil {
		writeError(w, 500, "internal", "subscription read failed")
		return
	}
	count, err := qtx.CountDevices(r.Context(), uid)
	if err != nil {
		writeError(w, 500, "internal", "count failed")
		return
	}
	if count >= int64(sub.DeviceLimit) {
		writeError(w, 409, "device_limit_exceeded", "device limit reached")
		return
	}
	d, err := qtx.CreateDevice(r.Context(), store.CreateDeviceParams{UserID: uid, Name: req.Name, Platform: req.Platform})
	if err != nil {
		writeError(w, 500, "internal", "create failed")
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, 500, "internal", "commit failed")
		return
	}
	writeJSON(w, 201, toDeviceBody(d))
}

func (s *Server) handleRevokeDevice(w http.ResponseWriter, r *http.Request) {
	if err := s.q.DeleteDevice(r.Context(), store.DeleteDeviceParams{ID: chi.URLParam(r, "deviceId"), UserID: userID(r)}); err != nil {
		writeError(w, 500, "internal", "delete failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
