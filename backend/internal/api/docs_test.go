package api_test

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"net/http/httptest"

	"github.com/S7245/mini_vpn_app/backend/internal/api"
	"github.com/S7245/mini_vpn_app/backend/internal/config"
	"github.com/S7245/mini_vpn_app/backend/internal/testutil"
)

func TestDocsServedWhenEnabled(t *testing.T) {
	db := testutil.NewPostgres(t)
	specBody := "openapi: 3.1.0\ninfo:\n  title: test\n  version: 0.0.0\npaths: {}\n"
	dir := t.TempDir()
	specPath := filepath.Join(dir, "spec.yaml")
	if err := os.WriteFile(specPath, []byte(specBody), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg := config.Config{JWTSecret: "test-secret", AccessTTL: 3600_000_000_000, RefreshTTL: 3600_000_000_000, DocsEnabled: true, OpenAPISpecPath: specPath}
	srv := httptest.NewServer(api.NewServer(db, cfg))
	t.Cleanup(srv.Close)

	// spec is served verbatim from disk
	resp := getJSON(t, srv.URL+"/openapi.yaml", "")
	if resp.StatusCode != 200 {
		t.Fatalf("/openapi.yaml status %d", resp.StatusCode)
	}
	b, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if string(b) != specBody {
		t.Fatalf("/openapi.yaml body mismatch: %q", string(b))
	}

	// docs page is HTML embedding Scalar and pointing at /openapi.yaml
	resp = getJSON(t, srv.URL+"/docs", "")
	if resp.StatusCode != 200 {
		t.Fatalf("/docs status %d", resp.StatusCode)
	}
	h, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	html := string(h)
	if !strings.Contains(html, "scalar") || !strings.Contains(html, "/openapi.yaml") {
		t.Fatalf("/docs missing scalar embed or spec url: %s", html)
	}
}

func TestDocsDisabledByDefault(t *testing.T) {
	srv := testServer(t) // cfg has DocsEnabled=false
	resp := getJSON(t, srv.URL+"/docs", "")
	if resp.StatusCode != 404 {
		t.Fatalf("expected /docs to be 404 when disabled, got %d", resp.StatusCode)
	}
}
