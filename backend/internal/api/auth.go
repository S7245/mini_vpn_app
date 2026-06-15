package api

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/S7245/mini_vpn_app/backend/internal/auth"
	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type tokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

func (s *Server) issueTokens(w http.ResponseWriter, r *http.Request, userID string, status int) {
	access, err := s.tm.NewAccessToken(userID)
	if err != nil {
		writeError(w, 500, "internal", "token mint failed")
		return
	}
	raw, hash, err := auth.NewRefreshToken()
	if err != nil {
		writeError(w, 500, "internal", "token mint failed")
		return
	}
	if err := s.q.CreateRefreshToken(r.Context(), store.CreateRefreshTokenParams{
		UserID:    userID,
		TokenHash: hash,
		ExpiresAt: time.Now().Add(s.cfg.RefreshTTL),
	}); err != nil {
		writeError(w, 500, "internal", "token persist failed")
		return
	}
	writeJSON(w, status, tokenPair{
		AccessToken:  access,
		RefreshToken: raw,
		TokenType:    "Bearer",
		ExpiresIn:    s.tm.AccessTTLSeconds(),
	})
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil || c.Email == "" || len(c.Password) < 8 {
		writeError(w, 400, "invalid_request", "email and password (>=8) required")
		return
	}
	hash, err := auth.HashPassword(c.Password)
	if err != nil {
		writeError(w, 500, "internal", "hash failed")
		return
	}
	u, err := s.q.CreateUser(r.Context(), store.CreateUserParams{Email: c.Email, PasswordHash: hash})
	if err != nil {
		writeError(w, 409, "email_taken", "email already registered")
		return
	}
	// default free subscription, 1 device
	if err := s.q.CreateSubscription(r.Context(), store.CreateSubscriptionParams{
		UserID:      u.ID,
		Plan:        "free",
		Status:      "active",
		ExpiresAt:   sql.NullTime{},
		DeviceLimit: 1,
	}); err != nil {
		writeError(w, 500, "internal", "subscription init failed")
		return
	}
	s.issueTokens(w, r, u.ID, 201)
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		writeError(w, 400, "invalid_request", "bad body")
		return
	}
	u, err := s.q.GetUserByEmail(r.Context(), c.Email)
	if err != nil || !auth.CheckPassword(u.PasswordHash, c.Password) {
		writeError(w, 401, "invalid_credentials", "email or password incorrect")
		return
	}
	s.issueTokens(w, r, u.ID, 200)
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RefreshToken == "" {
		writeError(w, 400, "invalid_request", "refresh_token required")
		return
	}
	rec, err := s.q.GetRefreshToken(r.Context(), auth.HashRefreshToken(req.RefreshToken))
	if err != nil || rec.Revoked || rec.ExpiresAt.Before(time.Now()) {
		writeError(w, 401, "invalid_token", "refresh token invalid")
		return
	}
	// rotate: revoke the presented token, issue a fresh pair
	_ = s.q.RevokeRefreshToken(r.Context(), rec.TokenHash)
	s.issueTokens(w, r, rec.UserID, 200)
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	if err := s.q.RevokeAllUserTokens(r.Context(), userID(r)); err != nil {
		writeError(w, 500, "internal", "logout failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type changePasswordRequest struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password"`
}

func (s *Server) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	var req changePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.NewPassword) < 8 {
		writeError(w, 400, "invalid_request", "new_password (>=8) required")
		return
	}
	u, err := s.q.GetUserByID(r.Context(), userID(r))
	if err != nil {
		writeError(w, 404, "not_found", "user gone")
		return
	}
	if !auth.CheckPassword(u.PasswordHash, req.OldPassword) {
		writeError(w, 401, "invalid_credentials", "old password incorrect")
		return
	}
	hash, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		writeError(w, 500, "internal", "hash failed")
		return
	}
	if err := s.q.UpdatePassword(r.Context(), store.UpdatePasswordParams{ID: u.ID, PasswordHash: hash}); err != nil {
		writeError(w, 500, "internal", "update failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
