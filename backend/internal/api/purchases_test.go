package api_test

import "testing"

func TestPurchaseStubsReturn501(t *testing.T) {
	srv := testServer(t)
	tok := registerAndToken(t, srv.URL, "pay@b.com")
	for _, path := range []string{"/purchases/subscription", "/purchases/dedicated-ip"} {
		resp := postJSON(t, srv.URL+path, nil, tok)
		if resp.StatusCode != 501 {
			t.Fatalf("%s: expected 501, got %d", path, resp.StatusCode)
		}
	}
}
