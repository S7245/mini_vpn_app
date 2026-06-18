package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/S7245/mini_vpn_app/backend/internal/api"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/testutil"
)

func testServer(t *testing.T) *httptest.Server {
	db := testutil.NewPostgres(t)
	cfg := config.Config{JWTSecret: "test-secret", AccessTTL: 3600_000_000_000, RefreshTTL: 3600_000_000_000}
	srv := httptest.NewServer(api.NewServer(db, cfg))
	t.Cleanup(srv.Close)
	return srv
}

func postJSON(t *testing.T, url string, body any, bearer string) *http.Response {
	t.Helper()
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", url, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func TestRegisterLoginRefresh(t *testing.T) {
	srv := testServer(t)

	// register
	resp := postJSON(t, srv.URL+"/auth/register", map[string]string{"email": "a@b.com", "password": "password123"}, "")
	if resp.StatusCode != 201 {
		t.Fatalf("register status %d", resp.StatusCode)
	}
	var reg struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		TokenType    string `json:"token_type"`
		ExpiresIn    int    `json:"expires_in"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&reg)
	if reg.AccessToken == "" || reg.RefreshToken == "" || reg.TokenType != "Bearer" || reg.ExpiresIn == 0 {
		t.Fatalf("bad token pair: %+v", reg)
	}

	// login
	resp = postJSON(t, srv.URL+"/auth/login", map[string]string{"email": "a@b.com", "password": "password123"}, "")
	if resp.StatusCode != 200 {
		t.Fatalf("login status %d", resp.StatusCode)
	}

	// refresh
	resp = postJSON(t, srv.URL+"/auth/refresh", map[string]string{"refresh_token": reg.RefreshToken}, "")
	if resp.StatusCode != 200 {
		t.Fatalf("refresh status %d", resp.StatusCode)
	}

	// wrong password
	resp = postJSON(t, srv.URL+"/auth/login", map[string]string{"email": "a@b.com", "password": "nope"}, "")
	if resp.StatusCode != 401 {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}

	// protected route without token
	resp, _ = http.Get(srv.URL + "/subscription")
	if resp.StatusCode != 401 {
		t.Fatalf("expected 401 on unauth, got %d", resp.StatusCode)
	}
}

func putJSON(t *testing.T, url string, body any, bearer string) *http.Response {
	t.Helper()
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("PUT", url, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func TestChangePasswordRevokesRefreshTokens(t *testing.T) {
	srv := testServer(t)

	// register, capture access + refresh
	resp := postJSON(t, srv.URL+"/auth/register", map[string]string{"email": "chpw@b.com", "password": "password123"}, "")
	if resp.StatusCode != 201 {
		t.Fatalf("register status %d", resp.StatusCode)
	}
	var reg struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&reg)

	// change password (authenticated with access token)
	resp = putJSON(t, srv.URL+"/auth/password", map[string]string{"old_password": "password123", "new_password": "newpassword456"}, reg.AccessToken)
	if resp.StatusCode != 204 {
		t.Fatalf("change-password status %d", resp.StatusCode)
	}

	// the pre-change refresh token must now be rejected (revoked)
	resp = postJSON(t, srv.URL+"/auth/refresh", map[string]string{"refresh_token": reg.RefreshToken}, "")
	if resp.StatusCode != 401 {
		t.Fatalf("expected stale refresh token to be 401 after password change, got %d", resp.StatusCode)
	}
}
