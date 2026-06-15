package api

import (
	"net/http"
	"time"
)

type subscriptionBody struct {
	Plan        string  `json:"plan"`
	Status      string  `json:"status"`
	ExpiresAt   *string `json:"expires_at"`
	DeviceLimit int     `json:"device_limit"`
}

func (s *Server) handleGetSubscription(w http.ResponseWriter, r *http.Request) {
	sub, err := s.q.GetSubscription(r.Context(), userID(r))
	if err != nil {
		writeError(w, 404, "not_found", "no subscription")
		return
	}
	var exp *string
	if sub.ExpiresAt.Valid {
		v := sub.ExpiresAt.Time.UTC().Format(time.RFC3339)
		exp = &v
	}
	writeJSON(w, 200, subscriptionBody{
		Plan:        sub.Plan,
		Status:      sub.Status,
		ExpiresAt:   exp,
		DeviceLimit: int(sub.DeviceLimit),
	})
}
