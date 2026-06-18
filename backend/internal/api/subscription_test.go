package api_test

import (
	"encoding/json"
	"net/http"
	"testing"
)

func registerAndToken(t *testing.T, baseURL, email string) string {
	t.Helper()
	resp := postJSON(t, baseURL+"/auth/register", map[string]string{"email": email, "password": "password123"}, "")
	if resp.StatusCode != 201 {
		t.Fatalf("register %d", resp.StatusCode)
	}
	var tp struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&tp)
	return tp.AccessToken
}

func getJSON(t *testing.T, url, bearer string) *http.Response {
	t.Helper()
	req, _ := http.NewRequest("GET", url, nil)
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func TestGetSubscription(t *testing.T) {
	srv := testServer(t)
	tok := registerAndToken(t, srv.URL, "sub@b.com")
	resp := getJSON(t, srv.URL+"/subscription", tok)
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	var sub struct {
		Plan        string `json:"plan"`
		Status      string `json:"status"`
		DeviceLimit int    `json:"device_limit"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&sub)
	if sub.Plan != "free" || sub.Status != "active" || sub.DeviceLimit != 1 {
		t.Fatalf("bad subscription: %+v", sub)
	}
}
