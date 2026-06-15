package backend_test

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers"
	"github.com/getkin/kin-openapi/routers/gorillamux"
	"github.com/google/uuid"

	"github.com/S7245/mini_vpn_app/backend/internal/api"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/store"
	"github.com/S7245/mini_vpn_app/backend/internal/testutil"
)

const specBase = "http://localhost:8080"

func loadSpecRouter(t *testing.T) routers.Router {
	t.Helper()
	loader := openapi3.NewLoader()
	doc, err := loader.LoadFromFile("../contracts/backend-api.openapi.yaml")
	if err != nil {
		t.Fatalf("load spec: %v", err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		t.Fatalf("spec invalid: %v", err)
	}
	router, err := gorillamux.NewRouter(doc)
	if err != nil {
		t.Fatalf("build router: %v", err)
	}
	return router
}

// assertConforms validates a captured response (status+header+body) against the
// spec route method+specPath (templated path as written in the OpenAPI doc).
func assertConforms(t *testing.T, router routers.Router, method, specPath string, status int, header http.Header, body []byte) {
	t.Helper()
	specReq, err := http.NewRequest(method, specBase+specPath, nil)
	if err != nil {
		t.Fatal(err)
	}
	route, pathParams, err := router.FindRoute(specReq)
	if err != nil {
		t.Fatalf("route %s %s not found in spec: %v", method, specPath, err)
	}
	if err := openapi3filter.ValidateResponse(context.Background(), &openapi3filter.ResponseValidationInput{
		RequestValidationInput: &openapi3filter.RequestValidationInput{
			Request:    specReq,
			PathParams: pathParams,
			Route:      route,
		},
		Status:  status,
		Header:  header,
		Body:    io.NopCloser(bytes.NewReader(body)),
		Options: &openapi3filter.Options{IncludeResponseStatus: true},
	}); err != nil {
		t.Fatalf("%s %s (status %d) does NOT conform to contract: %v\nbody: %s", method, specPath, status, err, string(body))
	}
}

func readAll(t *testing.T, resp *http.Response) []byte {
	t.Helper()
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	return b
}

func TestResponsesConformToContract(t *testing.T) {
	db := testutil.NewPostgres(t)
	cfg := config.Config{JWTSecret: "test-secret", AccessTTL: time.Hour, RefreshTTL: time.Hour}
	srv := httptest.NewServer(api.NewServer(db, cfg))
	t.Cleanup(srv.Close)
	router := loadSpecRouter(t)

	// --- register (201) ---
	regReq, _ := json.Marshal(map[string]string{"email": "conf@b.com", "password": "password123"})
	resp, err := http.Post(srv.URL+"/auth/register", "application/json", bytes.NewReader(regReq))
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 201 {
		t.Fatalf("register status %d", resp.StatusCode)
	}
	regBody := readAll(t, resp)
	assertConforms(t, router, "POST", "/auth/register", resp.StatusCode, resp.Header, regBody)

	var tp struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.Unmarshal(regBody, &tp); err != nil || tp.AccessToken == "" {
		t.Fatalf("no access token from register: %v", err)
	}
	tok := tp.AccessToken

	// --- subscription (200, free plan => expires_at null) ---
	subReq, _ := http.NewRequest("GET", srv.URL+"/subscription", nil)
	subReq.Header.Set("Authorization", "Bearer "+tok)
	resp, err = http.DefaultClient.Do(subReq)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("subscription status %d", resp.StatusCode)
	}
	assertConforms(t, router, "GET", "/subscription", resp.StatusCode, resp.Header, readAll(t, resp))

	// --- seed a shared node + a user-owned dedicated node, then nodes (200) ---
	q := store.New(db)
	ctx := context.Background()
	if err := q.SeedNode(ctx, store.SeedNodeParams{Kind: "shared", Region: "US", City: "Los Angeles", LatencyMs: 142, Load: 0.37, Tier: sql.NullString{String: "standard", Valid: true}}); err != nil {
		t.Fatal(err)
	}
	u, err := q.GetUserByEmail(ctx, "conf@b.com")
	if err != nil {
		t.Fatal(err)
	}
	owner, err := uuid.Parse(u.ID)
	if err != nil {
		t.Fatal(err)
	}
	if err := q.SeedNode(ctx, store.SeedNodeParams{
		Kind: "dedicated", Region: "US", City: "San Jose", LatencyMs: 130, Load: 0.05,
		Label:     sql.NullString{String: "my-static-1", Valid: true},
		StaticIp:  sql.NullString{String: "203.0.113.9", Valid: true},
		ExpiresAt: sql.NullTime{Time: time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC), Valid: true},
		OwnerID:   uuid.NullUUID{UUID: owner, Valid: true},
	}); err != nil {
		t.Fatal(err)
	}

	nodesReq, _ := http.NewRequest("GET", srv.URL+"/nodes", nil)
	nodesReq.Header.Set("Authorization", "Bearer "+tok)
	resp, err = http.DefaultClient.Do(nodesReq)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("nodes status %d", resp.StatusCode)
	}
	assertConforms(t, router, "GET", "/nodes", resp.StatusCode, resp.Header, readAll(t, resp))
}
