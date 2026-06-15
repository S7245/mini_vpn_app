package api_test

import (
	"encoding/json"
	"net/http"
	"sync"
	"testing"
)

func TestDeviceLifecycleAndLimit(t *testing.T) {
	srv := testServer(t)
	tok := registerAndToken(t, srv.URL, "dev@b.com") // free plan => device_limit 1

	// list empty
	resp := getJSON(t, srv.URL+"/devices", tok)
	if resp.StatusCode != 200 {
		t.Fatalf("list status %d", resp.StatusCode)
	}
	var list struct {
		Devices     []map[string]any `json:"devices"`
		DeviceLimit int              `json:"device_limit"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&list)
	if len(list.Devices) != 0 || list.DeviceLimit != 1 {
		t.Fatalf("bad empty list: %+v", list)
	}

	// register one
	resp = postJSON(t, srv.URL+"/devices", map[string]string{"name": "Mac", "platform": "macos"}, tok)
	if resp.StatusCode != 201 {
		t.Fatalf("register device status %d", resp.StatusCode)
	}
	var dev struct {
		ID       string `json:"id"`
		Platform string `json:"platform"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&dev)
	if dev.ID == "" || dev.Platform != "macos" {
		t.Fatalf("bad device: %+v", dev)
	}

	// second exceeds limit -> 409
	resp = postJSON(t, srv.URL+"/devices", map[string]string{"name": "Mac2", "platform": "macos"}, tok)
	if resp.StatusCode != 409 {
		t.Fatalf("expected 409, got %d", resp.StatusCode)
	}

	// revoke
	req, _ := http.NewRequest("DELETE", srv.URL+"/devices/"+dev.ID, nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, _ = http.DefaultClient.Do(req)
	if resp.StatusCode != 204 {
		t.Fatalf("revoke status %d", resp.StatusCode)
	}
}

func TestRevokeMalformedDeviceIDIsNoOp(t *testing.T) {
	srv := testServer(t)
	tok := registerAndToken(t, srv.URL, "delmal@b.com")
	req, _ := http.NewRequest("DELETE", srv.URL+"/devices/not-a-uuid", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 204 {
		t.Fatalf("malformed deviceId should be a 204 no-op, got %d", resp.StatusCode)
	}
}

// TestConcurrentDeviceRegisterRespectsLimit exercises the FOR UPDATE row lock:
// firing N concurrent registers against a device_limit of 1 must yield exactly
// one 201 and the rest 409 — never two devices created (TOCTOU regression guard).
func TestConcurrentDeviceRegisterRespectsLimit(t *testing.T) {
	srv := testServer(t)
	tok := registerAndToken(t, srv.URL, "race@b.com") // device_limit 1

	const n = 6
	var wg sync.WaitGroup
	codes := make([]int, n)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func(i int) {
			defer wg.Done()
			resp := postJSON(t, srv.URL+"/devices", map[string]string{"name": "d", "platform": "macos"}, tok)
			codes[i] = resp.StatusCode
		}(i)
	}
	wg.Wait()

	created, conflict := 0, 0
	for _, c := range codes {
		switch c {
		case 201:
			created++
		case 409:
			conflict++
		default:
			t.Fatalf("unexpected status %d (codes=%v)", c, codes)
		}
	}
	if created != 1 || conflict != n-1 {
		t.Fatalf("TOCTOU: expected exactly 1 created and %d conflicts, got created=%d conflict=%d (codes=%v)", n-1, created, conflict, codes)
	}

	// confirm the DB really holds exactly one device
	resp := getJSON(t, srv.URL+"/devices", tok)
	var list struct {
		Devices []map[string]any `json:"devices"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&list)
	if len(list.Devices) != 1 {
		t.Fatalf("expected exactly 1 device persisted, got %d", len(list.Devices))
	}
}
