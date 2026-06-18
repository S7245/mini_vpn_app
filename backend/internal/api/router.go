package api

import (
	"database/sql"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/S7245/mini_vpn_app/backend/internal/auth"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/store"
)

// Server bundles dependencies shared by handlers.
type Server struct {
	q   *store.Queries
	db  *sql.DB
	tm  *auth.TokenManager
	cfg config.Config
}

// NewServer wires a chi router with all routes.
func NewServer(db *sql.DB, cfg config.Config) *chi.Mux {
	s := &Server{
		q:   store.New(db),
		db:  db,
		tm:  auth.NewTokenManager(cfg.JWTSecret, cfg.AccessTTL),
		cfg: cfg,
	}
	r := chi.NewRouter()
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, 200, map[string]string{"status": "ok"})
	})

	// public
	r.Post("/auth/register", s.handleRegister)
	r.Post("/auth/login", s.handleLogin)
	r.Post("/auth/refresh", s.handleRefresh)

	// authenticated
	r.Group(func(r chi.Router) {
		r.Use(s.requireAuth)
		r.Post("/auth/logout", s.handleLogout)
		r.Put("/auth/password", s.handleChangePassword)
		r.Get("/subscription", s.handleGetSubscription)
		r.Get("/devices", s.handleListDevices)
		r.Post("/devices", s.handleRegisterDevice)
		r.Delete("/devices/{deviceId}", s.handleRevokeDevice)
		r.Get("/nodes", s.handleListNodes)
		r.Post("/nodes/select-best", s.handleSelectBest)
		r.Post("/purchases/subscription", s.handlePurchaseStub)
		r.Post("/purchases/dedicated-ip", s.handlePurchaseStub)
	})
	return r
}
